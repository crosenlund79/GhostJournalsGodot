class_name GameDatabase
extends Resource
## Registry of all data definitions used by an investigation.

@export var evidence: Array[EvidenceDefinition] = []
@export var ghosts: Array[GhostDefinition] = []
@export var equipment: Array[EquipmentDefinition] = []
@export var balance: GameBalance


func get_evidence(evidence_id: StringName) -> EvidenceDefinition:
	for e in evidence:
		if e.id == evidence_id:
			return e
	return null


func get_ghost(ghost_id: StringName) -> GhostDefinition:
	for g in ghosts:
		if g.id == ghost_id:
			return g
	return null


func get_equipment(equipment_id: StringName) -> EquipmentDefinition:
	for e in equipment:
		if e.id == equipment_id:
			return e
	return null


func ghosts_with_evidence(evidence_id: StringName) -> Array[GhostDefinition]:
	var out: Array[GhostDefinition] = []
	for g in ghosts:
		if g.has_evidence(evidence_id):
			out.append(g)
	return out
