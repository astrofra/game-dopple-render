import csv
import re
from pathlib import Path

ASSETS_DIR = Path("gdapp/assets")
QUARANTINE_DIR = ASSETS_DIR / "_quarantine"
REPORT_PATH = Path("documentation/asset-normalization-report.csv")

PAIR_FILE_RE = re.compile(r"^(\d{3})_([ab])\.png$")


def collect_pairs():
    pairs = {}
    for file_path in ASSETS_DIR.glob("*.png"):
        match = PAIR_FILE_RE.match(file_path.name)
        if not match:
            continue
        pair_id, label = match.groups()
        if pair_id not in pairs:
            pairs[pair_id] = {}
        pairs[pair_id][label] = file_path
    return pairs


def ensure_directory(path):
    path.mkdir(parents=True, exist_ok=True)


def main():
    pairs = collect_pairs()
    complete_ids = sorted(pair_id for pair_id, labels in pairs.items() if set(labels.keys()) == {"a", "b"})
    incomplete_ids = sorted(pair_id for pair_id, labels in pairs.items() if set(labels.keys()) != {"a", "b"})

    pair_mapping = {}
    for index, old_pair_id in enumerate(complete_ids):
        pair_mapping[old_pair_id] = f"{index:03d}"

    rename_operations = []
    report_rows = []

    for old_pair_id in complete_ids:
        new_pair_id = pair_mapping[old_pair_id]
        if old_pair_id == new_pair_id:
            continue

        for label in ("a", "b"):
            old_png = ASSETS_DIR / f"{old_pair_id}_{label}.png"
            new_png = ASSETS_DIR / f"{new_pair_id}_{label}.png"
            rename_operations.append((old_png, new_png))
            report_rows.append({
                "action": "rename",
                "old_path": str(old_png),
                "new_path": str(new_png),
                "details": "pair_id_reindex",
            })

            old_import = ASSETS_DIR / f"{old_pair_id}_{label}.png.import"
            new_import = ASSETS_DIR / f"{new_pair_id}_{label}.png.import"
            if old_import.exists():
                rename_operations.append((old_import, new_import))
                report_rows.append({
                    "action": "rename",
                    "old_path": str(old_import),
                    "new_path": str(new_import),
                    "details": "pair_id_reindex",
                })

    # Quarantine incomplete source files before reindexing so renamed files
    # cannot be moved by mistake.
    ensure_directory(QUARANTINE_DIR)
    for pair_id in incomplete_ids:
        labels = sorted(pairs[pair_id].keys())
        for label in labels:
            old_png = ASSETS_DIR / f"{pair_id}_{label}.png"
            new_png = QUARANTINE_DIR / old_png.name
            if old_png.exists():
                old_png.rename(new_png)
                report_rows.append({
                    "action": "quarantine",
                    "old_path": str(old_png),
                    "new_path": str(new_png),
                    "details": "incomplete_pair",
                })

            old_import = ASSETS_DIR / f"{pair_id}_{label}.png.import"
            if old_import.exists():
                new_import = QUARANTINE_DIR / old_import.name
                old_import.rename(new_import)
                report_rows.append({
                    "action": "quarantine",
                    "old_path": str(old_import),
                    "new_path": str(new_import),
                    "details": "incomplete_pair",
                })

    # Two-phase rename to avoid collisions.
    staged_operations = []
    for old_path, new_path in rename_operations:
        if not old_path.exists():
            continue
        temp_path = old_path.with_name(old_path.name + ".tmp_norm")
        old_path.rename(temp_path)
        staged_operations.append((temp_path, new_path))

    for temp_path, new_path in staged_operations:
        temp_path.rename(new_path)

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with REPORT_PATH.open("w", newline="", encoding="utf-8") as report_file:
        writer = csv.DictWriter(report_file, fieldnames=["action", "old_path", "new_path", "details"])
        writer.writeheader()
        writer.writerows(report_rows)

    # Final validation must fail loudly if anything is still inconsistent.
    final_pairs = collect_pairs()
    final_complete_ids = sorted(pair_id for pair_id, labels in final_pairs.items() if set(labels.keys()) == {"a", "b"})
    expected_ids = [f"{index:03d}" for index in range(len(final_complete_ids))]
    if final_complete_ids != expected_ids:
        raise RuntimeError("Final pair IDs are not contiguous after normalization")

    final_incomplete = sorted(pair_id for pair_id, labels in final_pairs.items() if set(labels.keys()) != {"a", "b"})
    if final_incomplete:
        raise RuntimeError(f"Incomplete pairs remain after normalization: {final_incomplete}")

    print(f"Normalized complete pairs: {len(final_complete_ids)}")
    print(f"Quarantined incomplete pair IDs: {', '.join(incomplete_ids) if incomplete_ids else '-'}")
    print(f"Report written to: {REPORT_PATH}")


if __name__ == "__main__":
    main()
