extends CharacterBody3D

@onready var HeadPivotPoint = $HeadPivotPoint
@onready var camera = $HeadPivotPoint/Camera3D

@onready var testHUD = $HeadPivotPoint/Camera3D/CanvasLayer/testHUD

class DetectedLedge:
	var point_a:Vector3
	var point_b:Vector3
	var normal:Vector3
	func _init(p_a:Vector3, p_b:Vector3, n:Vector3) -> void:
		point_a = p_a
		point_b = p_b
		normal = n

@onready var detected_ledges : Array[DetectedLedge] = []

var wall_angle_variation = 15.0
var max_wall_angle : float = 90 + wall_angle_variation
var min_wall_angle : float = 90 - wall_angle_variation

var max_top_surface_angle_degrees : float = 40.0

var amount_of_rays : int = 40
var scanning_area_height : float = 4.0
var scanning_area_bottom : float = 0.0 # relative to player.position
var rays_vertical_spacing : float = (scanning_area_height - scanning_area_bottom) / (amount_of_rays - 1)
var ray_scanning_distance : float = 4.0

var min_clearance_depth_hanging = 0.1
var min_clearance_height_hanging = 0.1

var min_clearance_depth_climbing = 0.7
var min_clearance_height_climbing = 1.1 # climb onto then crouch

const WALKSPEED = 4.0
const SPRINTSPEED = 8.0
const CROUCHSPEED = 2.5
const MAX_SLIDE_DURATION_SECONDS = 0.9
var slide_start_time = 0
var slide_direction := Vector3.ZERO
var slide_angle_degrees : float = 0.0
var sliding_camera_clamp_offset : float = 40.0
var max_fall_slide_time : float = 0.3

var max_coyotejump_time : float = 0.12
var just_jumped : bool = false

var start_falling_time : int = 0
var fall_duration : float = 0.0

var sensitivity = 0.003

var speed = WALKSPEED

var jump_height = 1.1
var jump_time_to_peak = 0.30
var jump_time_to_fall = 0.25

var max_step_height = 0.4
var max_step_distance = 0.15

@onready var jump_gravity := calculate_jump_gravity(jump_height, jump_time_to_peak)
@onready var fall_gravity := calculate_fall_gravity(jump_height, jump_time_to_fall)
@onready var jump_velocity := calculate_jump_velocity(jump_height, jump_time_to_peak)

var base_fov = 75.0
var fov_multiplier = 1.5

var paused : bool = false

enum states {
	IDLE,
	WALKING,
	SPRINTING,
	JUMPING,
	FALLING,
	CROUCHING,
	
	SLIDING,
	SLIDE_FALLING,
	LANDING,
	VAULTING,
	HANGING_ON_LEDGE,
	CLIMBING_ONTO_LEDGE,
	LEDGE_GRABBING,

	ZIPLINING,
	GRAPPLING_HOOK_FLYING,
	GRAPPLING_HOOK_THROWING,
	
	KICKING,
	ATTACKING_MELEE,
	AIMING_DOWN_SIGHTS,
	AIMING_WALKING
}

var max_small_height = 4.0
var max_medium_height = 8.0

var last_state:states = states.IDLE
var current_state:states = states.IDLE
var next_state:states = states.IDLE

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	create_debug_labels()

func _unhandled_input(event) -> void:
	if event is InputEventMouseMotion and not paused:
		self.rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90)) # straight up and down
		
	if paused:
		if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			paused = false
			print("resume")

func _physics_process(delta: float) -> void:
	
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := Vector3(HeadPivotPoint.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	next_state = determine_next_state(direction)
	if current_state != next_state:
		transition_into_state(direction, next_state)
	
	
	handle_movement_state(direction, delta)

	move_and_slide()

func _process(delta: float) -> void:
	update_fov(delta)
	update_debug_labels()
	
	if(Input.is_action_just_pressed("esc") and (not paused)):
		paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		print("pause")


func handle_movement_state(direction:Vector3, delta:float) -> void:
	if current_state == states.FALLING:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 4.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 4.0)
		
		if velocity.y >= 0.0:
			velocity.y += jump_gravity * delta
		else:
			velocity.y += fall_gravity * delta
		return
	
	var moving_on_floor = true
	if current_state == states.SPRINTING:
		speed = SPRINTSPEED
	elif current_state == states.CROUCHING:
		speed = CROUCHSPEED
	elif current_state == states.WALKING:
		speed = WALKSPEED
	else:
		moving_on_floor = false
	
	if moving_on_floor:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		return
	
	if current_state == states.SLIDING:
		speed = SPRINTSPEED
		velocity.x = slide_direction.x * speed
		velocity.z = slide_direction.z * speed
	if current_state == states.SLIDE_FALLING:
		speed = WALKSPEED
		velocity.x = lerp(velocity.x, slide_direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, slide_direction.z * speed, delta * 3.0)
		velocity.y += fall_gravity * delta
		
	
	if current_state == states.IDLE:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 10.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 10.0)
		return


