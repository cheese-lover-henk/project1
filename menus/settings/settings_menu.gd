extends CenterContainer

@export var should_leave_settings : bool = false

@onready var sensitivity_slider : HSlider = $VBoxContainer/HBoxContainer/HSlider
@onready var sensitivity_label : Label = $VBoxContainer/HBoxContainer/Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sensitivity_slider.value = int(Globals.sens_multiplier * 100)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	sensitivity_label.text = str(sensitivity_slider.value)


func _on_quit_to_main_menu_pressed() -> void:
	should_leave_settings = true


func _on_defaults_pressed() -> void:
	sensitivity_slider.value = 100
	save()

func save() -> void:
	Globals.sens_multiplier = (sensitivity_slider.value / 100)
	print("settings saved")

func _on_save_pressed() -> void:
	save()
