class_name EvidenceDefinition
extends Resource
## Data definition for one kind of paranormal evidence.
##
## Which ghosts can produce a piece of evidence is defined on the ghost side
## ([member GhostDefinition.evidence]); [method GameDatabase.ghosts_with_evidence]
## answers the reverse question so the data is never duplicated.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## Player-facing hint describing how the evidence is discovered.
@export_multiline var discovery_requirements: String = ""
## Equipment that is used to detect this evidence (empty for environmental evidence).
@export var equipment_id: StringName
## Short label used in the journal's field notes.
@export var short_name: String = ""
## Field-note text written when the evidence is first observed. {room} and
## {detail} are substituted.
@export var observation_note: String = "Something was observed in the {room}."
