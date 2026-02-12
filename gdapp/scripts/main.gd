extends Control

const TOTAL_ROUNDS := 10
const PAIRS_ROOT := "res://assets/pairs"
const ENABLE_BORDERLESS_WINDOW := true
const SCREEN_FADE_DURATION := 0.18
const PAIR_APPEAR_DURATION := 0.20
const CHOICE_FEEDBACK_DURATION := 0.22

var random_generator := RandomNumberGenerator.new()
var pair_ids: Array[String] = []
var used_pair_ids := {}
var rounds: Array[Dictionary] = []
var current_round_index := 0
var score := 0
var can_choose := false

var current_pair_id := ""
var current_correct_choice := -1
var current_left_path := ""
var current_right_path := ""

var is_loading_textures := false
var pending_left_path := ""
var pending_right_path := ""

@onready var card_panel: PanelContainer = $SafeArea/RootColumn/Card
@onready var intro_screen: VBoxContainer = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/IntroScreen
@onready var game_screen: VBoxContainer = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/GameScreen
@onready var result_screen: VBoxContainer = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/ResultScreen

@onready var title_label: Label = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/IntroScreen/TitleLabel
@onready var intro_label: Label = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/IntroScreen/IntroLabel
@onready var start_button: Button = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/IntroScreen/StartButton

@onready var round_label: Label = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/GameScreen/RoundLabel
@onready var hint_label: Label = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/GameScreen/HintLabel
@onready var left_frame: PanelContainer = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/GameScreen/PairRow/LeftFrame
@onready var right_frame: PanelContainer = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/GameScreen/PairRow/RightFrame
@onready var left_choice_button: TextureButton = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/GameScreen/PairRow/LeftFrame/LeftChoiceButton
@onready var right_choice_button: TextureButton = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/GameScreen/PairRow/RightFrame/RightChoiceButton
@onready var loading_label: Label = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/GameScreen/LoadingLabel

@onready var result_title: Label = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/ResultScreen/ResultTitle
@onready var score_label: Label = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/ResultScreen/ScoreLabel
@onready var recap_list: VBoxContainer = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/ResultScreen/RecapScroll/RecapList
@onready var replay_button: Button = $SafeArea/RootColumn/Card/CardPadding/ScreenStack/ResultScreen/ReplayButton


func _ready() -> void:
	random_generator.randomize()
	set_process(true)
	apply_window_preferences()
	apply_theme()
	configure_text()
	configure_choice_buttons()
	connect_signals()
	pair_ids = discover_pair_ids()
	show_intro_screen()


func _process(_delta: float) -> void:
	if is_loading_textures:
		try_complete_async_load()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var key := key_event.keycode
	if key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
		if intro_screen.visible or result_screen.visible:
			start_game()
			get_viewport().set_input_as_handled()
			return

	if not game_screen.visible or not can_choose:
		return

	if key == KEY_LEFT or key == KEY_A:
		on_choice_made(0)
		get_viewport().set_input_as_handled()
	elif key == KEY_RIGHT or key == KEY_D:
		on_choice_made(1)
		get_viewport().set_input_as_handled()


func apply_window_preferences() -> void:
	if not OS.has_feature("desktop"):
		return

	if ENABLE_BORDERLESS_WINDOW:
		var screen := DisplayServer.window_get_current_screen()
		var screen_size := DisplayServer.screen_get_size(screen)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_size(screen_size)
		DisplayServer.window_set_position(Vector2i.ZERO)


func apply_theme() -> void:
	card_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.18, 0.19, 0.22, 1.0), Color(0.38, 0.40, 0.44, 1.0), 22, 2))
	left_frame.add_theme_stylebox_override("panel", make_panel_style(Color(0.12, 0.13, 0.15, 1.0), Color(0.38, 0.40, 0.44, 1.0), 16, 2))
	right_frame.add_theme_stylebox_override("panel", make_panel_style(Color(0.12, 0.13, 0.15, 1.0), Color(0.38, 0.40, 0.44, 1.0), 16, 2))

	var normal_button_style := make_panel_style(Color(0.22, 0.24, 0.27, 1.0), Color(0.48, 0.51, 0.56, 1.0), 12, 2)
	var hover_button_style := make_panel_style(Color(0.27, 0.30, 0.34, 1.0), Color(0.65, 0.70, 0.75, 1.0), 12, 2)
	var pressed_button_style := make_panel_style(Color(0.17, 0.19, 0.22, 1.0), Color(0.55, 0.61, 0.67, 1.0), 12, 2)

	for button in [start_button, replay_button]:
		button.add_theme_stylebox_override("normal", normal_button_style)
		button.add_theme_stylebox_override("hover", hover_button_style)
		button.add_theme_stylebox_override("pressed", pressed_button_style)
		button.add_theme_stylebox_override("focus", hover_button_style)
		button.add_theme_color_override("font_color", Color(0.93, 0.95, 0.97, 1.0))
		button.custom_minimum_size = Vector2(220, 56)

	title_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	round_label.add_theme_color_override("font_color", Color(0.90, 0.94, 0.99, 1.0))
	result_title.add_theme_color_override("font_color", Color(0.90, 0.94, 0.99, 1.0))
	score_label.add_theme_color_override("font_color", Color(0.83, 0.91, 0.90, 1.0))


