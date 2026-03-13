extends Node3D

@export var enabled : bool = true

@export var active_material : Material
@export var inactive_material : Material

@onready var parentRaycast : RayCast3D
@onready var visual_indicator : MeshInstance3D = $MeshInstance3D

var using_a := true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var parent = get_parent()
	if parent is RayCast3D:
		parentRaycast = parent
	else:
		queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var ray_origin = parentRaycast.global_position
	var ray_end: Vector3
	
	if parentRaycast.is_colliding():
		visual_indicator.material_override = active_material
		ray_end = parentRaycast.get_collision_point()
	else:
		visual_indicator.material_override = inactive_material
		ray_end = parentRaycast.to_global(parentRaycast.target_position)

	var length = ray_origin.distance_to(ray_end)
	visual_indicator.mesh = visual_indicator.mesh.duplicate()
	var cylinder := visual_indicator.mesh as CylinderMesh
	cylinder.height = length
	visual_indicator.global_position = ray_origin
	if not visual_indicator.global_position.is_equal_approx(parentRaycast.to_global(ray_end)): visual_indicator.look_at(ray_end, Vector3.UP)
	visual_indicator.translate_object_local(Vector3(0, 0, -length / 2.0))
	visual_indicator.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
		
