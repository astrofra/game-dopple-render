import re
from pathlib import Path


ASSETS_DIR = Path("gdapp/assets")
PAIRS_DIR = ASSETS_DIR / "pairs"
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


def rewrite_import_file(import_path, pair_id, role):
    text = import_path.read_text(encoding="utf-8")
    source_path = f'source_file="res://assets/pairs/{pair_id}/{role}.png"'
    text = re.sub(r'source_file="[^"]+"', source_path, text, count=1)

    text = re.sub(
        r'path="res://\.godot/imported/[^"]+-(\w+)\.ctex"',
        f'path="res://.godot/imported/{role}.png-\\1.ctex"',
        text,
        count=1,
    )
    text = re.sub(
        r'dest_files=\["res://\.godot/imported/[^"]+-(\w+)\.ctex"\]',
        f'dest_files=["res://.godot/imported/{role}.png-\\1.ctex"]',
        text,
        count=1,
    )
    import_path.write_text(text, encoding="utf-8")


def main():
    pairs = collect_pairs()
    pair_ids = sorted(pairs.keys())
    expected_ids = [f"{index:03d}" for index in range(len(pair_ids))]
    if pair_ids != expected_ids:
        raise RuntimeError("Pair IDs must be contiguous before conversion")

    for pair_id in pair_ids:
        labels = set(pairs[pair_id].keys())
        if labels != {"a", "b"}:
            raise RuntimeError(f"Incomplete pair {pair_id}: {labels}")

    PAIRS_DIR.mkdir(parents=True, exist_ok=True)

    for pair_id in pair_ids:
        pair_dir = PAIRS_DIR / pair_id
        pair_dir.mkdir(parents=True, exist_ok=True)

        for label, role in (("a", "real"), ("b", "ai")):
            old_png = ASSETS_DIR / f"{pair_id}_{label}.png"
            new_png = pair_dir / f"{role}.png"
            old_png.rename(new_png)

            old_import = ASSETS_DIR / f"{pair_id}_{label}.png.import"
            if not old_import.exists():
                raise RuntimeError(f"Missing import file: {old_import}")
            new_import = pair_dir / f"{role}.png.import"
            old_import.rename(new_import)
            rewrite_import_file(new_import, pair_id, role)

    leftover_png = sorted(path.name for path in ASSETS_DIR.glob("*.png"))
    leftover_import = sorted(path.name for path in ASSETS_DIR.glob("*.png.import"))
    if leftover_png or leftover_import:
        raise RuntimeError("Old flat asset files remain after conversion")

    quarantine_dir = ASSETS_DIR / "_quarantine"
    if quarantine_dir.exists() and not any(quarantine_dir.iterdir()):
        quarantine_dir.rmdir()

    pair_dirs = sorted(path.name for path in PAIRS_DIR.iterdir() if path.is_dir())
    if pair_dirs != expected_ids:
        raise RuntimeError("Final pair folders are not contiguous")

    for pair_id in pair_dirs:
        pair_dir = PAIRS_DIR / pair_id
        if not (pair_dir / "real.png").exists() or not (pair_dir / "ai.png").exists():
            raise RuntimeError(f"Missing expected files in {pair_dir}")

    print(f"Converted pairs: {len(pair_dirs)}")
    print(f"Assets folder: {PAIRS_DIR}")


if __name__ == "__main__":
    main()
