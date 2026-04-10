extends Node2D
class_name RunScene

const CellCore = preload("res://scripts/entities/cell_core.gd")
const ResourceManager = preload("res://scripts/managers/resource_manager.gd")
const UpgradeManager = preload("res://scripts/managers/upgrade_manager.gd")
const MutationManager = preload("res://scripts/managers/mutation_manager.gd")
const WaveManager = preload("res://scripts/managers/wave_manager.gd")
const HUD = preload("res://scripts/ui/hud.gd")
const MutationChoicePanel = preload("res://scripts/ui/mutation_choice_panel.gd")
const GameOverPanel = preload("res://scripts/ui/game_over_panel.gd")
const FTUEOverlay = preload("res://scripts/ui/ftue_overlay.gd")
const PauseMenuPanel = preload("res://scripts/ui/pause_menu_panel.gd")
const RunStats = preload("res://scripts/core/run_stats.gd")
const MutationData = preload("res://scripts/data/mutation_data.gd")
const ArenaBackdrop = preload("res://scripts/run/arena_backdrop.gd")

const DNA_PICKUP_INTERVAL_MIN := 9.0
const DNA_PICKUP_INTERVAL_MAX := 15.0
const MAX_ACTIVE_DNA_PICKUPS := 3
const RUN_MUSIC_PATH := "res://music.mp3"

@onready var arena_backdrop: ArenaBackdrop = $ArenaBackdrop
@onready var enemy_container: Node2D = $EnemyContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var pickup_container: Node2D = $PickupContainer
@onready var core: CellCore = $CellCore
@onready var resource_manager: ResourceManager = $ResourceManager
@onready var upgrade_manager: UpgradeManager = $UpgradeManager
@onready var mutation_manager: MutationManager = $MutationManager
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: HUD = $UI/HUD
@onready var mutation_panel: MutationChoicePanel = $UI/MutationChoicePanel
@onready var game_over_panel: GameOverPanel = $UI/GameOverPanel
@onready var ftue_overlay: FTUEOverlay = $UI/FTUEOverlay
@onready var pause_menu_panel: PauseMenuPanel = $UI/PauseMenuPanel

var arena_center: Vector2 = Vector2.ZERO
var arena_radius: float = 260.0
var gameplay_paused: bool = false
var run_finished: bool = false
var _committed_rewards: bool = false
var _active_enemy_count: int = 0
var _dna_pickup_scene: PackedScene = preload("res://scenes/entities/dna_pickup.tscn")
var _dna_spawn_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _game_over_summary: Dictionary = {}
var _game_over_reward_multiplier: float = 1.0
var _run_music_player: AudioStreamPlayer

func _ready() -> void:
	_rng.randomize()
	get_viewport().size_changed.connect(_update_arena_layout)
	_update_arena_layout()
	_wire_scene()
	_setup_run_music()
	var resumed := false
	if SaveManager.consume_resume_saved_run_request():
		resumed = _try_resume_saved_run()
	if not resumed:
		_start_new_run()

func _process(delta: float) -> void:
	upgrade_manager.update_runtime_systems(delta, is_gameplay_paused())
	if is_gameplay_paused():
		return

	_dna_spawn_timer -= delta
	if _dna_spawn_timer <= 0.0:
		_try_spawn_dna_pickup()
		_schedule_next_dna_pickup()

