extends Control

const StoryEngineScript := preload("res://scripts/story_engine.gd")
const FONT_PATH := "res://assets/fonts/NotoSansArabic-Regular.ttf"
const TITLE_BACKGROUND := "res://assets/story/runtime/chad_desert.png"
const BASE_UI_WIDTH := 1280.0
const MAX_UI_SCALE := 3.6

const COLOR_INK := Color(0.055, 0.071, 0.078, 0.96)
const COLOR_INK_SOFT := Color(0.082, 0.105, 0.11, 0.95)
const COLOR_SAND := Color(0.91, 0.78, 0.55, 1.0)
const COLOR_PAPER := Color(0.96, 0.93, 0.86, 1.0)
const COLOR_MUTED := Color(0.72, 0.77, 0.75, 1.0)
const COLOR_TEAL := Color(0.31, 0.72, 0.68, 1.0)
const COLOR_RUST := Color(0.72, 0.31, 0.23, 1.0)

var _engine: StoryEngine
var _font: Font
var _country_labels: Dictionary = {}
var _last_name := "محسن"
var _last_country := "egypt"
var _result_note := ""
var _current_background := ""

var _background: TextureRect
var _shade: ColorRect
var _title_layer: Control
var _title_panel: PanelContainer
var _name_input: LineEdit
var _country_input: OptionButton
var _story_layer: Control
var _hud_panel: PanelContainer
var _hud_location: Label
var _hud_day: Label
var _hud_health: Label
var _hud_water: Label
var _hud_food: Label
var _hud_trust: Label
var _hud_companions: Label
var _story_panel: PanelContainer
var _scene_title: Label
var _speaker_label: Label
var _story_text: Label
var _result_label: Label
var _choices_box: VBoxContainer
var _pause_layer: Control
var _pause_panel: PanelContainer
var _pause_button: Button


func _ready() -> void:
	set_process_input(true)
	_engine = StoryEngineScript.new()
	if not _engine.load_story():
		_show_fatal_message("تعذر فتح ملف القصة. تحقق من وجود data/story_ar.json.")
		return
	_country_labels = _engine.story.get("countries", {})
	_font = load(FONT_PATH) as Font
	_apply_theme()
	_update_responsive_scale()
	_build_base()
	_build_title_screen()
	_build_story_screen()
	_build_pause_screen()
	_show_title()
	_apply_responsive_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _update_responsive_scale():
			call_deferred("_refresh_responsive_layout")
		else:
			_refresh_responsive_layout()


func _update_responsive_scale() -> bool:
	if not is_inside_tree():
		return false
	var css_width := 0.0
	if OS.has_feature("web"):
		var browser_width: Variant = JavaScriptBridge.eval("window.innerWidth")
		if typeof(browser_width) == TYPE_FLOAT or typeof(browser_width) == TYPE_INT:
			css_width = float(browser_width)
	if css_width <= 0.0:
		css_width = float(get_window().size.x)
	if css_width <= 0.0:
		return false
	var window := get_window()
	var target_scale := clampf(BASE_UI_WIDTH / css_width, 1.0, MAX_UI_SCALE)
	if is_equal_approx(window.content_scale_factor, target_scale):
		return false
	window.content_scale_factor = target_scale
	return true


func _refresh_responsive_layout() -> void:
	_apply_responsive_layout()
	_layout_centered_panel(_title_panel, 780.0, 650.0)
	_layout_centered_panel(_pause_panel, 540.0, 390.0)


func _apply_responsive_layout() -> void:
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var portrait := view.y > view.x * 1.15
	if _hud_panel != null:
		_hud_panel.anchor_bottom = 0.22 if portrait else 0.255
	if _story_panel != null:
		_story_panel.anchor_top = 0.235 if portrait else 0.39


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _story_layer != null and _story_layer.visible and _pause_layer != null:
			_toggle_pause()
			get_viewport().set_input_as_handled()


func _apply_theme() -> void:
	var game_theme := Theme.new()
	if _font != null:
		game_theme.default_font = _font
	game_theme.default_font_size = 20
	theme = game_theme
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL


func _build_base() -> void:
	_background = TextureRect.new()
	_background.name = "المشهد"
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_shade = ColorRect.new()
	_shade.name = "تعتيم المشهد"
	_shade.color = Color(0.012, 0.025, 0.029, 0.42)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)


