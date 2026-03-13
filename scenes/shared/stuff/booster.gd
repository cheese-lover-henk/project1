extends CSGCylinder3D

@onready var area = $Area3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	for b in area.get_overlapping_bodies():
		b.velocity.y += 150.0 * delta