func _wire_scene() -> void:
	core.setup(self, wave_manager, projectile_container)
	wave_manager.setup(core, self, enemy_container, pickup_container, resource_manager, upgrade_manager)
	upgrade_manager.setup(resource_manager, mutation_manager)

	upgrade_manager.stats_updated.connect(_on_stats_updated)
	upgrade_manager.upgrades_changed.connect(_refresh_shop)
	resource_manager.atp_changed.connect(_on_runtime_values_changed)
	resource_manager.dna_projection_changed.connect(_on_runtime_values_changed)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_cleared.connect(_on_wave_cleared)
	wave_manager.enemy_counts_changed.connect(_on_enemy_counts_changed)
	wave_manager.mutation_milestone_reached.connect(_on_mutation_milestone_reached)
	mutation_manager.choices_requested.connect(_on_mutation_choices_requested)
	core.health_changed.connect(_on_core_health_changed)
	core.shield_changed.connect(_on_core_shield_changed)
	core.core_destroyed.connect(_on_core_destroyed)
	core.active_skill_state_changed.connect(_on_active_skill_state_changed)
	upgrade_manager.free_upgrade_granted.connect(_on_free_upgrade_granted)
	DailyMissionManager.mission_completed.connect(_on_daily_mission_completed)
	SeasonEventManager.milestone_reached.connect(_on_event_milestone_reached)
	BattlePassManager.tier_completed.connect(_on_battle_pass_tier_completed)
	OfferManager.offer_claimed.connect(_on_offer_claimed)

	hud.upgrade_requested.connect(_on_upgrade_requested)
	hud.active_skill_requested.connect(_on_active_skill_requested)
	hud.menu_requested.connect(_on_menu_button_requested)
	mutation_panel.mutation_selected.connect(_on_mutation_selected)
	game_over_panel.restart_requested.connect(_on_restart_requested)
	game_over_panel.meta_requested.connect(_on_meta_requested)
	game_over_panel.menu_requested.connect(_on_menu_requested)
	game_over_panel.revive_requested.connect(_on_revive_requested)
	game_over_panel.dna_boost_requested.connect(_on_dna_boost_requested)
	ftue_overlay.dismissed.connect(_on_ftue_dismissed)
	pause_menu_panel.continue_requested.connect(_on_pause_continue_requested)
	pause_menu_panel.save_requested.connect(_on_pause_save_requested)
	pause_menu_panel.exit_requested.connect(_on_pause_exit_requested)
	SettingsManager.audio_changed.connect(_on_audio_changed)
	SettingsManager.graphics_mode_changed.connect(_on_graphics_mode_changed)

func _start_new_run() -> void:
	SaveManager.clear_run_snapshot()
	_begin_run_state(true)

func _begin_run_state(show_ftue: bool) -> void:
	gameplay_paused = false
	run_finished = false
	_committed_rewards = false
	_active_enemy_count = 0
	_game_over_summary.clear()
	_game_over_reward_multiplier = 1.0
	RewardFlowManager.reset_run()
	game_over_panel.hide_panel()
	mutation_panel.hide_panel()
	ftue_overlay.hide_overlay()
	pause_menu_panel.hide_panel()
	resource_manager.reset_run()
	mutation_manager.reset_run()
	upgrade_manager.reset_run()
	_schedule_next_dna_pickup()
	core.global_position = arena_center
	core.reset_run()
	wave_manager.reset_run()
	_apply_selected_loadout()
	core.apply_stats(upgrade_manager.get_current_stats())
	resource_manager.set_dna_gain_multiplier(upgrade_manager.get_current_stats().dna_gain_multiplier)
	arena_backdrop.set_combat_state(1, 0)
	AnalyticsManager.start_run(RunConfigManager.selected_core_archetype, RunConfigManager.selected_chapter)
	_refresh_hud()
	_refresh_shop()
	if show_ftue:
		_show_ftue_if_needed()

func _restart_run() -> void:
	for projectile in projectile_container.get_children():
		projectile.queue_free()
	for pickup in pickup_container.get_children():
		pickup.queue_free()
	_start_new_run()

func _setup_run_music() -> void:
	_run_music_player = AudioStreamPlayer.new()
	_run_music_player.bus = "Master"
	_run_music_player.volume_db = -8.0
	_run_music_player.stream = _load_run_music_stream()
	add_child(_run_music_player)
	if _run_music_player.stream != null and SettingsManager.audio_enabled:
		_run_music_player.play()

func _load_run_music_stream() -> AudioStream:
	if not FileAccess.file_exists(RUN_MUSIC_PATH):
		push_warning("Run music not found at %s" % RUN_MUSIC_PATH)
		return null

	var bytes := FileAccess.get_file_as_bytes(RUN_MUSIC_PATH)
	if bytes.is_empty():
		push_warning("Run music file is empty at %s" % RUN_MUSIC_PATH)
		return null

	var mp3_stream := AudioStreamMP3.new()
	mp3_stream.data = bytes
	mp3_stream.loop = true
	return mp3_stream

