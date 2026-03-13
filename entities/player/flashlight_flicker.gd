extends SpotLight3D

var turnon_time : int = 0
var amountOfFlickers : int = 0
var flickering : bool = false
var fullEnergy : float = 4.5
var energyCap : float = fullEnergy
var last_turnoff : int = 0

@onready var timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	resetVariables()
	last_turnoff = -10


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var justTurnedOn = false
	if Input.is_action_just_pressed("flashlight"):
		if visible:
			visible = false
			last_turnoff = Time.get_ticks_msec()
			resetVariables()
		else:
			visible = true
			turnon_time = Time.get_ticks_msec()
			rotation_degrees.z = randi_range(0, 360)
			justTurnedOn = true
	
	if !visible or flickering: return
	
	if float(turnon_time) / 1000.0 > 30 and randi_range(1, 10) == 1:
		energyCap -= 0.01
	
	# base percentage chance + 0.5 extra percent for every second its been on
	var timeSinceTurnoffMS = Time.get_ticks_msec() - last_turnoff
	if timeSinceTurnoffMS < 5: amountOfFlickers = abs(timeSinceTurnoffMS / 1000.0)
	elif justTurnedOn: amountOfFlickers = randi_range(5, 8)
	else: amountOfFlickers = randi_range(3, 7)
	flickering = true
	
	timer.wait_time = 0.1
	timer.start()


func _on_timer_timeout() -> void:
	timer.stop()
	while(amountOfFlickers > 0):
		light_energy = randf_range(0.5, fullEnergy)
		rotation_degrees.z += randi_range(-5, 5)
		if randi_range(1, 2) == 1: break
		light_energy = fullEnergy - randf_range(0.5, 1.5)
		amountOfFlickers -= 1
		if randi_range(1, 3) < 3: break

	if amountOfFlickers <= 0:
		light_energy = energyCap
		await get_tree().create_timer(randi_range(1, 15)).timeout
		flickering = false
		return
	
	timer.wait_time = randf_range(0.01, 0.1)
	timer.start()

func resetVariables():
	timer.stop()
	amountOfFlickers = 0
	flickering = false
	energyCap = fullEnergy
	light_energy = fullEnergy
	turnon_time = 0
