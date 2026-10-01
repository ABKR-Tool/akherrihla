extends SceneTree

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	_check(ProjectSettings.get_setting("application/config/name") == "آخر رحلة", "هوية اللعبة العربية في الحزمة")
	_check(FileAccess.file_exists("res://data/story_ar.json"), "ملف القصة داخل الحزمة")
	var arabic_font := load("res://assets/fonts/NotoSansArabic-Regular.ttf") as Font
	_check(arabic_font != null, "خط العربية داخل الحزمة")
	for path: String in [
		"assets/story/runtime/plane_crash.png",
		"assets/story/runtime/egypt_ruins.png",
		"assets/story/runtime/morocco_checkpoint.png",
		"assets/story/runtime/chad_desert.png",
		"assets/share/og.png",
		"assets/share/favicon.png",
	]:
		_check(ResourceLoader.exists("res://" + path), "أصل مُصدّر: " + path)
	_check(not ResourceLoader.exists("res://test/test_suite.tscn"), "استبعاد مشهد الاختبار")
	_check(root.get_node_or_null("SaveStore") == null, "لا يوجد حفظ دائم")
	_check(root.get_node_or_null("I18n") == null, "لا يوجد تبديل لغة")
	_check(root.get_node_or_null("AudioDirector") == null, "لا توجد موسيقى أو مؤثرات")

	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "مشهد البداية داخل الحزمة")
	if packed != null:
		var main := packed.instantiate()
		root.add_child(main)
		await process_frame
		await process_frame
		var title_layer := main.get("_title_layer") as Control
		_check(title_layer != null and title_layer.visible, "تفتح الحزمة على شاشة العنوان")
		var country_input := main.get("_country_input") as OptionButton
		var name_input := main.get("_name_input") as LineEdit
		if country_input != null and name_input != null:
			country_input.selected = 2
			name_input.text = "محسن"
			main.call("_start_game")
			await process_frame
			var game_layer := main.get("_story_layer") as Control
			var heading := main.get("_scene_title") as Label
			var body := main.get("_story_text") as Label
			var engine := main.get("_engine") as StoryEngine
			_check(game_layer != null and game_layer.visible, "تبدأ اللعبة من واجهة العنوان")
			_check(heading != null and heading.text == "قبل الانقطاع", "مشهد الطائرة يعرض عنوانه")
			_check(body != null and body.text.contains("السعودية"), "نص الرحلة ظاهر بالعربية")
			_check(engine != null and engine.get_state().get("country", "") == "chad", "الحزمة تفعل مسار تشاد")
			_check(engine != null and engine.get_state().get("player_name", "") == "محسن", "اسم الناجي الافتراضي")
		main.queue_free()
		await process_frame

	var story_engine := StoryEngine.new()
	_check(story_engine.load_story(), "قراءة القصة من الحزمة")
	if not story_engine.story.is_empty():
		_check(story_engine.start("محسن", "chad"), "بدء مسار النجاة التشادي")
		for choice_id: String in ["check_supplies", "help_landing", "search_cockpit", "seek_help_chad", "join_moussa", "follow_chad_tracks", "long_road", "track_plane_chad", "start_plane"]:
			_check(_choose_id(story_engine, choice_id), "مسار تشاد: " + choice_id)
		_check(story_engine.current_id == "ending_escape", "الوصول إلى نهاية النجاة في الحزمة")

	if _failures.is_empty():
		print("[last-journey-pack] PASS: %d checks" % _checks)
		quit(0)
	else:
		for failure: String in _failures:
			push_error("[last-journey-pack] " + failure)
		print("[last-journey-pack] FAIL: %d إخفاقًا من أصل %d" % [_failures.size(), _checks])
		quit(1)


func _choose_id(engine: StoryEngine, choice_id: String) -> bool:
	var choices := engine.get_choices()
	for index: int in range(choices.size()):
		if str(choices[index].get("id", "")) == choice_id:
			return bool(engine.choose(index).get("ok", false))
	return false


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