func _update_arena_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var playfield := Rect2(
		Vector2(viewport_size.x * 0.07, viewport_size.y * 0.18),
		Vector2(viewport_size.x * 0.86, viewport_size.y * 0.56)
	)
	if is_instance_valid(hud):
		playfield = hud.get_playfield_rect(viewport_size)

	arena_center = playfield.position + (playfield.size * 0.5)
	arena_radius = min(playfield.size.x * 0.44, playfield.size.y * 0.48)
	if is_instance_valid(arena_backdrop):
		arena_backdrop.set_arena_layout(arena_center, arena_radius)
	if is_instance_valid(core):
		core.global_position = arena_center
	queue_redraw()

func get_random_spawn_position() -> Vector2:
	var angle := _rng.randf() * TAU
	var spawn_radius := arena_radius + _rng.randf_range(24.0, 52.0)
	return arena_center + Vector2.RIGHT.rotated(angle) * spawn_radius

func get_random_collectible_position() -> Vector2:
	var angle := _rng.randf() * TAU
	var distance_ratio := _rng.randf_range(0.18, 0.82)
	return arena_center + Vector2.RIGHT.rotated(angle) * (arena_radius * distance_ratio)

func is_gameplay_paused() -> bool:
	return gameplay_paused or run_finished

func _on_upgrade_requested(upgrade_id: StringName) -> void:
	if run_finished:
		return
	if upgrade_manager.purchase_upgrade(upgrade_id):
		_refresh_hud()
		_refresh_shop()

func _on_stats_updated(stats: RunStats) -> void:
	core.apply_stats(stats)
	resource_manager.set_dna_gain_multiplier(stats.dna_gain_multiplier)
	hud.set_active_mutations(upgrade_manager.get_active_mutations())
	_refresh_hud()
	_refresh_shop()

func _on_runtime_values_changed(_value = null) -> void:
	_refresh_hud()
	_refresh_shop()

func _on_wave_started(_wave: int) -> void:
	AnalyticsManager.note_wave_reached(_wave)
	arena_backdrop.set_combat_state(max(1, wave_manager.current_wave), _active_enemy_count)
	_refresh_hud()

func _on_enemy_counts_changed(active_count: int, _pending_count: int) -> void:
	_active_enemy_count = active_count
	arena_backdrop.set_combat_state(max(1, wave_manager.current_wave), _active_enemy_count)
	_refresh_hud()

func _on_wave_cleared(wave: int, rewards: Dictionary) -> void:
	var event_parts: Array[String] = ["Wave %d stabilizzata" % wave]
	var total_atp: int = int(rewards.get("total_atp_bonus", 0))
	var dna_wave_bonus: int = int(rewards.get("dna_wave_bonus", 0))
	if total_atp > 0:
		event_parts.append("+%d ATP" % total_atp)
	if dna_wave_bonus > 0:
		event_parts.append("+%d DNA" % dna_wave_bonus)
	if event_parts.size() > 1:
		hud.show_runtime_event("   ".join(event_parts))
	_refresh_hud()

func _on_core_health_changed(_current_hp: float, _max_hp: float) -> void:
	_refresh_hud()

func _on_core_shield_changed(_current_shield: float, _max_shield: float) -> void:
	_refresh_hud()

func _on_mutation_milestone_reached(_wave: int) -> void:
	if not mutation_manager.request_choice():
		wave_manager.resume_after_mutation_choice()
		return
	gameplay_paused = true

func _on_mutation_choices_requested(options: Array[MutationData]) -> void:
	mutation_panel.show_choices(options)

func _on_mutation_selected(mutation_id: StringName) -> void:
	mutation_manager.choose_mutation(mutation_id)
	DailyMissionManager.register_mutation_selected()
	BattlePassManager.register_mutation_selected()
	AnalyticsManager.track_event(&"mutation_selected", {"mutation_id": String(mutation_id)})
	mutation_panel.hide_panel()
	gameplay_paused = false
	wave_manager.resume_after_mutation_choice()
	hud.set_active_mutations(upgrade_manager.get_active_mutations())
	_refresh_hud()
	_refresh_shop()

func _on_core_destroyed() -> void:
	if run_finished:
		return
	run_finished = true
	gameplay_paused = true
	_game_over_summary = resource_manager.build_run_summary()
	_game_over_summary["best_wave"] = max(MetaProgression.best_wave, int(_game_over_summary.get("wave_reached", 1)))
	_refresh_game_over_panel()

