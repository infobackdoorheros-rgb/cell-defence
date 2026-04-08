extends Node
class_name MutationManager

const MutationData = preload("res://scripts/data/mutation_data.gd")

signal choices_requested(options)
signal mutation_added(mutation)

var _rng := RandomNumberGenerator.new()
var _active_mutations: Array[MutationData] = []
var _offered_choices: Array[MutationData] = []

func _ready() -> void:
	_rng.randomize()

func reset_run() -> void:
	_active_mutations.clear()
	_offered_choices.clear()

func get_active_mutations() -> Array[MutationData]:
	return _active_mutations.duplicate()

func request_choice() -> bool:
	var pool: Array[MutationData] = _get_available_pool()
	if pool.is_empty():
		return false

	var local_pool: Array[MutationData] = pool.duplicate()
	var options: Array[MutationData] = []
	var desired: int = min(3, local_pool.size())

	while options.size() < desired and not local_pool.is_empty():
		var picked: MutationData = _roll_weighted(local_pool)
		if picked == null:
			break
		options.append(picked)
		local_pool.erase(picked)

	_offered_choices = options
	choices_requested.emit(options)
	return true

func choose_mutation(mutation_id: StringName) -> MutationData:
	for mutation in _offered_choices:
		if mutation.mutation_id == mutation_id:
			_active_mutations.append(mutation)
			_offered_choices.clear()
			mutation_added.emit(mutation)
			return mutation
	return null

func _get_available_pool() -> Array[MutationData]:
	var pool: Array[MutationData] = []
	for mutation in ContentDB.get_all_mutations():
		if not MetaProgression.is_mutation_unlocked(mutation.mutation_id):
			continue
		var already_owned: bool = false
		for active_mutation in _active_mutations:
			if active_mutation.mutation_id == mutation.mutation_id:
				already_owned = true
				break
		if already_owned:
			continue
		pool.append(mutation)
	return pool

func _roll_weighted(pool: Array[MutationData]) -> MutationData:
	var total_weight := 0.0
	for mutation in pool:
		total_weight += max(mutation.selection_weight, 0.01)

	if total_weight <= 0.0:
		return pool[0]

	var roll := _rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for mutation in pool:
		cursor += max(mutation.selection_weight, 0.01)
		if roll <= cursor:
			return mutation
	return pool[pool.size() - 1]
