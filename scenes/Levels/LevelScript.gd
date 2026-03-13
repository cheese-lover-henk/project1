extends Node3D

@export var spawnPoints : Dictionary[Area3D, Marker3D]

@onready var initialSpawnpoint : Marker3D = $respawnPoints/InitialSpawn
@onready var levelBoundingBox : Area3D = $LevelBounds

var currentSpawnpoint : Marker3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	currentSpawnpoint = initialSpawnpoint
	if Globals.get_player() != null:
		respawn()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Globals.get_player() == null: return
	
	if not Globals.get_player() in levelBoundingBox.get_overlapping_bodies():
		respawn()
		return
	
	
	for body in spawnPoints.keys():
		if Globals.get_player() in body.get_overlapping_bodies() and currentSpawnpoint != spawnPoints[body]:
			currentSpawnpoint = spawnPoints[body]
			print("spawnpoint changed!")

func respawn():
	Globals.get_player().velocity = Vector3.ZERO
	Globals.get_player().global_position = currentSpawnpoint.global_position
	Globals.get_player().global_rotation = currentSpawnpoint.global_rotation
	print("respawned!")

func _on_level_bounds_body_exited(body: Node3D) -> void:
	if body == Globals.get_player():
		respawn()

func _on_area_2_body_entered(body: Node3D) -> void:
	Globals.get_player().stop_timer()
	var timeMS = Globals.get_player().get_timer_time()
	Globals.add_leaderboard_entry("Player", timeMS)
	var data := Globals.get_leaderboard_data()
	var formatted_time := Globals.msToTimeFormat(timeMS)

	var entries: Array = []
	for name in data:
		entries.append([name, data[name]])

	# Sort by time (ascending)
	entries.sort_custom(func(a, b): return a[1] < b[1])
	
	print(entries)

	# Find placement
	var placement := 1
	for entry in entries:
		if entry[0] == "Player" and entry[1] == timeMS:
			break
		placement += 1

	print("Your time: %s | You placed %d on the leaderboard!" % [formatted_time, placement])
