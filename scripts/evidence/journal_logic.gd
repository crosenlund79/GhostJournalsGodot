class_name JournalLogic
extends RefCounted
## Pure evidence-filtering rules used by the journal (unit tested).
##
## Each evidence has one of three marks. A ghost stays possible when it has
## every CONFIRMED evidence and none of the RULED_OUT evidence. UNKNOWN marks
## never exclude anything, so filtering can never contradict itself.

enum Mark { UNKNOWN, CONFIRMED, RULED_OUT }


static func is_ghost_possible(ghost: GhostDefinition, marks: Dictionary) -> bool:
	for evidence_id in marks.keys():
		var mark: int = marks[evidence_id]
		if mark == Mark.CONFIRMED and not ghost.has_evidence(evidence_id):
			return false
		if mark == Mark.RULED_OUT and ghost.has_evidence(evidence_id):
			return false
	return true


static func filter(ghosts: Array[GhostDefinition], marks: Dictionary) -> Array[GhostDefinition]:
	var out: Array[GhostDefinition] = []
	for g in ghosts:
		if is_ghost_possible(g, marks):
			out.append(g)
	return out


static func next_mark(mark: int) -> int:
	return (mark + 1) % 3
