extends Node

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_engine := StoryEngine.new()
	_check(source_engine.load_story(), "قراءة ملف القصة")
	if source_engine.story.is_empty():
		_finish()
		return

	var scenes: Dictionary = source_engine.story.get("scenes", {})
	_check(scenes.size() >= 30, "وجود مشاهد كافية للمسارات")
	var ending_ids := ["ending_alone", "ending_hunger", "ending_desert", "ending_mercenaries", "ending_zombies", "ending_escape"]
	for ending_id: String in ending_ids:
		_check(scenes.has(ending_id), "النهاية موجودة: " + ending_id)
		if scenes.has(ending_id):
			_check(str(scenes[ending_id].get("kind", "")) == "ending", "نوع نهاية صحيح: " + ending_id)

	for scene_id: Variant in scenes.keys():
		var raw_scene: Variant = scenes[scene_id]
		_check(raw_scene is Dictionary, "بيانات المشهد صالحة: " + str(scene_id))
		if not (raw_scene is Dictionary):
			continue
		var scene: Dictionary = raw_scene
		_check(_has_arabic(str(scene.get("title", ""))), "عنوان عربي: " + str(scene_id))
		_check(_has_arabic(str(scene.get("text", ""))), "حوار عربي: " + str(scene_id))
		if scene.has("background"):
			var image_path := str(scene["background"]).trim_prefix("res://")
			_check(ResourceLoader.exists("res://" + image_path), "خلفية موجودة: " + str(scene_id))
		if scene.has("background_by_country"):
			var backgrounds: Dictionary = scene["background_by_country"]
			for country: Variant in backgrounds.keys():
				var image_path := str(backgrounds[country]).trim_prefix("res://")
				_check(ResourceLoader.exists("res://" + image_path), "خلفية المسار موجودة: " + str(scene_id) + "/" + str(country))
		for choice_value: Variant in scene.get("choices", []):
			_check(choice_value is Dictionary, "بنية اختيار صالحة: " + str(scene_id))
			if not (choice_value is Dictionary):
				continue
			var choice: Dictionary = choice_value
			_check(_has_arabic(str(choice.get("text", ""))), "اختيار عربي: " + str(scene_id))
			var destinations := _destinations(choice)
			_check(not destinations.is_empty(), "للاختيار وجهة: " + str(scene_id))
			for destination: String in destinations:
				_check(scenes.has(destination), "وجهة صحيحة: " + str(scene_id) + " ← " + destination)

	for country: String in ["egypt", "morocco", "chad"]:
		var reachable := _reachable(source_engine.story, country)
		for ending_id: String in ending_ids:
			_check(reachable.has(ending_id), "النهاية " + ending_id + " متاحة لمسار " + country)

	var safe_paths := {
		"egypt": ["check_supplies", "help_landing", "search_cockpit", "tell_truth", "share_with_salem", "canal_path", "fill_bottle", "old_south_road", "bargain_adel", "use_map_egypt", "start_plane"],
		"morocco": ["check_supplies", "help_landing", "search_cockpit", "truth_guard", "join_yassin", "search_food_morocco", "avoid_morocco_stranger", "bargain_rashid", "follow_milestones", "take_beacon_morocco", "start_plane"],
		"chad": ["check_supplies", "help_landing", "search_cockpit", "seek_help_chad", "join_moussa", "follow_chad_tracks", "long_road", "track_plane_chad", "start_plane"],
	}
	for country: String in safe_paths.keys():
		var play_engine := StoryEngine.new()
		play_engine.story = source_engine.story.duplicate(true)
		_check(play_engine.start("محسن", country), "بدء الجولة: " + country)
		for choice_id: String in safe_paths[country]:
			_check(_choose_id(play_engine, choice_id), "اختيار مسار " + country + ": " + choice_id)
		_check(play_engine.current_id == "ending_escape", "نجاة فعلية عبر المسار: " + country)
		_check(str(play_engine.get_scene().get("kind", "")) == "ending", "مشهد النجاة نهاية فعلية: " + country)

	var gates := StoryEngine.new()
	gates.story = source_engine.story.duplicate(true)
	_check(gates.start("اختبار", "chad"), "بدء اختبار شروط الوصول")
	gates.current_id = "final_airfield"
	gates.state["water"] = 0
	gates.state["flags"] = {}
	var gated_ids := _choice_ids(gates)
	_check(not gated_ids.has("start_plane"), "الطائرة لا تعمل بلا دليل مسار")
	_check(not gated_ids.has("radio_plane"), "إشارة الاستغاثة تحتاج إلى ماء")
	_check(gates.choose(-1).get("ok", true) == false, "رفض فهرس اختيار خارج النطاق")
	_check(gates.start("", "egypt"), "إعادة ضبط جلسة المتصفح")
	_check(str(gates.get_state().get("player_name", "")) == "محسن", "الاسم الافتراضي عند تركه فارغًا")
	_check(gates.get_state().get("water", -1) == 3 and gates.get_state().get("companions", []).is_empty(), "إعادة المحاولة تبدأ بموارد ورفاق جدد")
	_check(not gates.start("اختبار", "unknown"), "رفض رمز بلد غير معروف")

	var font := load("res://assets/fonts/NotoSansArabic-Regular.ttf") as Font
	_check(font != null, "خط عربي مضمن")
	if font != null:
		for codepoint: int in [0x0627, 0x0645, 0x064A, 0x0629]:
			_check(font.has_char(codepoint), "تغطية الخط لحرف عربي: " + str(codepoint))

	var main_scene := load("res://scenes/main.tscn") as PackedScene
	_check(main_scene != null, "تحميل مشهد اللعبة")
	if main_scene != null:
		var main := main_scene.instantiate()
		get_tree().root.add_child(main)
		await get_tree().process_frame
		await get_tree().process_frame
		var title_layer := main.get("_title_layer") as Control
		_check(title_layer != null and title_layer.visible, "تبدأ الواجهة من شاشة العنوان")
		var name_input := main.get("_name_input") as LineEdit
		var country_input := main.get("_country_input") as OptionButton
		if name_input != null and country_input != null:
			name_input.text = ""
			country_input.selected = 2
			main.call("_start_game")
			await get_tree().process_frame
			var game_engine := main.get("_engine") as StoryEngine
			var story_layer := main.get("_story_layer") as Control
			var scene_title := main.get("_scene_title") as Label
			var story_text := main.get("_story_text") as Label
			_check(story_layer != null and story_layer.visible, "واجهة اللعب تظهر عند البدء")
			_check(game_engine != null and game_engine.get_state().get("country", "") == "chad", "اختيار بلد الهبوط يفعّل مساره")
			_check(game_engine != null and game_engine.get_state().get("player_name", "") == "محسن", "الاسم الافتراضي في الواجهة")
			_check(scene_title != null and scene_title.text == "قبل الانقطاع", "عنوان مشهد البداية يظهر")
			_check(story_text != null and story_text.text.contains("السعودية"), "حوار البداية يصل إلى واجهة اللعبة")
		_check(get_tree().root.get_node_or_null("SaveStore") == null, "لا يوجد مخزن حفظ دائم")
		main.queue_free()
		await get_tree().process_frame

	_finish()


