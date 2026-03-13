extends Control

@export var should_unpause = false
@export var should_quit = false

@onready var settingsMenu = $"SettingsMenu-CenterContainer"
@onready var pauseMenu = $CenterContainer

var menus : Array[Control]

var sceneTree : SceneTree
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menus.push_back(pauseMenu)
	menus.push_back(settingsMenu)
	sceneTree = get_tree()
	show_menu(pauseMenu)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if settingsMenu.should_leave_settings:
		show_menu(pauseMenu)
		settingsMenu.should_leave_settings = false

func show_menu(menuToShow : Control):
	for m in menus:
		m.visible = false
		m.set_process_input(false)
	menuToShow.visible = true
	menuToShow.set_process_input(true)

func _on_quit_to_main_menu_pressed() -> void:
	should_quit = true


func _on_resume_pressed() -> void:
	should_unpause = true
	self.visible = false


func _on_settings_pressed() -> void:
	settingsMenu.should_leave_settings = false
	show_menu(settingsMenu)
