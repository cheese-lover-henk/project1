extends CenterContainer

@onready var stuffContainer = $VBoxContainer/VBoxContainer

@export var shouldReturn : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func show_stuff():
	for c in stuffContainer.get_children():
		c.queue_free()
	
	var data = Globals.get_leaderboard_data()
	if data.keys().size() == 0:
		var temp = Label.new()
		temp.text = "No Leaderboard data yet"
		stuffContainer.add_child(temp)
		return
	var dataKeys = data.keys()
	dataKeys.sort_custom(func(a, b): return data[a] < data[b])
	#dataKeys = dataKeys.to_set().to_array()
	
	var i = 1
	for name in dataKeys:
		if data[name] == 0:
			continue
		var temp = Label.new()
		temp.text = str(i) + ". " + name + " - " + Globals.msToTimeFormat(data[name])
		stuffContainer.add_child(temp)
		
		i += 1


func _on_return_button_pressed() -> void:
	shouldReturn = true