func _on_free_upgrade_granted(category: StringName, upgrade_name: String) -> void:
	var prefix := "Evoluzione Attacco"
	if category == &"defense":
		prefix = "Evoluzione Difesa"
	elif category == &"utility":
		prefix = "Evoluzione Utility"
	hud.show_runtime_event("%s: %s" % [prefix, upgrade_name])
	_refresh_hud()
	_refresh_shop()

func _on_active_skill_requested() -> void:
	if run_finished or gameplay_paused:
		return
	if core.activate_active_skill():
		hud.show_runtime_event("%s attivata" % core.get_active_skill_name())
		_refresh_hud()

func _on_active_skill_state_changed(cooldown_remaining: float, cooldown_total: float) -> void:
	hud.update_active_skill(cooldown_remaining, cooldown_total)

func _on_audio_changed(enabled: bool) -> void:
	if _run_music_player == null or _run_music_player.stream == null:
		return
	if enabled:
		if not _run_music_player.playing:
			_run_music_player.play()
	else:
		_run_music_player.stop()

func _on_menu_button_requested() -> void:
	if run_finished or mutation_panel.visible or ftue_overlay.visible:
		return
	if pause_menu_panel.visible:
		_on_pause_continue_requested()
		return
	gameplay_paused = true
	pause_menu_panel.show_panel()

func _on_restart_requested() -> void:
	_finalize_run_rewards()
	SaveManager.clear_run_snapshot()
	_restart_run()

func _on_meta_requested() -> void:
	_finalize_run_rewards()
	SaveManager.clear_run_snapshot()
	get_tree().change_scene_to_file("res://scenes/laboratory_scene.tscn")

func _on_menu_requested() -> void:
	_finalize_run_rewards()
	SaveManager.clear_run_snapshot()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_revive_requested() -> void:
	if not run_finished or not RewardFlowManager.consume_revive():
		return
	AnalyticsManager.track_event(&"reward_revive_used")
	run_finished = false
	gameplay_paused = false
	_game_over_reward_multiplier = 1.0
	_game_over_summary.clear()
	game_over_panel.hide_panel()
	core.revive()
	wave_manager.apply_area_damage(core.global_position, 165.0, core.get_current_stats().damage * 6.0, core.get_current_stats())
	hud.show_runtime_event("Stimolo di emergenza attivato")
	_refresh_hud()

func _on_dna_boost_requested() -> void:
	if not run_finished or not RewardFlowManager.consume_dna_boost():
		return
	AnalyticsManager.track_event(&"reward_dna_boost_used")
	_game_over_reward_multiplier = RewardFlowManager.get_dna_boost_multiplier()
	_refresh_game_over_panel()

func _on_ftue_dismissed() -> void:
	RunConfigManager.mark_ftue_completed()
	gameplay_paused = false
	hud.show_runtime_event("Protocollo iniziale completato")

func _on_daily_mission_completed(_mission_id: StringName) -> void:
	if is_inside_tree():
		hud.show_runtime_event("Missione giornaliera completata")

func _on_event_milestone_reached(index: int, _target: int) -> void:
	if is_inside_tree():
		hud.show_runtime_event("Traguardo evento %d disponibile" % (index + 1))

func _on_battle_pass_tier_completed(index: int, _target: int) -> void:
	if is_inside_tree():
		hud.show_runtime_event("Tier pass %d disponibile" % (index + 1))

func _on_offer_claimed(_offer_id: StringName, reward_type: StringName, reward_amount: int) -> void:
	if not is_inside_tree():
		return
	match reward_type:
		&"season_event_points":
			hud.show_runtime_event("+%d spore evento" % reward_amount)
		&"battle_pass_xp":
			hud.show_runtime_event("+%d pass XP" % reward_amount)
		_:
			hud.show_runtime_event("+%d DNA live ops" % reward_amount)

func _refresh_hud() -> void:
	hud.update_run_status(
		core.get_current_health(),
		core.get_current_stats().max_hp,
		core.get_current_shield(),
		core.get_current_stats().shield_max,
		resource_manager.atp,
		max(1, wave_manager.current_wave),
		resource_manager.get_projected_dna(),
		_active_enemy_count
	)
	hud.update_active_skill(core.get_active_skill_cooldown_remaining(), core.get_active_skill_cooldown_total())

