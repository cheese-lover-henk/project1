extends Node

var player : CharacterBody3D
var leaderboard : Dictionary[String, int]

@export var sens_multiplier : float = 1.0

func get_player() -> CharacterBody3D:
	return player

func add_leaderboard_entry(name : String, timeMS : int):
	var i : int = leaderboard.keys().size()
	name = name + str(i)
	leaderboard[name] = timeMS

func get_leaderboard_data() -> Dictionary[String, int]:
	return leaderboard

func msToTimeFormat(timeMS : int) -> String:
	var ms := timeMS % 1000
	var total_seconds := timeMS / 1000
	
	var seconds := total_seconds % 60
	var total_minutes := total_seconds / 60
	
	var minutes := total_minutes % 60
	var hours := total_minutes / 60

	return "%02d:%02d:%02d,%03d" % [hours, minutes, seconds, ms]

func _ready() -> void:
	leaderboard["test2"] = 200000
	leaderboard["test"] = 100000


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player != null:
		player.sens_multiplier = sens_multiplier
