class_name InvestigationManager
extends Node
## Owns the state of one investigation: the true ghost, what the player's
## equipment has observed, the journal marks, the final conclusion and the
## outcome. UI reads from here; gameplay systems report into it.

signal evidence_observed(evidence: EvidenceDefinition, note: String)
signal journal_changed
signal notification(text: String, tone: StringName)
signal investigation_finished(results: Dictionary)

var database: GameDatabase
var ghost_definition: GhostDefinition
var elapsed: float = 0.0
## evidence id -> first field note.
var observed: Dictionary = {}
var field_notes: Array[String] = []
## evidence id -> JournalLogic.Mark
var marks: Dictionary = {}
var selected_ghost_id: StringName = &""
## &"not_attempted", &"success" or &"failed".
var exorcism_result: StringName = &"not_attempted"
var player_died: bool = false
var finished: bool = false
var results: Dictionary = {}


func setup(db: GameDatabase, ghost: GhostDefinition) -> void:
	database = db
	ghost_definition = ghost
	for e in database.evidence:
		marks[e.id] = JournalLogic.Mark.UNKNOWN


func _process(delta: float) -> void:
	if not finished:
		elapsed += delta


func time_string(seconds: float = -1.0) -> String:
	var t := elapsed if seconds < 0.0 else seconds
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


## Reports that the player's equipment genuinely detected an evidence type.
func observe(evidence_id: StringName, room_name: String = "", detail: String = "") -> void:
	if finished:
		return
	var def := database.get_evidence(evidence_id)
	if def == null:
		push_warning("Unknown evidence %s" % evidence_id)
		return
	if observed.has(evidence_id):
		return
	var note := def.observation_note.format({"room": room_name if room_name != "" else "house", "detail": detail})
	note = "%s — %s" % [time_string(), note]
	observed[evidence_id] = note
	field_notes.append(note)
	AudioManager.play(&"evidence_cue", -8.0)
	notify("Something registered. (J — journal)", &"evidence")
	evidence_observed.emit(def, note)
	journal_changed.emit()


func add_field_note(text: String) -> void:
	field_notes.append("%s — %s" % [time_string(), text])
	journal_changed.emit()


func notify(text: String, tone: StringName = &"info") -> void:
	notification.emit(text, tone)


func get_mark(evidence_id: StringName) -> int:
	return marks.get(evidence_id, JournalLogic.Mark.UNKNOWN)


func set_mark(evidence_id: StringName, mark: int) -> void:
	marks[evidence_id] = mark
	# A conclusion that the notes now exclude is cleared to stay consistent.
	if selected_ghost_id != &"":
		var g := database.get_ghost(selected_ghost_id)
		if g and not JournalLogic.is_ghost_possible(g, marks):
			selected_ghost_id = &""
	journal_changed.emit()


func cycle_mark(evidence_id: StringName) -> void:
	set_mark(evidence_id, JournalLogic.next_mark(get_mark(evidence_id)))


func possible_ghosts() -> Array[GhostDefinition]:
	return JournalLogic.filter(database.ghosts, marks)


func select_ghost(ghost_id: StringName) -> void:
	selected_ghost_id = ghost_id if selected_ghost_id != ghost_id else &""
	journal_changed.emit()


func selected_ghost() -> GhostDefinition:
	return database.get_ghost(selected_ghost_id) if selected_ghost_id != &"" else null


func set_exorcism_result(result: StringName) -> void:
	exorcism_result = result


func finish(survived: bool) -> Dictionary:
	if finished:
		return results
	finished = true
	player_died = not survived
	var observed_names: Array[String] = []
	for e in database.evidence:
		if observed.has(e.id):
			observed_names.append(e.display_name)
	var confirmed_names: Array[String] = []
	var ruled_out_names: Array[String] = []
	for e in database.evidence:
		match get_mark(e.id):
			JournalLogic.Mark.CONFIRMED:
				confirmed_names.append(e.display_name)
			JournalLogic.Mark.RULED_OUT:
				ruled_out_names.append(e.display_name)
	var selected := selected_ghost()
	results = {
		"actual_ghost": ghost_definition.display_name,
		"actual_ghost_id": ghost_definition.id,
		"selected_ghost": selected.display_name if selected else "",
		"correct": selected != null and selected.id == ghost_definition.id,
		"observed_evidence": observed_names,
		"confirmed_evidence": confirmed_names,
		"ruled_out_evidence": ruled_out_names,
		"actual_evidence": ghost_definition.evidence.map(func(id: StringName) -> String: return database.get_evidence(id).display_name),
		"exorcism": exorcism_result,
		"survived": survived,
		"duration": time_string(),
	}
	investigation_finished.emit(results)
	return results
