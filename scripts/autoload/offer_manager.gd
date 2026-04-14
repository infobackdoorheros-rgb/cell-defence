extends Node

signal offers_changed
signal offer_claimed(offer_id: StringName, reward_type: StringName, reward_amount: int)

var _offers: Array[Dictionary] = []
var _claim_state: Dictionary = {}

func _ready() -> void:
	if not RemoteConfigManager.config_reloaded.is_connected(_on_config_reloaded):
		RemoteConfigManager.config_reloaded.connect(_on_config_reloaded)
	_apply_config()
	load_state()

func load_state() -> void:
	var save_data := SaveManager.get_save()
	_claim_state = (save_data.get("offers", {}) as Dictionary).duplicate(true)
	offers_changed.emit()

func save_state() -> void:
	SaveManager.write_save({
		"offers": _claim_state
	})

func are_claims_enabled() -> bool:
	return RemoteConfigManager.get_bool("features.offer_claims_enabled", false)

func get_offers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var today_key := _get_today_key()
	var claims_enabled := are_claims_enabled()
	for offer in _offers:
		var offer_id := String(offer.get("id", ""))
		var refresh := String(offer.get("refresh", "once"))
		var state := (_claim_state.get(offer_id, {}) as Dictionary).duplicate(true)
		var available := claims_enabled
		var status := "beta_locked"

		if claims_enabled:
			status = "available"
			match refresh:
				"once":
					if bool(state.get("claimed_forever", false)):
						available = false
						status = "claimed"
				"daily":
					if String(state.get("last_claim_day", "")) == today_key:
						available = false
						status = "claimed_today"

		result.append({
			"id": offer_id,
			"display_name": SettingsManager.t("offer.%s.title" % offer_id),
			"description": SettingsManager.t("offer.%s.description" % offer_id),
			"reward_type": String(offer.get("reward_type", "")),
			"reward_amount": int(offer.get("reward_amount", 0)),
			"refresh": refresh,
			"available": available,
			"status": status
		})
	return result

func get_available_offer_count() -> int:
	if not are_claims_enabled():
		return 0
	var total := 0
	for offer in get_offers():
		if bool(offer.get("available", false)):
			total += 1
	return total

func claim_offer(offer_id: StringName) -> bool:
	if not are_claims_enabled():
		return false
	for offer in get_offers():
		if StringName(offer.get("id", "")) != offer_id:
			continue
		if not bool(offer.get("available", false)):
			return false
		var reward_type := StringName(offer.get("reward_type", ""))
		var reward_amount := int(offer.get("reward_amount", 0))
		_apply_reward(reward_type, reward_amount)
		_store_claim(offer)
		AnalyticsManager.track_event(&"offer_claimed", {
			"offer_id": String(offer_id),
			"reward_type": String(reward_type),
			"reward_amount": reward_amount
		})
		save_state()
		offers_changed.emit()
		offer_claimed.emit(offer_id, reward_type, reward_amount)
		return true
	return false

func _apply_reward(reward_type: StringName, reward_amount: int) -> void:
	match reward_type:
		&"season_event_points":
			SeasonEventManager.add_progress(reward_amount)
		&"battle_pass_xp":
			BattlePassManager.add_progress(reward_amount)
		_:
			MetaProgression.add_dna(reward_amount)

func _store_claim(offer: Dictionary) -> void:
	var offer_id := String(offer.get("id", ""))
	var refresh := String(offer.get("refresh", "once"))
	var state := (_claim_state.get(offer_id, {}) as Dictionary).duplicate(true)
	match refresh:
		"daily":
			state["last_claim_day"] = _get_today_key()
		_:
			state["claimed_forever"] = true
	_claim_state[offer_id] = state

func _apply_config() -> void:
	_offers.clear()
	for item in RemoteConfigManager.get_array("offers.cards"):
		if item is Dictionary:
			_offers.append((item as Dictionary).duplicate(true))

func _on_config_reloaded() -> void:
	_apply_config()
	offers_changed.emit()

func _get_today_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]
