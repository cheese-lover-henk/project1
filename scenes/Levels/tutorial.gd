extends Node3D

@export var spawnPoints : Dictionary[Area3D, Marker3D]

@onready var initialSpawnpoint : Marker3D = $respawnpoints/initialSpawn
@onready var levelBoundingBox : Area3D = $levelbounds

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
	print("respawned!")


func _on_levelbounds_body_exited(body: Node3D) -> void:
	if body == Globals.get_player():
		respawn()
