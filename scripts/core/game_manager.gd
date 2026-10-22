extends Node
## Autoload: session-wide state that must survive scene changes.
## (Scene flow, debug flag, the data database and ghost rotation.)

const MAIN_MENU_SCENE := "res://scenes/main/main_menu.tscn"
const INVESTIGATION_SCENE := "res://scenes/main/investigation.tscn"
const DATABASE_PATH := "res://resources/game_database.tres"

## Enables the debug overlay and debug hotkeys inside an investigation.
var debug_enabled: bool = false
## When set, the next investigation uses this ghost type (debug / tests).
var forced_ghost_id: StringName = &""
var last_ghost_id: StringName = &""
var investigations_started: int = 0
## True while the guided "Learn to Play" investigation is running.
var tutorial_mode: bool = false
var database: GameDatabase
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	if ResourceLoader.exists(DATABASE_PATH):
		database = load(DATABASE_PATH) as GameDatabase
	if database == null:
		push_error("Game database missing at %s (run tools/build_resources.gd)" % DATABASE_PATH)
	var args := OS.get_cmdline_user_args()
	if args.has("--debug-mode"):
		debug_enabled = true
	for arg in args:
		if arg.begins_with("--ghost="):
			forced_ghost_id = StringName(arg.trim_prefix("--ghost="))


func _exit_tree() -> void:
	# Release static caches so the engine exits without leak warnings.
	UiTheme.clear_cache()
	Flashlight.clear_cache()


## Picks the ghost for a new investigation. A repeat of the previous type is
## re-rolled once, so consecutive runs usually (75%) meet a different ghost.
func pick_ghost_definition() -> GhostDefinition:
	if forced_ghost_id != &"":
		var forced := database.get_ghost(forced_ghost_id)
		if forced:
			return forced
	var ghosts := database.ghosts
	var pick: GhostDefinition = ghosts[rng.randi() % ghosts.size()]
	if pick.id == last_ghost_id and ghosts.size() > 1:
		pick = ghosts[rng.randi() % ghosts.size()]
	return pick


func register_investigation(ghost: GhostDefinition) -> void:
	last_ghost_id = ghost.id
	investigations_started += 1


func start_investigation() -> void:
	tutorial_mode = false
	_load_investigation()


## Starts the guided tutorial: a normal-behaving ghost that cannot kill.
func start_tutorial() -> void:
	tutorial_mode = true
	_load_investigation()


## Restarts in the current mode (tutorial stays tutorial).
func restart_current() -> void:
	_load_investigation()


func _load_investigation() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(INVESTIGATION_SCENE)


func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func quit_game() -> void:
	get_tree().quit()
