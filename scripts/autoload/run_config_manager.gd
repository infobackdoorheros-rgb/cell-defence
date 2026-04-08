extends Node

signal core_archetype_changed(archetype_id: StringName)
signal chapter_changed(chapter_id: StringName)
signal ftue_state_changed(completed: bool)
signal menu_tutorial_state_changed(completed: bool)

const DEFAULT_CORE_ARCHETYPE: StringName = &"sentinel_core"
const DEFAULT_CHAPTER: StringName = &"chapter_capillary"
const CURRENT_FTUE_VERSION: int = 2

var selected_core_archetype: StringName = DEFAULT_CORE_ARCHETYPE
var selected_chapter: StringName = DEFAULT_CHAPTER
var ftue_completed: bool = false
var menu_tutorial_completed: bool = false
var ftue_version: int = 0

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	var save_data := SaveManager.get_save()
	var profile := save_data.get("run_profile", {}) as Dictionary
	selected_core_archetype = StringName(profile.get("selected_core_archetype", String(DEFAULT_CORE_ARCHETYPE)))
	selected_chapter = StringName(profile.get("selected_chapter", String(DEFAULT_CHAPTER)))
	ftue_completed = bool(profile.get("ftue_completed", false))
	menu_tutorial_completed = bool(profile.get("menu_tutorial_completed", false))
	ftue_version = int(profile.get("ftue_version", 0))

	if ContentDB.get_core_archetype(selected_core_archetype) == null:
		selected_core_archetype = DEFAULT_CORE_ARCHETYPE
	if ContentDB.get_chapter(selected_chapter) == null:
		selected_chapter = DEFAULT_CHAPTER

func save_profile() -> void:
	SaveManager.write_save({
		"run_profile": {
			"selected_core_archetype": String(selected_core_archetype),
			"selected_chapter": String(selected_chapter),
			"ftue_completed": ftue_completed,
			"menu_tutorial_completed": menu_tutorial_completed,
			"ftue_version": ftue_version
		}
	})

func set_selected_core_archetype(archetype_id: StringName) -> void:
	if ContentDB.get_core_archetype(archetype_id) == null:
		return
	selected_core_archetype = archetype_id
	AnalyticsManager.track_event(&"core_archetype_selected", {"archetype_id": String(archetype_id)})
	save_profile()
	core_archetype_changed.emit(selected_core_archetype)

func set_selected_chapter(chapter_id: StringName) -> void:
	if ContentDB.get_chapter(chapter_id) == null:
		return
	selected_chapter = chapter_id
	AnalyticsManager.track_event(&"chapter_selected", {"chapter_id": String(chapter_id)})
	save_profile()
	chapter_changed.emit(selected_chapter)

func get_selected_core_archetype():
	return ContentDB.get_core_archetype(selected_core_archetype)

func get_selected_chapter():
	return ContentDB.get_chapter(selected_chapter)

func mark_ftue_completed() -> void:
	if ftue_completed and ftue_version >= CURRENT_FTUE_VERSION:
		return
	ftue_completed = true
	ftue_version = CURRENT_FTUE_VERSION
	save_profile()
	ftue_state_changed.emit(true)

func mark_menu_tutorial_completed() -> void:
	if menu_tutorial_completed:
		return
	menu_tutorial_completed = true
	save_profile()
	menu_tutorial_state_changed.emit(true)

func reset_profile() -> void:
	load_profile()
	core_archetype_changed.emit(selected_core_archetype)
	chapter_changed.emit(selected_chapter)
	ftue_state_changed.emit(ftue_completed)
	menu_tutorial_state_changed.emit(menu_tutorial_completed)
