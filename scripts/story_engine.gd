class_name StoryEngine
extends RefCounted

const STORY_PATH := "res://data/story_ar.json"
const MAX_HEALTH := 3
const MAX_RESOURCE := 5
const STARTING_COUNTRIES := ["egypt", "morocco", "chad"]

var story: Dictionary = {}
var state: Dictionary = {}
var current_id := ""


func load_story() -> bool:
	if not FileAccess.file_exists(STORY_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_PATH))
	if not (parsed is Dictionary):
		return false
	story = parsed
	var scenes: Dictionary = story.get("scenes", {})
	return story.has("start") and not scenes.is_empty()


func start(player_name: String, country: String) -> bool:
	if not STARTING_COUNTRIES.has(country):
		return false
	if story.is_empty() and not load_story():
		return false
	var clean_name := player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "محسن"
	state = {
		"player_name": clean_name,
		"country": country,
		"health": MAX_HEALTH,
		"food": 3,
		"water": 3,
		"trust": 0,
		"days": 1,
		"flags": {},
		"companions": [],
		"alive": true,
	}
	current_id = str(story.get("start", "flight_intro"))
	return not get_scene().is_empty()


func get_scene() -> Dictionary:
	var scenes: Dictionary = story.get("scenes", {})
	var raw_scene: Variant = scenes.get(current_id, {})
	if raw_scene is Dictionary:
		return raw_scene.duplicate(true)
	return {}


func get_choices() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	var scene := get_scene()
	for raw_choice: Variant in scene.get("choices", []):
		if not (raw_choice is Dictionary):
			continue
		var choice: Dictionary = raw_choice
		if _requirements_met(choice.get("requires", {})):
			available.append(choice.duplicate(true))
	return available


func choose(index: int) -> Dictionary:
	var choices := get_choices()
	if index < 0 or index >= choices.size():
		return {"ok": false, "error": "اختيار غير متاح"}
	var choice: Dictionary = choices[index]
	var destination := str(choice.get("next", ""))
	var raw_routes: Variant = choice.get("next_by_country", {})
	if raw_routes is Dictionary:
		var routes: Dictionary = raw_routes
		destination = str(routes.get(str(state.get("country", "")), destination))
	var scenes: Dictionary = story.get("scenes", {})
	if destination.is_empty() or not scenes.has(destination):
		return {"ok": false, "error": "المشهد التالي غير موجود: " + destination}

	_apply_choice(choice)
	current_id = destination
	if int(state.get("health", MAX_HEALTH)) <= 0:
		current_id = "ending_hunger" if _resources_exhausted() else "ending_alone"
		state["alive"] = false
	return {
		"ok": true,
		"scene_id": current_id,
		"ending": str(get_scene().get("kind", "")) == "ending",
	}


func get_state() -> Dictionary:
	return state.duplicate(true)


func scene_ids() -> Array:
	var scenes: Dictionary = story.get("scenes", {})
	var ids: Array = scenes.keys()
	ids.sort()
	return ids


func _requirements_met(requirements: Variant) -> bool:
	if not (requirements is Dictionary):
		return true
	var req: Dictionary = requirements
	if req.has("trust_min") and int(state.get("trust", 0)) < int(req["trust_min"]):
		return false
	if req.has("water_min") and int(state.get("water", 0)) < int(req["water_min"]):
		return false
	if req.has("food_min") and int(state.get("food", 0)) < int(req["food_min"]):
		return false
	if req.has("country") and str(state.get("country", "")) != str(req["country"]):
		return false
	var flags: Dictionary = state.get("flags", {})
	if req.has("flag") and not bool(flags.get(str(req["flag"]), false)):
		return false
	if req.has("no_flag") and bool(flags.get(str(req["no_flag"]), false)):
		return false
	var companions: Array = state.get("companions", [])
	if req.has("companion") and not companions.has(str(req["companion"])):
		return false
	return true


func _apply_choice(choice: Dictionary) -> void:
	var effects: Dictionary = choice.get("effects", {})
	for stat: String in ["health", "food", "water", "trust"]:
		var updated := int(state.get(stat, 0)) + int(effects.get(stat, 0))
		if stat == "health":
			state[stat] = clampi(updated, 0, MAX_HEALTH)
		elif stat == "food" or stat == "water":
			state[stat] = clampi(updated, 0, MAX_RESOURCE)
		else:
			state[stat] = clampi(updated, -3, 5)

	var flags: Dictionary = state.get("flags", {})
	var raw_new_flags: Variant = effects.get("set_flags", {})
	if raw_new_flags is Dictionary:
		var new_flags: Dictionary = raw_new_flags
		for flag: Variant in new_flags.keys():
			flags[str(flag)] = new_flags[flag]
	state["flags"] = flags

	var companions: Array = state.get("companions", [])
	var add_companion := str(effects.get("add_companion", ""))
	if not add_companion.is_empty() and not companions.has(add_companion):
		companions.append(add_companion)
	var remove_companion := str(effects.get("remove_companion", ""))
	if not remove_companion.is_empty():
		companions.erase(remove_companion)
	state["companions"] = companions
	_advance_days(maxi(0, int(effects.get("days", 0))))


func _advance_days(count: int) -> void:
	for _day in range(count):
		state["days"] = int(state.get("days", 1)) + 1
		if int(state["days"]) % 2 == 0:
			_consume("water")
		if int(state["days"]) % 3 == 0:
			_consume("food")


func _consume(resource: String) -> void:
	if int(state.get(resource, 0)) > 0:
		state[resource] = int(state[resource]) - 1
	else:
		state["health"] = maxi(0, int(state.get("health", MAX_HEALTH)) - 1)


func _resources_exhausted() -> bool:
	return int(state.get("water", 0)) <= 0 or int(state.get("food", 0)) <= 0