func configure_text() -> void:
	title_label.text = "_DoppleRender"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	intro_label.text = "You will see pairs of images: one is real, the other is AI-generated.\nTap or click on the REAL photo. 10 pairs to identify."
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	start_button.text = "Begin"
	hint_label.text = "(Tap/click on the real photo)"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.text = "Loading next pair..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	result_title.text = "Summary"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_button.text = "Play again"


func configure_choice_buttons() -> void:
	left_choice_button.ignore_texture_size = true
	right_choice_button.ignore_texture_size = true
	left_choice_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	right_choice_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	left_choice_button.custom_minimum_size = Vector2(460, 460)
	right_choice_button.custom_minimum_size = Vector2(460, 460)


func connect_signals() -> void:
	start_button.pressed.connect(start_game)
	replay_button.pressed.connect(start_game)
	left_choice_button.pressed.connect(_on_left_choice_pressed)
	right_choice_button.pressed.connect(_on_right_choice_pressed)


func _on_left_choice_pressed() -> void:
	on_choice_made(0)


func _on_right_choice_pressed() -> void:
	on_choice_made(1)


func discover_pair_ids() -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(PAIRS_ROOT)
	assert(dir != null, "Pair folder not found: " + PAIRS_ROOT)

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var real_path := PAIRS_ROOT + "/" + entry + "/real.png"
			var ai_path := PAIRS_ROOT + "/" + entry + "/ai.png"
			assert(FileAccess.file_exists(real_path), "Missing real image: " + real_path)
			assert(FileAccess.file_exists(ai_path), "Missing ai image: " + ai_path)
			found.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()

	found.sort()
	assert(found.size() > 0, "No valid pair folders found")
	return found


func show_intro_screen() -> void:
	transition_to_screen(intro_screen)


func show_game_screen() -> void:
	transition_to_screen(game_screen)


func show_result_screen() -> void:
	transition_to_screen(result_screen)


func transition_to_screen(target: Control) -> void:
	for screen in [intro_screen, game_screen, result_screen]:
		screen.visible = screen == target
		screen.modulate = Color(1.0, 1.0, 1.0, 1.0)

	target.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(target, "modulate:a", 1.0, SCREEN_FADE_DURATION)


func start_game() -> void:
	current_round_index = 0
	score = 0
	used_pair_ids.clear()
	rounds.clear()
	show_game_screen()
	load_next_round()


func load_next_round() -> void:
	if current_round_index >= TOTAL_ROUNDS:
		build_result_screen()
		return

	can_choose = false
	set_loading_state(true)
	round_label.text = "Pair %d/%d" % [current_round_index + 1, TOTAL_ROUNDS]

	current_pair_id = pick_random_pair_id()
	var is_real_left := random_generator.randi_range(0, 1) == 0
	current_correct_choice = 0 if is_real_left else 1

	current_left_path = pair_texture_path(current_pair_id, "real" if is_real_left else "ai")
	current_right_path = pair_texture_path(current_pair_id, "ai" if is_real_left else "real")
	start_async_pair_load(current_left_path, current_right_path)


func start_async_pair_load(left_path: String, right_path: String) -> void:
	pending_left_path = left_path
	pending_right_path = right_path
	is_loading_textures = true

	var left_error := ResourceLoader.load_threaded_request(left_path, "Texture2D")
	var right_error := ResourceLoader.load_threaded_request(right_path, "Texture2D")
	assert(left_error == OK, "Cannot request async load for: " + left_path)
	assert(right_error == OK, "Cannot request async load for: " + right_path)


func try_complete_async_load() -> void:
	var left_status := ResourceLoader.load_threaded_get_status(pending_left_path)
	var right_status := ResourceLoader.load_threaded_get_status(pending_right_path)

	assert(left_status != ResourceLoader.THREAD_LOAD_FAILED, "Async load failed: " + pending_left_path)
	assert(right_status != ResourceLoader.THREAD_LOAD_FAILED, "Async load failed: " + pending_right_path)
	assert(left_status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "Invalid resource: " + pending_left_path)
	assert(right_status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "Invalid resource: " + pending_right_path)

	if left_status != ResourceLoader.THREAD_LOAD_LOADED or right_status != ResourceLoader.THREAD_LOAD_LOADED:
		return

	var left_texture := ResourceLoader.load_threaded_get(pending_left_path) as Texture2D
	var right_texture := ResourceLoader.load_threaded_get(pending_right_path) as Texture2D
	assert(left_texture != null, "Cannot load texture: " + pending_left_path)
	assert(right_texture != null, "Cannot load texture: " + pending_right_path)

	set_button_texture(left_choice_button, left_texture)
	set_button_texture(right_choice_button, right_texture)

	is_loading_textures = false
	set_loading_state(false)
	animate_pair_appearance()
	can_choose = true