func _refresh_shop() -> void:
	hud.refresh_shop(upgrade_manager)
	hud.set_active_mutations(upgrade_manager.get_active_mutations())

func _draw() -> void:
	var threat_level: float = clamp((float(_active_enemy_count) / 18.0) + (float(max(1, wave_manager.current_wave)) * 0.012), 0.0, 1.0)
	draw_arc(arena_center, arena_radius * 0.22, 0.0, TAU, 48, Color(0.32, 0.84, 1.0, 0.28), 2.0)
	draw_arc(arena_center, arena_radius * 0.54, 0.0, TAU, 72, Color(0.18, 0.42, 0.58, 0.18), 2.0)
	draw_arc(arena_center, arena_radius * 0.9, 0.0, TAU, 96, Color(0.3 + (0.06 * threat_level), 0.72, 0.98 - (0.08 * threat_level), 0.2), 2.0)
	if SettingsManager.use_mobile_safe_visuals():
		return

	var hex_points := PackedVector2Array()
	for point_index in range(6):
		var angle: float = TAU * float(point_index) / 6.0 + 0.52
		hex_points.append(arena_center + Vector2.RIGHT.rotated(angle) * (arena_radius * 0.08))
	hex_points.append(hex_points[0])
	draw_polyline(hex_points, Color(0.56, 0.88, 1.0, 0.46), 2.0)

	for segment_index in range(8):
		var angle: float = TAU * float(segment_index) / 8.0
		var inner: Vector2 = arena_center + Vector2.RIGHT.rotated(angle) * (arena_radius * 0.93)
		var outer: Vector2 = arena_center + Vector2.RIGHT.rotated(angle) * (arena_radius + 12.0)
		draw_line(inner, outer, Color(0.46, 0.92, 0.87, 0.1), 2.0)

func _on_graphics_mode_changed(_mode: StringName) -> void:
	if is_instance_valid(arena_backdrop):
		arena_backdrop.queue_redraw()
	queue_redraw()

func _on_pause_continue_requested() -> void:
	pause_menu_panel.hide_panel()
	gameplay_paused = false

func _on_pause_save_requested() -> void:
	if run_finished:
		return
	_save_current_run_snapshot()
	pause_menu_panel.show_saved_feedback()

func _on_pause_exit_requested() -> void:
	if not run_finished:
		_save_current_run_snapshot()
	pause_menu_panel.hide_panel()
	gameplay_paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _schedule_next_dna_pickup() -> void:
	var spawn_bonus: float = upgrade_manager.get_current_stats().dna_crystal_spawn_bonus
	var min_interval: float = max(3.0, DNA_PICKUP_INTERVAL_MIN * (1.0 - spawn_bonus))
	var max_interval: float = max(min_interval + 0.5, DNA_PICKUP_INTERVAL_MAX * (1.0 - spawn_bonus))
	_dna_spawn_timer = _rng.randf_range(min_interval, max_interval)

func _try_spawn_dna_pickup() -> void:
	if run_finished or gameplay_paused:
		return
	if _count_active_dna_pickups() >= MAX_ACTIVE_DNA_PICKUPS:
		return

	var dna_pickup := _dna_pickup_scene.instantiate()
	pickup_container.add_child(dna_pickup)
	dna_pickup.global_position = get_random_collectible_position()
	var reward_amount: int = 1 + int(max(1, wave_manager.current_wave) / 10)
	dna_pickup.initialize(reward_amount, core, self)
	dna_pickup.collected.connect(resource_manager.add_runtime_dna)
	hud.show_runtime_event("Cristallo DNA rilevato")

func _count_active_dna_pickups() -> int:
	var count: int = 0
	for pickup in pickup_container.get_children():
		if pickup.is_in_group("dna_pickups"):
			count += 1
	return count

func _apply_selected_loadout() -> void:
	var archetype = RunConfigManager.get_selected_core_archetype()
	var chapter = RunConfigManager.get_selected_chapter()
	core.configure_archetype(archetype)
	hud.configure_active_skill(core.get_active_skill_name(), core.get_active_skill_description())
	if chapter != null:
		resource_manager.set_chapter_dna_multiplier(chapter.dna_multiplier)
		arena_backdrop.set_theme_palette(chapter.arena_primary, chapter.arena_secondary)
		var archetype_name: String = archetype.display_name if archetype != null else "Core"
		hud.show_runtime_event("%s  |  %s" % [archetype_name, chapter.display_name])