func _destinations(choice: Dictionary) -> Array[String]:
	var output: Array[String] = []
	var next_id := str(choice.get("next", ""))
	if not next_id.is_empty():
		output.append(next_id)
	var raw_routes: Variant = choice.get("next_by_country", {})
	if raw_routes is Dictionary:
		var routes: Dictionary = raw_routes
		for country: Variant in routes.keys():
			var destination := str(routes[country])
			if not destination.is_empty() and not output.has(destination):
				output.append(destination)
	return output


func _reachable(story_data: Dictionary, country: String) -> Dictionary:
	var scenes: Dictionary = story_data.get("scenes", {})
	var queue: Array[String] = [str(story_data.get("start", ""))]
	var visited: Dictionary = {}
	while not queue.is_empty():
		var scene_id: String = queue.pop_front()
		if visited.has(scene_id) or not scenes.has(scene_id):
			continue
		visited[scene_id] = true
		var scene: Dictionary = scenes[scene_id]
		for choice_value: Variant in scene.get("choices", []):
			if not (choice_value is Dictionary):
				continue
			var choice: Dictionary = choice_value
			var target := str(choice.get("next", ""))
			var raw_routes: Variant = choice.get("next_by_country", {})
			if raw_routes is Dictionary:
				var routes: Dictionary = raw_routes
				target = str(routes.get(country, target))
			if not target.is_empty() and not visited.has(target):
				queue.append(target)
	return visited


func _choose_id(engine: StoryEngine, choice_id: String) -> bool:
	var choices := engine.get_choices()
	for index: int in range(choices.size()):
		if str(choices[index].get("id", "")) == choice_id:
			return bool(engine.choose(index).get("ok", false))
	return false


func _choice_ids(engine: StoryEngine) -> Array[String]:
	var ids: Array[String] = []
	for choice: Dictionary in engine.get_choices():
		ids.append(str(choice.get("id", "")))
	return ids


func _has_arabic(text: String) -> bool:
	for index: int in range(text.length()):
		var codepoint := text.unicode_at(index)
		if codepoint >= 0x0600 and codepoint <= 0x06FF:
			return true
	return false


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		push_error("[اختبارات آخر رحلة] " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("[last-journey-tests] PASS: %d checks" % _checks)
		get_tree().quit(0)
	else:
		push_error("[last-journey-tests] FAIL: %d إخفاقًا من أصل %d" % [_failures.size(), _checks])
		get_tree().quit(1)