func animate_pair_appearance() -> void:
	left_frame.modulate = Color(1.0, 1.0, 1.0, 0.0)
	right_frame.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(left_frame, "modulate:a", 1.0, PAIR_APPEAR_DURATION)
	tween.tween_property(right_frame, "modulate:a", 1.0, PAIR_APPEAR_DURATION)


func set_button_texture(button: TextureButton, texture: Texture2D) -> void:
	button.texture_normal = texture
	button.texture_hover = texture
	button.texture_pressed = texture
	button.texture_disabled = texture
	button.texture_focused = texture


func pair_texture_path(pair_id: String, role: String) -> String:
	return PAIRS_ROOT + "/" + pair_id + "/" + role + ".png"


func pick_random_pair_id() -> String:
	assert(used_pair_ids.size() < pair_ids.size(), "No remaining pair IDs available")
	var candidate := pair_ids[random_generator.randi_range(0, pair_ids.size() - 1)]
	while used_pair_ids.has(candidate):
		candidate = pair_ids[random_generator.randi_range(0, pair_ids.size() - 1)]
	used_pair_ids[candidate] = true
	return candidate


func set_loading_state(is_loading: bool) -> void:
	loading_label.visible = is_loading
	left_choice_button.disabled = is_loading
	right_choice_button.disabled = is_loading
	if is_loading:
		left_frame.modulate = Color(1.0, 1.0, 1.0, 0.50)
		right_frame.modulate = Color(1.0, 1.0, 1.0, 0.50)


func on_choice_made(choice: int) -> void:
	if not can_choose:
		return

	can_choose = false
	var is_correct := choice == current_correct_choice
	if is_correct:
		score += 1

	await animate_choice_feedback(choice, is_correct)
	rounds.append({
		"pair_id": current_pair_id,
		"left_path": current_left_path,
		"right_path": current_right_path,
		"user_choice": choice,
		"correct_choice": current_correct_choice
	})

	current_round_index += 1
	load_next_round()


func animate_choice_feedback(choice: int, is_correct: bool) -> void:
	var selected_frame := left_frame if choice == 0 else right_frame
	selected_frame.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.12, 0.13, 0.15, 1.0),
			Color(0.22, 0.74, 0.44, 1.0) if is_correct else Color(0.80, 0.30, 0.30, 1.0),
			16,
			4
		)
	)

	var tween := create_tween()
	tween.tween_property(selected_frame, "scale", Vector2(1.02, 1.02), CHOICE_FEEDBACK_DURATION * 0.45)
	tween.tween_property(selected_frame, "scale", Vector2.ONE, CHOICE_FEEDBACK_DURATION * 0.55)
	await tween.finished
	selected_frame.remove_theme_stylebox_override("panel")


func build_result_screen() -> void:
	show_result_screen()
	score_label.text = "Your score: %d/%d" % [score, TOTAL_ROUNDS]
	clear_recap_entries()

	for index in range(rounds.size()):
		var round := rounds[index]
		var row := build_recap_row(index, round)
		recap_list.add_child(row)


func clear_recap_entries() -> void:
	for child in recap_list.get_children():
		child.queue_free()


func build_recap_row(index: int, round: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)

	var index_label := Label.new()
	index_label.text = "Pair %d" % [index + 1]
	index_label.custom_minimum_size = Vector2(90, 36)
	index_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(index_label)

	var left_panel := create_recap_image_panel(round["left_path"])
	var right_panel := create_recap_image_panel(round["right_path"])
	row.add_child(left_panel)
	row.add_child(right_panel)

	var selected_panel := left_panel if int(round["user_choice"]) == 0 else right_panel
	var was_correct := int(round["user_choice"]) == int(round["correct_choice"])
	selected_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.12, 0.13, 0.15, 1.0),
			Color(0.22, 0.74, 0.44, 1.0) if was_correct else Color(0.80, 0.30, 0.30, 1.0),
			12,
			4
		)
	)

	return row


func create_recap_image_panel(texture_path: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 180)
	panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.12, 0.13, 0.15, 1.0), Color(0.32, 0.35, 0.39, 1.0), 12, 2))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = load(texture_path) as Texture2D
	margin.add_child(image)

	return panel


func make_panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
