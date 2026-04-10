extends Node

signal shop_changed

const REWARDED_LIMIT_PER_DAY := 3
const REWARDED_DNA_REWARD := 18

const _DNA_PACKS := [
	{
		"id": "starter_bundle",
		"dna": 60,
		"bonus": 10,
		"price_label": "EUR 1.99"
	},
	{
		"id": "gene_cache",
		"dna": 140,
		"bonus": 30,
		"price_label": "EUR 4.99"
	},
	{
		"id": "genome_vault",
		"dna": 320,
		"bonus": 80,
		"price_label": "EUR 9.99"
	}
]

var _shop_state: Dictionary = {}

func _ready() -> void:
	load_state()
	if not OfferManager.offers_changed.is_connected(_on_offers_changed):
		OfferManager.offers_changed.connect(_on_offers_changed)

func load_state() -> void:
	_shop_state = (SaveManager.get_save().get("shop_state", {}) as Dictionary).duplicate(true)
	_sync_rewarded_day()
	shop_changed.emit()

func save_state() -> void:
	SaveManager.write_save({
		"shop_state": _shop_state
	})

func get_dna_packs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var claims := (_shop_state.get("iap_test_claims", {}) as Dictionary)
	for pack in _DNA_PACKS:
		var pack_copy := (pack as Dictionary).duplicate(true)
		var pack_id := String(pack_copy.get("id", ""))
		pack_copy["claim_count"] = int(claims.get(pack_id, 0))
		pack_copy["total_dna"] = int(pack_copy.get("dna", 0)) + int(pack_copy.get("bonus", 0))
		result.append(pack_copy)
	return result

func purchase_dna_pack(pack_id: StringName) -> bool:
	for pack in _DNA_PACKS:
		if StringName(pack.get("id", "")) != pack_id:
			continue
		var total_dna := int(pack.get("dna", 0)) + int(pack.get("bonus", 0))
		if total_dna <= 0:
			return false

		var claims := (_shop_state.get("iap_test_claims", {}) as Dictionary).duplicate(true)
		var key := String(pack_id)
		claims[key] = int(claims.get(key, 0)) + 1
		_shop_state["iap_test_claims"] = claims
		MetaProgression.add_dna(total_dna)
		AnalyticsManager.track_event(&"shop_pack_purchased", {
			"pack_id": key,
			"dna_awarded": total_dna,
			"claim_count": int(claims[key])
		})
		save_state()
		shop_changed.emit()
		return true
	return false

func get_rewarded_video_overview() -> Dictionary:
	_sync_rewarded_day()
	var claims_today: int = int(_shop_state.get("rewarded_claims_today", 0))
	var remaining: int = max(REWARDED_LIMIT_PER_DAY - claims_today, 0)
	return {
		"claims_today": claims_today,
		"remaining": remaining,
		"limit": REWARDED_LIMIT_PER_DAY,
		"reward_amount": REWARDED_DNA_REWARD,
		"available": remaining > 0
	}

func claim_rewarded_video() -> bool:
	_sync_rewarded_day()
	var claims_today: int = int(_shop_state.get("rewarded_claims_today", 0))
	if claims_today >= REWARDED_LIMIT_PER_DAY:
		return false

	claims_today += 1
	_shop_state["rewarded_claims_today"] = claims_today
	MetaProgression.add_dna(REWARDED_DNA_REWARD)
	AnalyticsManager.track_event(&"shop_rewarded_claimed", {
		"dna_awarded": REWARDED_DNA_REWARD,
		"claims_today": claims_today
	})
	save_state()
	shop_changed.emit()
	return true

func get_flash_offers() -> Array[Dictionary]:
	return OfferManager.get_offers()

func get_available_flash_offer_count() -> int:
	return OfferManager.get_available_offer_count()

func claim_flash_offer(offer_id: StringName) -> bool:
	var claimed := OfferManager.claim_offer(offer_id)
	if claimed:
		shop_changed.emit()
	return claimed

func get_shop_summary() -> Dictionary:
	var rewarded := get_rewarded_video_overview()
	return {
		"free_dna_remaining": int(rewarded.get("remaining", 0)),
		"free_dna_limit": int(rewarded.get("limit", REWARDED_LIMIT_PER_DAY)),
		"offers_available": get_available_flash_offer_count()
	}

func _sync_rewarded_day() -> void:
	var today_key := _get_today_key()
	if String(_shop_state.get("rewarded_day", "")) == today_key:
		return
	_shop_state["rewarded_day"] = today_key
	_shop_state["rewarded_claims_today"] = 0
	save_state()

func _get_today_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]

func _on_offers_changed() -> void:
	shop_changed.emit()