func transition_into_state(direction:Vector3, new:states) -> void:
	
	if new == states.FALLING || new == states.SLIDE_FALLING:
		start_falling_time = Time.get_ticks_msec()
	
	if new == states.SLIDING and current_state != states.SLIDE_FALLING:
		slide_start_time = Time.get_ticks_msec()
		slide_direction = Vector3(direction.x, 0.0, direction.z).normalized()
		slide_angle_degrees = rad_to_deg(Vector3(0, 0, -1).angle_to(slide_direction))
	
	if new == states.JUMPING:
		velocity.y = jump_velocity
		
	
	last_state = current_state
	current_state = new

func determine_next_state(move_direction:Vector3) -> states:
	var moving : bool = move_direction != Vector3.ZERO # is not zero if: holding one or more movement keys
	
	if Input.is_action_pressed("jump"):
		if is_on_floor():
			if not (current_state == states.CROUCHING || current_state == states.SLIDING):
				just_jumped = true
				return states.JUMPING
		elif (((Time.get_ticks_msec() - start_falling_time) / 1000.0) < max_coyotejump_time) and not just_jumped:
			just_jumped = true
			return states.JUMPING
	
	
	if not is_on_floor():
		if not (current_state == states.SLIDING || current_state == states.SLIDE_FALLING ):
			return states.FALLING
	
	if current_state == states.IDLE:
		if Input.is_action_just_pressed("crouch"):
			return states.CROUCHING
		if moving: 
			if Input.is_action_pressed("sprint"):
				return states.SPRINTING
			else:
				return states.WALKING

	if current_state == states.WALKING:
		if Input.is_action_just_pressed("crouch"):
			return states.CROUCHING
		if moving:
			if Input.is_action_pressed("sprint"):
				return states.SPRINTING
			else:
				return states.WALKING
	
	if current_state == states.CROUCHING:
		if Input.is_action_just_pressed("crouch"):
			if moving:
				return states.WALKING
			else:
				return states.IDLE
		elif moving:
			if Input.is_action_pressed("sprint"):
				return states.SPRINTING
			else:
				return states.CROUCHING
		else:
			return states.CROUCHING
	
	if current_state == states.SPRINTING:
		if Input.is_action_pressed("sprint"):
			if moving:
				if Input.is_action_just_pressed("crouch"):
					return states.SLIDING
				else:
					return states.SPRINTING
			else:
				return states.IDLE
		else:
			if moving:
				return states.WALKING
			else:
				return states.IDLE
	
	if current_state == states.SLIDING:
		if Input.is_action_just_pressed("crouch") or ((Time.get_ticks_msec() - slide_start_time) / 1000.0) > MAX_SLIDE_DURATION_SECONDS:
			if Input.is_action_pressed("sprint") and moving:
				return states.SPRINTING
			else:
				return states.CROUCHING
		else:
			if is_on_floor():
				return states.SLIDING
			else:
				return states.SLIDE_FALLING
	
	if current_state == states.SLIDE_FALLING:
		if Input.is_action_just_pressed("crouch") or (((Time.get_ticks_msec() - slide_start_time) / 1000.0) > MAX_SLIDE_DURATION_SECONDS) or (((Time.get_ticks_msec() - start_falling_time) / 1000.0) > max_fall_slide_time):
			if is_on_floor():
				if moving:
					if Input.is_action_pressed("sprint"):
						return states.SPRINTING
					else:
						return states.WALKING
				else:
					return states.IDLE
			return states.FALLING
		if is_on_floor():
			return states.SLIDING
		else:
			return states.SLIDE_FALLING
	
	if current_state == states.FALLING:
		if is_on_floor():
			return states.LANDING
	
	if current_state == states.LANDING:
		just_jumped = false
	
	return states.IDLE


func update_fov(delta: float) -> void:
	var temp := Vector2(velocity.x, velocity.z)
	var velocity_clamped = clamp(temp.length(), 0.5, SPRINTSPEED * 2)
	var target_fov = base_fov + fov_multiplier * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

func get_state_name(state_value: states) -> String:
	for key in states.keys():
		if states[key] == state_value:
			return key
	return "UNKNOWN"

func create_debug_labels() -> void:
	testHUD.createLabel("state")
	testHUD.createLabel("laststate")
	testHUD.createLabel("velocity")
	testHUD.createLabel("position")
	testHUD.createLabel("speed")
	
func update_debug_labels() -> void:
	testHUD.updateLabel("state", "current state: " + get_state_name(current_state))
	testHUD.updateLabel("laststate", "last state: " + get_state_name(last_state))
	testHUD.updateLabel("velocity", "velocity: " + vec3_to_str(velocity, 2))
	testHUD.updateLabel("position", "position (x, y, z): " + vec3_to_str(global_position, 2))
	testHUD.updateLabel("speed", "actual speed: " + ("%0.2f" % velocity.length()) + " | speed var: " + str(speed))

func vec3_to_str(vec3:Vector3, decimal_places:int) -> String:
	var temp = "%0." + str(decimal_places) + "f, %0." + str(decimal_places) + "f, %0." + str(decimal_places) + "f"
	return temp % [vec3.x, vec3.y, vec3.z]

func calculate_fall_gravity(height: float, time_to_descent: float) -> float:
	return -(2.0 * height) / pow(time_to_descent, 2.0)
func calculate_jump_gravity(height: float, time_to_peak: float) -> float:
	return -(2.0 * height) / pow(time_to_peak, 2.0)
func calculate_jump_velocity(height: float, time_to_peak: float) -> float:
	return -(-2.0 * height) / time_to_peak