func _show_ftue_if_needed() -> void:
	if RunConfigManager.ftue_version >= RunConfigManager.CURRENT_FTUE_VERSION:
		return
	gameplay_paused = true
	var archetype = RunConfigManager.get_selected_core_archetype()
	var chapter = RunConfigManager.get_selected_chapter()
	var archetype_name: String = archetype.display_name if archetype != null else "Core"
	var chapter_name: String = chapter.display_name if chapter != null else "Sector"
	ftue_overlay.show_ftue(archetype_name, chapter_name, core.get_active_skill_name())

func _refresh_game_over_panel() -> void:
	var summary := _game_over_summary.duplicate(true)
	summary["dna_earned"] = max(1, int(round(float(summary.get("dna_earned", 1)) * _game_over_reward_multiplier)))
	game_over_panel.show_summary(summary)
	var can_revive := RewardFlowManager.can_use_revive() and _game_over_reward_multiplier <= 1.0
	game_over_panel.set_reward_states(can_revive, RewardFlowManager.can_use_dna_boost())

func _finalize_run_rewards() -> void:
	if _committed_rewards or _game_over_summary.is_empty():
		return
	var earned := resource_manager.commit_run_rewards(_game_over_reward_multiplier)
	_game_over_summary["dna_earned"] = earned
	_game_over_summary["best_wave"] = MetaProgression.best_wave
	AnalyticsManager.complete_run(_game_over_summary)
	_committed_rewards = true

func _save_current_run_snapshot() -> void:
	var snapshot := {
		"selected_core_archetype": String(RunConfigManager.selected_core_archetype),
		"selected_chapter": String(RunConfigManager.selected_chapter),
		"saved_wave": max(1, wave_manager.current_wave),
		"dna_spawn_timer": _dna_spawn_timer,
		"resource_manager": resource_manager.get_snapshot_state(),
		"mutation_manager": mutation_manager.get_snapshot_state(),
		"upgrade_manager": upgrade_manager.get_snapshot_state(),
		"wave_manager": wave_manager.get_snapshot_state(),
		"core": core.get_snapshot_state(),
		"reward_flow": RewardFlowManager.get_snapshot_state()
	}
	SaveManager.save_run_snapshot(snapshot)
	hud.show_runtime_event(SettingsManager.t("pause.save_done"))

func _try_resume_saved_run() -> bool:
	var snapshot := SaveManager.get_run_snapshot()
	if snapshot.is_empty():
		return false

	var saved_core := StringName(snapshot.get("selected_core_archetype", String(RunConfigManager.DEFAULT_CORE_ARCHETYPE)))
	var saved_chapter := StringName(snapshot.get("selected_chapter", String(RunConfigManager.DEFAULT_CHAPTER)))
	if ContentDB.get_core_archetype(saved_core) != null:
		RunConfigManager.set_selected_core_archetype(saved_core)
	if ContentDB.get_chapter(saved_chapter) != null:
		RunConfigManager.set_selected_chapter(saved_chapter)

	_begin_run_state(false)
	mutation_manager.restore_snapshot_state(snapshot.get("mutation_manager", {}) as Dictionary)
	upgrade_manager.restore_snapshot_state(snapshot.get("upgrade_manager", {}) as Dictionary)
	core.apply_stats(upgrade_manager.get_current_stats())
	resource_manager.restore_snapshot_state(snapshot.get("resource_manager", {}) as Dictionary)
	core.restore_snapshot_state(snapshot.get("core", {}) as Dictionary)
	wave_manager.restore_snapshot_state(snapshot.get("wave_manager", {}) as Dictionary)
	RewardFlowManager.restore_snapshot_state(snapshot.get("reward_flow", {}) as Dictionary)
	_dna_spawn_timer = max(0.5, float(snapshot.get("dna_spawn_timer", _dna_spawn_timer)))
	SaveManager.clear_run_snapshot()
	hud.show_runtime_event(SettingsManager.t("pause.resume_loaded"))
	_refresh_hud()
	_refresh_shop()
	return true
