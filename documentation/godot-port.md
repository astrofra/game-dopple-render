# Godot Port Strategy (from `docs/` Web Version)

## 1) Current Web Implementation Analysis

### Source layout
- `docs/index.html`: three screens in one page (`intro`, `game`, `result`) toggled with `.hidden` (`docs/index.html:9`, `docs/index.html:15`, `docs/index.html:25`).
- `docs/script.js`: all gameplay state and flow.
- `docs/image_mapping.js`: legacy web indirection layer from pair ID to hashed filenames.
- `docs/style.css`: visual style, fixed image target size (`500px` in game, `200px` in recap), neon/cyber theme (`docs/style.css:56`, `docs/style.css:90`).

### Game loop and rules (from `docs/script.js`)
- The game runs for exactly 10 rounds (`if (current >= 10) return showResult();`, `docs/script.js:31`).
- A round selects one random pair ID and randomizes left/right placement of AI vs real.
- Player must click the real image.
- Score increments by 1 for correct picks.
- Final screen shows total score and recap of all 10 rounds with visual feedback on clicked image.

### Data model inferred from source
- Runtime state: `current`, `score`, `order`, `seen`, `rounds`, `imagesLoaded`, `canClick`.
- Pair object stored in `order`: `{ id, correct }`, where `correct` is `0` (left) or `1` (right).
- Round recap object: `{ id, user, correct }`.
- Inference from render logic: `mapping.a` is treated as real and `mapping.b` as AI-generated.

### Asset and mapping observations
- `docs/assets`: 580 PNG files, total size ~1.14 GB.
- `docs/image_mapping.js`: 290 mapping entries (580 file references).
- In the Godot port, this mapping file should be removed and replaced by explicit per-pair filenames/folders.
- Legacy web data inconsistency to handle during migration:
- Runtime random range is `000..289` (`Math.floor(Math.random() * (580/2))`, `docs/script.js:24`).
- Mapping contains `290` and `291` (`docs/image_mapping.js:1155`, `docs/image_mapping.js:1159`), while `278` and `279` are missing.
- Image resolutions are heterogeneous (58 distinct dimensions), mostly square but not all.

## 2) Port Targets

- Desktop standalone app in Godot (Windows/macOS/Linux export-ready).
- Input parity for mouse and touch screen.
- Automatic adaptation for 1920x1080 and 4K displays.
- Optional borderless window mode (kiosk-friendly).
- Keep current game behavior unchanged for first port milestone.

## 3) Godot Architecture Proposal

### Scene structure
- `Main.tscn` (`Control` root): owns state machine and screen switching.
- `IntroPanel.tscn`: title, instructions, start button.
- `GamePanel.tscn`: round counter, instruction text, two clickable image widgets, loading label.
- `ResultPanel.tscn`: score, scrollable recap list, replay button.
- `RecapItem.tscn`: two thumbnail images with selected-side result highlight.

### Script structure (task-specific, no generic dispatcher)
- `game_controller.gd`: game flow, round progression, scoring, transitions.
- `pair_repository.gd`: discovers pair folders/files and returns random unseen pairs.
- `pair_loader.gd`: async loading of 2 textures for current round.
- `result_builder.gd`: rebuilds recap UI from round history.

### Asset normalization (replace mapping)
- Normalize assets into explicit pair structure, for example:
- `res://assets/pairs/000/real.png`
- `res://assets/pairs/000/ai.png`
- `res://assets/pairs/001/real.png`
- `res://assets/pairs/001/ai.png`
- `pair_repository.gd` scans `res://assets/pairs/` at startup and builds the available pair list directly from filesystem.
- Add a one-time validation script that fails loudly if:
- A pair folder does not contain exactly `real.png` and `ai.png`.
- Any duplicate pair ID exists.
- No valid pairs are found.

## 4) Resolution, Scaling, and Window Strategy

### Baseline viewport and stretch
- Design base: `1920x1080`.
- Project settings:
- `display/window/size/viewport_width = 1920`
- `display/window/size/viewport_height = 1080`
- `display/window/stretch/mode = canvas_items`
- `display/window/stretch/aspect = expand`
- `display/window/dpi/allow_hidpi = true`

### UI behavior for 1080p and 4K
- Use `Control` anchors/containers only (no fixed pixel coordinates for layout).
- Keep image widgets in equal-width containers, preserve texture aspect (`expand_mode = keep_size`, `stretch_mode = keep_aspect_centered` equivalent behavior).
- Keep minimum clickable size large enough for touch at 1080p; let stretch scaling naturally enlarge on 4K.

### Borderless desktop behavior
- Default mode for release build: borderless + maximized to current screen size.
- Optional setting/toggle for true fullscreen.
- Runtime startup behavior:
- Detect primary display size.
- Set window size to display size.
- Apply borderless mode.

Example startup logic (Godot 4, GDScript):

```gdscript
func _ready() -> void:
    var screen := DisplayServer.window_get_current_screen()
    var size := DisplayServer.screen_get_size(screen)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
    DisplayServer.window_set_size(size)
    DisplayServer.window_set_position(Vector2i.ZERO)
```

## 5) Input Strategy (Mouse + Touch)

- Use `TextureButton` for left/right image choices.
- Connect `pressed` signal for both images; this works for mouse click and touch tap.
- Keep keyboard fallback for desktop testing:
- `ui_left` chooses left image.
- `ui_right` chooses right image.

## 6) Gameplay Port Flow

### Round flow equivalence
1. Start game resets all state and opens game panel.
2. Pick random unseen pair ID.
3. Randomize whether AI appears left or right.
4. Load both textures asynchronously.
5. Enable input only after both textures are ready.
6. On selection: evaluate, store round result, update score, continue.
7. After 10 rounds: show summary + recap list.

### Suggested strict data constants
- `TOTAL_ROUNDS := 10`
- `pair_count := discovered_pairs.size()` (no hardcoded pool size)

## 7) Performance and Memory Plan

- Do not preload all textures (dataset is too large).
- Load only current round textures (+ optional next-round prefetch of 2 textures).
- Free previous round textures immediately after transition.
- Consider optional offline conversion/compression pipeline for desktop package size reduction.

## 8) Risks and Pre-Port Fixes

- Remove legacy mapping dependency entirely in Godot:
- Rename/reorganize source images into explicit `real`/`ai` pair files.
- Drive selection from discovered pair folders instead of numeric ID assumptions.
- Clarify/lock semantic contract that `a = real` and `b = AI` in source dataset metadata (currently inferred from UI logic).
- Remove dead CSS-equivalent concepts during port (`correct`/`wrong` container class exists in JS logic but has no style effect in web version).

## 9) Implementation Plan (Incremental)

1. Data pipeline: normalize assets to per-pair `real/ai` files + validation script.
2. UI scaffold: Intro/Game/Result scenes with responsive container layout.
3. Core logic: round selection, scoring, recap data.
4. Async loader: enable/disable clickability based on 2-image readiness.
5. Window/scaling: borderless startup, 1080p/4K checks.
6. Input QA: mouse and touch validation on target devices.
7. Visual parity pass: match current style and feedback behavior.

## 10) Acceptance Criteria

- 10-round session completes reliably with no missing-pair errors.
- Same scoring behavior as web version.
- Recap clearly marks user choice and correctness each round.
- Works with mouse and touch on desktop.
- Correctly adapts on 1920x1080 and 3840x2160 without layout breakage.
- Borderless startup behavior works as configured.
