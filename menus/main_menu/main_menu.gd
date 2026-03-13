extends Control

@onready var mainMenu = $"MainMenu-CenterContainer"
@onready var SettingsMenu = $"SettingsMenu-CenterContainer"
@onready var leaderboard = $Leaderboard

var menus : Array[Control]

var sceneTree : SceneTree

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menus.push_back(mainMenu)
	menus.push_back(SettingsMenu)
	menus.push_back(leaderboard)
	sceneTree = get_tree()
	show_menu(mainMenu)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if SettingsMenu.should_leave_settings:
		show_menu(mainMenu)
		SettingsMenu.should_leave_settings = false
	if leaderboard.shouldReturn:
		show_menu(mainMenu)
		leaderboard.shouldReturn = false


func show_menu(menuToShow : Control):
	for m in menus:
		m.visible = false
		m.set_process_input(false)
	menuToShow.visible = true
	menuToShow.set_process_input(true)

func _on_button_tutorial_pressed() -> void:
	sceneTree.change_scene_to_file("res://scenes/Levels/tutorial.tscn")

func _on_button_lvl_1_pressed() -> void:
	sceneTree.change_scene_to_file("res://scenes/Levels/level_harder.tscn")

func _on_button_testmap_pressed() -> void:
	sceneTree.change_scene_to_file("res://scenes/testmap/test_map_with_player.tscn")

func _on_button_settings_pressed() -> void:
	SettingsMenu.should_leave_settings = false
	show_menu(SettingsMenu)


func _on_button_quit_pressed() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit(0)


func _on_button_leaderboard_pressed() -> void:
	leaderboard.shouldReturn = false
	show_menu(leaderboard)
	leaderboard.show_stuff()