func _build_title_screen() -> void:
	_title_layer = Control.new()
	_title_layer.name = "شاشة البداية"
	_title_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_layer.layout_direction = Control.LAYOUT_DIRECTION_RTL
	add_child(_title_layer)

	_title_panel = PanelContainer.new()
	_title_panel.name = "بطاقة البداية"
	_title_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_INK))
	_title_layer.add_child(_title_panel)
	_layout_centered_panel(_title_panel, 780.0, 650.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_title_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	content.layout_direction = Control.LAYOUT_DIRECTION_RTL
	scroll.add_child(content)

	var eyebrow := _label("حكاية بقاء عربية تفاعلية", 17, COLOR_TEAL, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(eyebrow)
	var title := _label("آخر رحلة", 52, COLOR_PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	title.custom_minimum_size = Vector2(0, 66)
	content.add_child(title)
	var tagline := _label("العالم لم يعد كما كان.", 25, COLOR_SAND, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(tagline)
	var intro := _label("من السعودية إلى تشاد، طريقٌ واحد وثلاث بدايات وقراراتٌ لا تعود إلى الوراء.", 20, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)

	var separator := ColorRect.new()
	separator.color = Color(0.62, 0.54, 0.4, 0.5)
	separator.custom_minimum_size = Vector2(0, 1)
	content.add_child(separator)

	var name_caption := _label("اسم الناجي", 18, COLOR_PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	content.add_child(name_caption)
	_name_input = LineEdit.new()
	_name_input.name = "اسم الناجي"
	_name_input.text = ""
	_name_input.placeholder_text = "محسن"
	_name_input.max_length = 24
	_name_input.custom_minimum_size = Vector2(0, 58)
	_name_input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_name_input.virtual_keyboard_enabled = true
	_name_input.virtual_keyboard_show_on_focus = true
	_name_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_name_input.select_all_on_focus = true
	_set_rtl(_name_input)
	_style_field(_name_input)
	content.add_child(_name_input)

	var country_caption := _label("مكان الهبوط الاضطراري", 18, COLOR_PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	content.add_child(country_caption)
	_country_input = OptionButton.new()
	_country_input.name = "مكان الهبوط"
	_country_input.add_item("مصر", 0)
	_country_input.add_item("المغرب", 1)
	_country_input.add_item("تشاد — البداية من الجنوب", 2)
	_country_input.selected = 0
	_country_input.custom_minimum_size = Vector2(0, 58)
	_set_rtl(_country_input)
	_style_option(_country_input)
	content.add_child(_country_input)

	var start_button := _button("ابدأ الرحلة", true)
	start_button.name = "زر بدء الرحلة"
	start_button.custom_minimum_size = Vector2(0, 64)
	start_button.pressed.connect(_start_game)
	content.add_child(start_button)

	var session_note := _label("تقدمك مؤقت لهذه الجلسة؛ لا يُحفظ عند إغلاق الصفحة.", 16, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	session_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(session_note)


func _build_story_screen() -> void:
	_story_layer = Control.new()
	_story_layer.name = "اللعب"
	_story_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_story_layer.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_story_layer.visible = false
	add_child(_story_layer)

	var hud := PanelContainer.new()
	hud.name = "شريط الحالة"
	_hud_panel = hud
	hud.add_theme_stylebox_override("panel", _panel_style(COLOR_INK_SOFT))
	hud.anchor_left = 0.025
	hud.anchor_right = 0.975
	hud.anchor_top = 0.025
	hud.anchor_bottom = 0.255
	hud.offset_left = 0
	hud.offset_right = 0
	hud.offset_top = 0
	hud.offset_bottom = 0
	_story_layer.add_child(hud)

	var hud_margin := MarginContainer.new()
	hud_margin.add_theme_constant_override("margin_left", 16)
	hud_margin.add_theme_constant_override("margin_right", 16)
	hud_margin.add_theme_constant_override("margin_top", 10)
	hud_margin.add_theme_constant_override("margin_bottom", 10)
	hud.add_child(hud_margin)

	var hud_stack := VBoxContainer.new()
	hud_stack.add_theme_constant_override("separation", 6)
	hud_stack.layout_direction = Control.LAYOUT_DIRECTION_RTL
	hud_margin.add_child(hud_stack)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	hud_stack.add_child(top_row)
	_hud_location = _label("الموقع: —", 20, COLOR_PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	_hud_location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_hud_location)
	_pause_button = _button("إيقاف", false)
	_pause_button.custom_minimum_size = Vector2(128, 48)
	_pause_button.pressed.connect(_toggle_pause)
	top_row.add_child(_pause_button)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	grid.layout_direction = Control.LAYOUT_DIRECTION_RTL
	hud_stack.add_child(grid)
	_hud_day = _hud_chip()
	_hud_health = _hud_chip()
	_hud_water = _hud_chip()
	_hud_food = _hud_chip()
	_hud_trust = _hud_chip()
	_hud_companions = _hud_chip()
	for chip: Label in [_hud_day, _hud_health, _hud_water, _hud_food, _hud_trust, _hud_companions]:
		grid.add_child(chip)

	_story_panel = PanelContainer.new()
	_story_panel.name = "بطاقة المشهد والاختيارات"
	_story_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_INK))
	_story_panel.anchor_left = 0.035
	_story_panel.anchor_right = 0.965
	_story_panel.anchor_top = 0.39
	_story_panel.anchor_bottom = 0.975
	_story_panel.offset_left = 0
	_story_panel.offset_right = 0
	_story_panel.offset_top = 0
	_story_panel.offset_bottom = 0
	_story_layer.add_child(_story_panel)

	var story_margin := MarginContainer.new()
	story_margin.add_theme_constant_override("margin_left", 20)
	story_margin.add_theme_constant_override("margin_right", 20)
	story_margin.add_theme_constant_override("margin_top", 14)
	story_margin.add_theme_constant_override("margin_bottom", 12)
	_story_panel.add_child(story_margin)

	var story_scroll := ScrollContainer.new()
	story_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	story_margin.add_child(story_scroll)

	var story_content := VBoxContainer.new()
	story_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_content.add_theme_constant_override("separation", 7)
	story_content.layout_direction = Control.LAYOUT_DIRECTION_RTL
	story_scroll.add_child(story_content)

	_scene_title = _label("", 29, COLOR_SAND, HORIZONTAL_ALIGNMENT_RIGHT)
	_scene_title.custom_minimum_size = Vector2(0, 38)
	story_content.add_child(_scene_title)
	_speaker_label = _label("", 18, COLOR_TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	story_content.add_child(_speaker_label)
	_story_text = _label("", 21, COLOR_PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	_story_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_text.custom_minimum_size = Vector2(0, 90)
	story_content.add_child(_story_text)
	_result_label = _label("", 17, COLOR_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_content.add_child(_result_label)

	var choice_separator := ColorRect.new()
	choice_separator.color = Color(0.62, 0.54, 0.4, 0.5)
	choice_separator.custom_minimum_size = Vector2(0, 1)
	story_content.add_child(choice_separator)
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 7)
	_choices_box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	story_content.add_child(_choices_box)


func _build_pause_screen() -> void:
	_pause_layer = Control.new()
	_pause_layer.name = "قائمة الإيقاف"
	_pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_pause_layer.visible = false
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(dim)

	_pause_panel = PanelContainer.new()
	_pause_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_INK))
	_pause_layer.add_child(_pause_panel)
	_layout_centered_panel(_pause_panel, 540.0, 390.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_pause_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.layout_direction = Control.LAYOUT_DIRECTION_RTL
	margin.add_child(content)
	content.add_child(_label("توقفت الرحلة", 34, COLOR_PAPER, HORIZONTAL_ALIGNMENT_CENTER))
	var note := _label("لا يوجد حفظ دائم؛ يمكن استئناف هذه الجلسة أو البدء من جديد.", 18, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	var resume := _button("تابع الرحلة", true)
	resume.custom_minimum_size = Vector2(0, 52)
	resume.pressed.connect(func() -> void: _pause_layer.visible = false)
	content.add_child(resume)
	var restart := _button("ابدأ الرحلة من جديد", false)
	restart.custom_minimum_size = Vector2(0, 50)
	restart.pressed.connect(_restart_run)
	content.add_child(restart)
	var back := _button("العودة إلى البداية", false)
	back.custom_minimum_size = Vector2(0, 50)
	back.pressed.connect(_show_title)
	content.add_child(back)


func _start_game() -> void:
	var entered_name := _name_input.text.strip_edges()
	_last_name = "محسن" if entered_name.is_empty() else entered_name
	var selected := _country_input.get_selected_id()
	_last_country = ["egypt", "morocco", "chad"][clampi(selected, 0, 2)]
	if not _engine.start(_last_name, _last_country):
		_show_fatal_message("تعذر بدء الرحلة. أعد تحميل اللعبة وحاول مرة أخرى.")
		return
	_result_note = ""
	_title_layer.visible = false
	_story_layer.visible = true
	_pause_layer.visible = false
	_render_scene()


func _restart_run() -> void:
	if _engine.start(_last_name, _last_country):
		_result_note = ""
		_pause_layer.visible = false
		_story_layer.visible = true
		_render_scene()


func _show_title() -> void:
	if _title_layer != null:
		_title_layer.visible = true
	if _story_layer != null:
		_story_layer.visible = false
	if _pause_layer != null:
		_pause_layer.visible = false
	_set_background(TITLE_BACKGROUND)
	get_viewport().gui_release_focus()


func _toggle_pause() -> void:
	if _pause_layer == null or _story_layer == null or not _story_layer.visible:
		return
	_pause_layer.visible = not _pause_layer.visible


func _render_scene() -> void:
	var scene: Dictionary = _engine.get_scene()
	if scene.is_empty():
		_show_fatal_message("تعذر العثور على مشهد القصة التالي.")
		return
	var country := str(_engine.state.get("country", "egypt"))
	var background := _scene_value(scene, "background", "background_by_country", country)
	if not background.is_empty():
		_set_background("res://" + background.trim_prefix("res://"))
	_scene_title.text = _format_text(str(scene.get("title", "")))
	_speaker_label.text = _format_text(str(scene.get("speaker", "")))
	_speaker_label.visible = not _speaker_label.text.is_empty()
	_story_text.text = _format_text(str(scene.get("text", "")))
	_result_label.text = _result_note
	_update_status(scene, country)
	_clear_choices()
	if str(scene.get("kind", "")) == "ending":
		_add_ending_buttons()
	else:
		var choices := _engine.get_choices()
		for index: int in choices.size():
			_add_choice_button(choices[index], index)
	if _choices_box.get_child_count() > 0:
		var first := _choices_box.get_child(0)
		if first is Control:
			(first as Control).grab_focus()


func _update_status(scene: Dictionary, country: String) -> void:
	var state: Dictionary = _engine.get_state()
	var location := _scene_value(scene, "location", "location_by_country", country)
	_hud_location.text = "الموقع: " + _format_text(location)
	_hud_day.text = "اليوم " + str(state.get("days", 1))
	_hud_health.text = "الصحة " + str(state.get("health", 3)) + "/3"
	_hud_water.text = "الماء " + str(state.get("water", 0))
	_hud_food.text = "الطعام " + str(state.get("food", 0))
	_hud_trust.text = "الثقة " + str(state.get("trust", 0))
	var companions: Array = state.get("companions", [])
	var companion_names := PackedStringArray()
	for companion: Variant in companions:
		companion_names.append(str(companion))
	_hud_companions.text = "الرفاق: " + ("، ".join(companion_names) if not companion_names.is_empty() else "لا أحد")
	_hud_companions.visible = not companions.is_empty()


func _add_choice_button(choice: Dictionary, visible_index: int) -> void:
	var caption := _format_text(str(choice.get("text", "اختيار")))
	var button := Button.new()
	button.name = "اختيار_" + str(choice.get("id", visible_index))
	button.tooltip_text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, _choice_height(caption))
	button.add_theme_stylebox_override("normal", _button_style(false, false))
	button.add_theme_stylebox_override("hover", _button_style(false, true))
	button.add_theme_stylebox_override("pressed", _button_style(true, false))
	button.add_theme_stylebox_override("focus", _focus_style())
	button.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	button.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	button.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	button.add_theme_font_size_override("font_size", 1)
	button.text = caption
	button.pressed.connect(_on_choice_selected.bind(visible_index, caption))
	_choices_box.add_child(button)

	var label := _label(caption, 16, COLOR_PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 16
	label.offset_right = -16
	label.offset_top = 5
	label.offset_bottom = -5
	button.add_child(label)


func _add_ending_buttons() -> void:
	var again := _button("أعد الرحلة", true)
	again.custom_minimum_size = Vector2(0, 54)
	again.pressed.connect(_restart_run)
	_choices_box.add_child(again)
	var title_button := _button("العودة إلى البداية", false)
	title_button.custom_minimum_size = Vector2(0, 50)
	title_button.pressed.connect(_show_title)
	_choices_box.add_child(title_button)


func _on_choice_selected(index: int, caption: String) -> void:
	var result: Dictionary = _engine.choose(index)
	if not bool(result.get("ok", false)):
		_result_note = "تعذر تنفيذ الاختيار. اختر خيارًا آخر."
		_render_scene()
		return
	_result_note = "قرارك: " + caption
	_pause_layer.visible = false
	_render_scene()


func _clear_choices() -> void:
	for child: Node in _choices_box.get_children():
		_choices_box.remove_child(child)
		child.queue_free()


func _scene_value(scene: Dictionary, plain_key: String, country_key: String, country: String) -> String:
	if scene.has(country_key):
		var values: Variant = scene.get(country_key, {})
		if values is Dictionary:
			var country_values: Dictionary = values
			return str(country_values.get(country, scene.get(plain_key, "")))
	return str(scene.get(plain_key, ""))


func _format_text(value: String) -> String:
	var result := value
	var state: Dictionary = _engine.get_state() if _engine != null else {}
	var country := str(state.get("country", "egypt"))
	result = result.replace("{player}", str(state.get("player_name", _last_name)))
	result = result.replace("{country_label}", str(_country_labels.get(country, "تشاد")))
	return result


func _set_background(path: String) -> void:
	if path == _current_background:
		return
	var texture := load(path) as Texture2D
	if texture == null:
		texture = load(TITLE_BACKGROUND) as Texture2D
		path = TITLE_BACKGROUND
	_background.texture = texture
	_current_background = path


func _label(text_value: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	_set_rtl(label)
	return label


func _hud_chip() -> Label:
	var chip := _label("", 17, COLOR_PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.custom_minimum_size = Vector2(0, 30)
	return chip


func _button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_stylebox_override("normal", _button_style(primary, false))
	button.add_theme_stylebox_override("hover", _button_style(primary, true))
	button.add_theme_stylebox_override("pressed", _button_style(true, false))
	button.add_theme_stylebox_override("focus", _focus_style())
	button.add_theme_color_override("font_color", COLOR_PAPER if primary else COLOR_SAND)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", COLOR_PAPER)
	button.add_theme_font_size_override("font_size", 19)
	_set_rtl(button)
	return button


func _style_field(control: Control) -> void:
	var field_style := StyleBoxFlat.new()
	field_style.bg_color = Color(0.12, 0.15, 0.15, 1.0)
	field_style.border_color = Color(0.53, 0.48, 0.38, 0.85)
	field_style.set_border_width_all(1)
	field_style.set_corner_radius_all(8)
	field_style.content_margin_left = 12
	field_style.content_margin_right = 12
	field_style.content_margin_top = 6
	field_style.content_margin_bottom = 6
	control.add_theme_stylebox_override("normal", field_style)
	control.add_theme_color_override("font_color", COLOR_PAPER)
	control.add_theme_color_override("font_placeholder_color", COLOR_MUTED)
	control.add_theme_font_size_override("font_size", 20)


func _style_option(control: Control) -> void:
	var field_style := _panel_style(Color(0.12, 0.15, 0.15, 1.0))
	field_style.border_color = Color(0.53, 0.48, 0.38, 0.85)
	field_style.set_border_width_all(1)
	control.add_theme_stylebox_override("normal", field_style)
	control.add_theme_stylebox_override("hover", _panel_style(Color(0.16, 0.20, 0.19, 1.0)))
	control.add_theme_color_override("font_color", COLOR_PAPER)
	control.add_theme_font_size_override("font_size", 20)


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.73, 0.54, 0.32, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 8
	return style


func _button_style(primary: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if primary:
		style.bg_color = Color(0.25, 0.52, 0.48, 1.0) if not hovered else Color(0.31, 0.63, 0.56, 1.0)
		style.border_color = Color(0.57, 0.82, 0.72, 0.9)
	else:
		style.bg_color = Color(0.13, 0.18, 0.18, 0.96) if not hovered else Color(0.19, 0.27, 0.25, 1.0)
		style.border_color = Color(0.62, 0.52, 0.36, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = COLOR_TEAL
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style


func _set_rtl(control: Control) -> void:
	control.layout_direction = Control.LAYOUT_DIRECTION_RTL


func _choice_height(caption: String) -> float:
	var viewport_width := get_viewport_rect().size.x
	var estimated_characters_per_line := maxi(18, int((viewport_width - 92.0) / 11.0))
	var lines := maxi(1, int(ceil(float(caption.length()) / float(estimated_characters_per_line))))
	return maxf(64.0, float(lines * 28 + 26))


func _layout_centered_panel(panel: PanelContainer, max_width: float, max_height: float) -> void:
	if panel == null or not is_inside_tree():
		return
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var panel_width := minf(max_width, maxf(280.0, view.x - 28.0))
	var panel_height := minf(max_height, maxf(300.0, view.y - 28.0))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width / 2.0
	panel.offset_right = panel_width / 2.0
	panel.offset_top = -panel_height / 2.0
	panel.offset_bottom = panel_height / 2.0


func _show_fatal_message(message: String) -> void:
	var error_label := _label(message, 20, COLOR_PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	error_label.custom_minimum_size = Vector2(520, 120)
	add_child(error_label)


func _exit_tree() -> void:
	# The game stores progress only in these in-memory objects; nothing is written to user:// or browser storage.
	if _engine != null:
		_engine.state.clear()
