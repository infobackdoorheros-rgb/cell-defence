extends Node

func _ready() -> void:
	var counts := {
		"cores": ContentDB.get_core_archetypes().size(),
		"chapters": ContentDB.get_chapters().size(),
		"enemies": ContentDB.get_all_enemies().size(),
		"runtime_upgrades": ContentDB.get_runtime_upgrades().size(),
		"mutations": ContentDB.get_all_mutations().size(),
		"has_wave_rules": ContentDB.get_wave_rules() != null,
	}
	print("CONTENT_COUNTS ", JSON.stringify(counts))

	RunConfigManager.selected_core_archetype = &"sentinel_core"
	RunConfigManager.selected_chapter = &"chapter_capillary"
	RunConfigManager.ftue_completed = true

	var run_scene := load("res://scenes/run_scene.tscn").instantiate()
	add_child(run_scene)

	await get_tree().create_timer(2.0).timeout

	var run_state := {
		"wave": run_scene.wave_manager.current_wave,
		"active_enemies": run_scene.wave_manager.get_active_enemy_count(),
		"queued_enemies": run_scene.wave_manager._spawn_queue.size(),
		"attack_upgrades": ContentDB.get_runtime_upgrades_by_category(&"attack").size(),
		"defense_upgrades": ContentDB.get_runtime_upgrades_by_category(&"defense").size(),
		"utility_upgrades": ContentDB.get_runtime_upgrades_by_category(&"utility").size(),
	}
	print("RUN_STATE ", JSON.stringify(run_state))
	get_tree().quit()
