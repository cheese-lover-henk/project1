extends Control

@onready var labelContainer = $MarginContainer/HBoxContainer/VBoxContainer

@onready var Labels : Dictionary[String, Label] = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func createLabel(key: String) -> void:
	if Labels.has(key):
		print("failed creating debuginfo label: ", key, " already exists")
		return
	
	var newLabel = Label.new()
	labelContainer.add_child(newLabel)
	Labels[key] = newLabel

func updateLabel(key: String, content: String) -> void:
	if not Labels.has(key):
		print("failed to update label with key: ", key, " because it doesnt exist")
		return
	
	Labels[key].text = content
