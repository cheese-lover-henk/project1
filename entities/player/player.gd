extends CharacterBody3D

@onready var HeadPivotPoint = $HeadPivotPoint
@onready var camera = $HeadPivotPoint/Camera3D

@onready var testHUD = $HeadPivotPoint/Camera3D/CanvasLayer/testHUD
@onready var TimerLabel = $HeadPivotPoint/Camera3D/CanvasLayer/HUD/Label
@onready var pauseMenu = $HeadPivotPoint/Camera3D/CanvasLayer/HUD/Node/PAUSEMENU

@onready var collisionShapeStanding = $CollisionShape3D
@onready var collisionShapeCrouching = $CollisionShapeCrouch
@onready var collisionShapeVaulting = $CollisionShapeVault

@onready var CameraPosUprightMarker = $HeadPivotPoint/CameraPositionUpright
@onready var CameraPosCrouchingMarker = $HeadPivotPoint/CameraPositionCrouch
@onready var CameraPosVaultingMarker = $HeadPivotPoint/CameraPositionVault

@onready var CrouchingHeadbumpRaycast = $raycasts/crouching_headbumpcast

@onready var flashlight = $HeadPivotPoint/SpotLight3D

@onready var raycastsNode = $raycasts

class DetectedLedge:
	var point_a:Vector3
	var point_b:Vector3
	var normal:Vector3
	func _init(p_a:Vector3, p_b:Vector3, n:Vector3) -> void:
		point_a = p_a
		point_b = p_b
		normal = n

@onready var detected_ledges : Array[DetectedLedge] = []

var TimerStartTime : int
var TimerEndTime : int
var TimerTotalRuntimeMS : int
var timer_running : bool = false

var pausedTime : float = 0.0

var wall_angle_variation = 15.0
var max_wall_angle : float = 90 + wall_angle_variation
var min_wall_angle : float = 90 - wall_angle_variation

var max_top_surface_angle_degrees : float = 40.0

var raycasts : Array[RayCast3D]
var shiftingRaycast : RayCast3D
const vaulting_obstacle_min_height : float = 0.5
const vaulting_obstacle_max_height : float = 1.4
const vaulting_obstacle_max_depth : float = 1.0
const vault_scanarea = [0.2, 1.0]
const vault_scan_incerement = 0.1
const vault_scan_distance = 2.0 
const vaulting_gap_min_height : float = 1.1
const vaulting_gap_min_width : float = 1.5
const vaulting_landingarea_minfloorheightdiff : float = 1.0
const vaulting_landingarea_mindepth : float = 1.0
const min_vaulting_speed : float = 7.0

var vault_end_position : Vector3
var vault_duration : float
var vault_gravity : float

var vault_start_position : Vector3
var vault_start_time : int
var vault_obstacle_startpos : Vector3
var vault_obstacle_endpos : Vector3
var vault_reached : bool = false
var vault_entry_speed : float

const vaulting_head_tilt_degrees : float = 15.0 # rotation along Z axis camera

var min_clearance_depth_hanging = 0.1
var min_clearance_height_hanging = 0.1

var min_clearance_depth_climbing = 0.7
var min_clearance_height_climbing = 1.1 # climb onto then crouch

const WALKSPEED = 4.0
const SPRINTSPEED = 7.0
const CROUCHSPEED = 2.4
const MAX_SLIDE_DURATION_SECONDS = 0.9
var slide_start_time = 0
var slide_direction := Vector3.ZERO
var slide_angle_degrees : float = 0.0
var sliding_camera_clamp_offset : float = 55.0
var max_fall_slide_time : float = 0.3
var slide_speed_boost : float = 1.2

var max_coyotejump_time : float = 0.2
var just_jumped : bool = false

var start_falling_time : int = 0
var fall_duration : float = 0.0

var sensitivity = 0.003
@export var sens_multiplier : float = 1.0

var speed = WALKSPEED
var input_dir : Vector2

var jump_height = 0.75
var jump_time_to_peak = 0.30
var jump_time_to_fall = 0.25

var start_jump_hold_time_ms : int = 0
var max_jump_hold_time_seconds : float = 0.10
var last_jump_press : int = 0
var max_pre_jump_buffer : float = 0.17

var max_step_height = 0.4
var max_step_distance = 0.15

@onready var jump_gravity := calculate_jump_gravity(jump_height, jump_time_to_peak)
@onready var fall_gravity := calculate_fall_gravity(jump_height, jump_time_to_fall)
@onready var jump_velocity := calculate_jump_velocity(jump_height, jump_time_to_peak)

var base_fov = 75.0
var fov_multiplier = 1.8

var target_camera_position : Vector3 = Vector3.ZERO
var target_camera_rotation_z : float = 0.0
var camera_offset_y : float = 0.0

const BOB_FREQ = 2.3
const BOB_AMP_DEFAULT = 0.11
const BOB_AMP_WALK = 0.05
var t_bob = 0.0

var paused : bool = false

var hasMoved : bool = false

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
	VAULTING
}

var max_small_height = 4.0
var max_medium_height = 8.0

var last_state:states = states.IDLE
var current_state:states = states.IDLE
var next_state:states = states.IDLE

func _ready() -> void:
	Globals.player = self
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if testHUD != null:
		create_debug_labels()
	if TimerLabel != null:
		TimerLabel.text = ""
	target_camera_position = CameraPosUprightMarker.position
	shiftingRaycast = create_raycast(Vector3.ZERO, Vector3.ZERO)
	
	var ray_height = vault_scanarea[0]
	var ray_maxheight = vault_scanarea[1]
	while ray_height <= ray_maxheight:
		raycasts.push_back(create_raycast(Vector3(0.0, ray_height, 0.0), vault_scan_distance * Vector3.FORWARD))
		ray_height += vault_scan_incerement
	raycasts.reverse()

func _unhandled_input(event) -> void:
	if event is InputEventMouseMotion and not paused:
		if current_state == states.SLIDING || current_state == states.SLIDE_FALLING:
			var delta = -event.relative.x * sensitivity * sens_multiplier
			var new_angle = wrapf(rotation_degrees.y + delta, -180.0, 180.0)

			var min_angle = slide_angle_degrees - sliding_camera_clamp_offset
			var max_angle = slide_angle_degrees + sliding_camera_clamp_offset

			if is_angle_between(new_angle, min_angle, max_angle):
				self.rotate_y(delta)
			elif angle_distance(new_angle, min_angle) < angle_distance(new_angle, max_angle):
				rotation.y = deg_to_rad(min_angle)
			else:
				rotation.y = deg_to_rad(max_angle)
		else:
			self.rotate_y(-event.relative.x * sensitivity * sens_multiplier)
		camera.rotate_x(-event.relative.y * sensitivity * sens_multiplier)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90)) # straight up and down
		if not current_state == states.VAULTING:
			camera.rotation.z = 0.0
		camera.rotation.y = 0.0
		flashlight.rotation.x = camera.rotation.x

func _physics_process(delta: float) -> void:
	if pauseMenu.should_quit:
		get_tree().change_scene_to_file("res://menus/menu_background_scene/main_menu_bg.tscn")
		return

	if paused:
		if pauseMenu.should_unpause:
			pauseMenu.should_unpause = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			paused = false
			print("resume")
		else:
			return
	
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	if input_dir != Vector2.ZERO and hasMoved == false:
		start_timer()
		hasMoved = true
	
	var direction := Vector3(HeadPivotPoint.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	next_state = determine_next_state(direction)
	if current_state != next_state:
		transition_into_state(direction, next_state)
	
	handle_movement_state(direction, delta)
	move_and_slide()

func _process(delta: float) -> void:
	if paused:
		if timer_running:
			pausedTime += delta
	
	if Input.is_action_just_pressed("debuginfo"):
		testHUD.visible = !testHUD.visible
	
	update_fov(delta)
	if testHUD != null:
		update_debug_labels()
	if not paused:
		TimerLabel.text = Globals.msToTimeFormat(get_timer_time())
	
	# move camera to correct position, with headbob if walking
	if current_state == states.WALKING || current_state == states.SPRINTING:
		t_bob += delta * velocity.length()
		camera.position = lerp(camera.position, target_camera_position + getHeadbobOffset(t_bob), delta * 10.0)
	else:
		camera.position = lerp(camera.position, target_camera_position, delta * 10.0)
	camera.rotation_degrees.z = lerp(camera.rotation_degrees.z, target_camera_rotation_z, delta * 7)
	if(Input.is_action_just_pressed("esc") and (not paused)):
		paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		pauseMenu.visible = true
		print("pause")
	
	flashlight.position = lerp(flashlight.position, target_camera_position, delta * 10.0)

func getHeadbobOffset(time : float) -> Vector3:
	var v = Vector3.ZERO
	var bob_amp
	var bob_freq
	if current_state == states.WALKING:
		bob_amp = BOB_AMP_WALK
		bob_freq = BOB_FREQ * 1.5
	elif current_state == states.SPRINTING:
		bob_amp = BOB_AMP_DEFAULT
		bob_freq = BOB_FREQ
	v.y = sin(time * bob_freq) * bob_amp
	v.x = cos(time * bob_freq / 2) * bob_amp
	return v

func handle_movement_state(direction:Vector3, delta:float) -> void:
	if current_state == states.VAULTING:
		var elapsed := (Time.get_ticks_msec() - vault_start_time) / 1000.0

		var forward := -global_transform.basis.z
		velocity.x = forward.x * vault_entry_speed
		velocity.z = forward.z * vault_entry_speed

		# Let the precomputed gravity drive the arc naturally
		velocity.y += vault_gravity * delta

		if elapsed >= vault_duration:
			vault_reached = true

		return
	
	if current_state == states.FALLING:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
		if velocity.y >= 0.0:
			if Input.is_action_just_released("jump"):
				velocity.y = 0.75 * velocity.y
			else:
				velocity.y += jump_gravity * delta
		else:
			velocity.y += fall_gravity * delta
		return
	
	if current_state == states.JUMPING:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	
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
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 11.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 11.0)
		return
	
	if current_state == states.SLIDING:
		velocity.x = lerp(velocity.x, slide_direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, slide_direction.z * speed, delta * 3.0)
	if current_state == states.SLIDE_FALLING:
		velocity.x = lerp(velocity.x, slide_direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, slide_direction.z * speed, delta * 3.0)
		velocity.y += fall_gravity * delta
		
	
	if current_state == states.IDLE:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 10.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 10.0)
		return

func transition_into_state(direction:Vector3, new:states) -> void:
	if current_state == states.VAULTING:
		var forward := -global_transform.basis.z
		velocity.x = forward.x * vault_entry_speed
		velocity.z = forward.z * vault_entry_speed
		#velocity.y = 0.0
	
	if new == states.CROUCHING || new == states.SLIDING || new == states.SLIDE_FALLING:
		collisionShapeCrouching.disabled = false
		collisionShapeStanding.disabled = true
		collisionShapeVaulting.disabled = true
		target_camera_position = CameraPosCrouchingMarker.position
	elif new == states.VAULTING:
		collisionShapeCrouching.disabled = true
		collisionShapeStanding.disabled = true
		collisionShapeVaulting.disabled = false
		target_camera_position = CameraPosVaultingMarker.position

		var forward := -global_transform.basis.z

		vault_entry_speed = Vector3(velocity.x, 0.0, velocity.z).length()
		vault_start_position = global_position
		vault_start_time = Time.get_ticks_msec()
		vault_reached = false

		vault_end_position = vault_obstacle_endpos + forward * 0.9
		vault_end_position.y = vault_obstacle_endpos.y

		var horizontal_to_end := Vector3(
			vault_end_position.x - vault_start_position.x,
			0.0,
			vault_end_position.z - vault_start_position.z
		).length()
		vault_duration = horizontal_to_end / max(vault_entry_speed, 0.1)

		var rise := (vault_obstacle_startpos.y + 0.1) - global_position.y
		var t_to_peak := vault_duration * 0.5
		velocity.y = (2.0 * rise) / t_to_peak

		vault_gravity = (-2.0 * rise) / (t_to_peak * t_to_peak)

		target_camera_rotation_z = vaulting_head_tilt_degrees
	else:
		collisionShapeCrouching.disabled = true
		collisionShapeStanding.disabled = false
		collisionShapeVaulting.disabled = true
		target_camera_position = CameraPosUprightMarker.position
		target_camera_rotation_z = 0.0
	
	if new == states.FALLING || new == states.SLIDE_FALLING:
		start_falling_time = Time.get_ticks_msec()
	
	if new == states.SLIDING and current_state != states.SLIDE_FALLING:
		velocity = Vector3(velocity.x * slide_speed_boost, velocity.y, velocity.z * slide_speed_boost)
		slide_start_time = Time.get_ticks_msec()
		slide_direction = Vector3(direction.x, 0.0, direction.z).normalized()
		slide_angle_degrees = rotation_degrees.y
	
	if new == states.JUMPING:
		velocity.y = jump_velocity
	
	if new == states.SPRINTING:
		$"Fast Run/AnimationPlayer".play("mixamo_com")
	else:
		$"Fast Run/AnimationPlayer".stop(true)
	
	last_state = current_state
	current_state = new

func determine_next_state(move_direction:Vector3) -> states:
	var moving : bool = move_direction != Vector3.ZERO # is not zero if: holding one or more movement keys
	
	if current_state == states.VAULTING:
		if not vault_reached:
			return states.VAULTING
		elif moving:
			if Input.is_action_pressed("sprint"):
				return states.SPRINTING
			else:
				return states.WALKING
	if Input.is_action_just_pressed("jump"):
		last_jump_press = Time.get_ticks_msec()
		if is_on_floor():
			if not (current_state == states.CROUCHING or current_state == states.SLIDING):
				just_jumped = true
				last_jump_press = 0
				start_jump_hold_time_ms = Time.get_ticks_msec()
				return states.JUMPING

		elif ((Time.get_ticks_msec() - start_falling_time) / 1000.0) < max_coyotejump_time and not just_jumped:
			just_jumped = true
			start_jump_hold_time_ms = Time.get_ticks_msec()
			return states.JUMPING
	if Input.is_action_pressed("jump") and not (current_state == states.CROUCHING or current_state == states.SLIDING):
		if current_state == states.JUMPING:
			var elapsed := (Time.get_ticks_msec() - start_jump_hold_time_ms) / 1000.0
			if elapsed < max_jump_hold_time_seconds:
				return states.JUMPING
		if velocity.length() > min_vaulting_speed and vault_conditions_check():
			return states.VAULTING
		elif ((Time.get_ticks_msec() - last_jump_press) / 1000.0) < max_pre_jump_buffer and is_on_floor():
			just_jumped = true
			start_jump_hold_time_ms = Time.get_ticks_msec()
			return states.JUMPING
	
	if not is_on_floor():
		if not (current_state == states.SLIDING || current_state == states.SLIDE_FALLING ):
			return states.FALLING
	
	if current_state == states.IDLE:
		if Input.is_action_just_pressed("crouch"):
			return states.CROUCHING
		if moving: 
			# on each check for sprint button: check if walking forward. you should only be able to sprint if you are walking forward. walking forward -> input_dir.y = -1
			if Input.is_action_pressed("sprint") and input_dir.y < 0:
				return states.SPRINTING
			else:
				return states.WALKING

	if current_state == states.WALKING:
		if Input.is_action_just_pressed("crouch"):
			return states.CROUCHING
		if moving:
			if Input.is_action_pressed("sprint") and input_dir.y < 0:
				return states.SPRINTING
			else:
				return states.WALKING
	
	if current_state == states.CROUCHING:
		if Input.is_action_just_pressed("crouch"):
			if not scan_raycast(CrouchingHeadbumpRaycast).is_colliding():
				if moving:
					return states.WALKING
				else:
					return states.IDLE
			else:
				return states.CROUCHING
		elif moving:
			if Input.is_action_pressed("sprint") and input_dir.y < 0 and not scan_raycast(CrouchingHeadbumpRaycast).is_colliding():
				return states.SPRINTING
			else:
				return states.CROUCHING
		else:
			return states.CROUCHING
	
	if current_state == states.SPRINTING:
		if Input.is_action_pressed("sprint") and input_dir.y < 0:
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
			if Input.is_action_pressed("sprint") and input_dir.y < 0 and not scan_raycast(CrouchingHeadbumpRaycast).is_colliding():
				return states.SPRINTING
			else:
				return states.CROUCHING
		else:
			if is_on_floor(): #TODO: || distance to floor is less then a small number (eg 0.05)
				if Input.is_action_just_pressed("jump"):
					if scan_raycast(CrouchingHeadbumpRaycast).is_colliding():
						return states.CROUCHING
					else:
						return states.JUMPING
				else:
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

func vault_conditions_check() -> bool:
	#info we are trying to get with raycasts:
	var obstacle_depth : float
	var gap_heights : Array[float] = [0.0, 0.0, 0.0] #height on the right side, height in middle, height on the right side
	var gap_widths : Array[float] = [0.0, 0.0] #width at bottom, width at top
	var landing_space_depth : float # to see if there is enough space for the player to land after vaulting over
	var landing_space_relative_height : float # height of the floor on other side of obstacle to check if vaulting is better or climbing on / through is better

	var initialHitGlobal
	var hit = false
	var wall_normal_global : Vector3
	for ray in raycasts: # raycasts array starts with highest relative position to player, so first hit is highest hit of scanning rays
		scan_raycast(ray)
		if ray.is_colliding():
			initialHitGlobal = ray.get_collision_point()
			#DebugDraw3D.draw_line(initialHitGlobal, ray.global_position)
			hit = true
			wall_normal_global = ray.get_collision_normal()
			break
	if not hit:
		return false # nothing in front of us found with raycasts.
	var initialHitLocal = self.to_local(initialHitGlobal)
	
	# check the height of the surface we want to try vaulting over
	var global_bottomedge_point : Vector3
	var _local_bottomedge_point : Vector3
	scan_raycast(shiftingRaycast, Vector3(initialHitLocal.x, initialHitLocal.y + vaulting_gap_min_height, initialHitLocal.z - 0.01), Vector3(0.0, -vaulting_gap_min_height, 0.0))
	if shiftingRaycast.is_colliding():
		global_bottomedge_point = shiftingRaycast.get_collision_point()
		_local_bottomedge_point = self.to_local(global_bottomedge_point)
		#DebugDraw3D.draw_arrow(shiftingRaycast.global_position, global_bottomedge_point, Color.RED, 0.1)
		var diff = global_bottomedge_point.y - self.global_position.y
		if not (diff > vaulting_obstacle_min_height and diff < vaulting_obstacle_max_height):
			return false # height relative to player is not within set min - max values
	else:
		return false # this should probably never be reached, because we are scanning down onto a target we know exists, but lets return false just in case if we dont find the object
	
	# check the height of any edges or ceilings that exist above the gap we might want to vault through
	var global_topedge_point : Vector3
	var _local_topedge_point : Vector3
	scan_raycast(shiftingRaycast, self.to_local(global_bottomedge_point + Vector3(0.0, 0.01, 0.0)), Vector3(0.0, vaulting_gap_min_height, 0.0))
	if shiftingRaycast.is_colliding(): # we scan from right on top of the gap bottom edge upwards, as far as the minimum gap height, so if collides: the height is less then min. but we double check with the coordinate of the hit
		global_topedge_point = shiftingRaycast.get_collision_point()
		_local_topedge_point = self.to_local(global_topedge_point)
		gap_heights[1] = global_bottomedge_point.distance_to(global_topedge_point)
	else:
		gap_heights[1] = vaulting_gap_min_height
		global_topedge_point = shiftingRaycast.to_global(shiftingRaycast.target_position)
		_local_topedge_point = shiftingRaycast.position + shiftingRaycast.target_position
	
	if gap_heights[1] < vaulting_gap_min_height:
		return false # height of gap not big enough
	
	# check the width of the gap we might want to vault through, save the corner points
	var bottom_right_global : Vector3
	var bottom_right_local : Vector3
	var bottom_left_global : Vector3
	var bottom_left_local : Vector3
	scan_raycast(shiftingRaycast, self.to_local(global_bottomedge_point) + Vector3(0.0, 0.01, 0.0), to_local_dir(wall_normal_global.cross(Vector3.UP) * (vaulting_gap_min_width * 0.6)))
	if shiftingRaycast.is_colliding():
		bottom_left_global = shiftingRaycast.get_collision_point()
	else:
		bottom_left_global = shiftingRaycast.to_global(shiftingRaycast.target_position)
	bottom_left_local = self.to_local(bottom_left_global)
	scan_raycast(shiftingRaycast, self.to_local(global_bottomedge_point) + Vector3(0.0, 0.01, 0.0), to_local_dir(flip_dir_horizontal(wall_normal_global.cross(Vector3.UP) * (vaulting_gap_min_width * 0.6))))
	if shiftingRaycast.is_colliding():
		bottom_right_global = shiftingRaycast.get_collision_point()
	else:
		bottom_right_global = shiftingRaycast.to_global(shiftingRaycast.target_position)
	bottom_right_local = self.to_local(bottom_right_global)
	
	
	#scan upwards from the corners, to check if the expected gap height is still the same.
	var top_right_global : Vector3
	var _top_right_local : Vector3
	var top_left_global : Vector3
	var _top_left_local : Vector3
	scan_raycast(shiftingRaycast, bottom_right_local + Vector3(-0.01, 0.0, 0.0), Vector3(0.0, vaulting_gap_min_height, 0.0))
	if shiftingRaycast.is_colliding():
		top_right_global = shiftingRaycast.get_collision_point()
	else:
		top_right_global = shiftingRaycast.global_position + shiftingRaycast.target_position
	_top_right_local = self.to_local(top_right_global)
	
	scan_raycast(shiftingRaycast, bottom_left_local + Vector3(0.01, 0.0, 0.0), Vector3(0.0, vaulting_gap_min_height, 0.0))
	if shiftingRaycast.is_colliding():
		top_left_global = shiftingRaycast.get_collision_point()
	else:
		top_left_global = shiftingRaycast.global_position + shiftingRaycast.target_position
	_top_left_local = self.to_local(_top_left_local)
	
	if (top_right_global.distance_to(bottom_right_global) < vaulting_gap_min_height or
			top_left_global.distance_to(bottom_left_global) < vaulting_gap_min_height or
			bottom_left_global.distance_to(bottom_right_global) < vaulting_gap_min_width or
			top_left_global.distance_to(top_right_global) < vaulting_gap_min_width):
		return false
	
	# check if its not just a hole in a wall but actually has enough space to possibly be a vaultable thingie
	scan_raycast(shiftingRaycast, _local_bottomedge_point + Vector3(0.0, 0.01, 0.0), Vector3.FORWARD * (vaulting_obstacle_max_depth + vaulting_landingarea_mindepth))
	if shiftingRaycast.is_colliding():
		DebugDraw3D.draw_line(shiftingRaycast.global_position, shiftingRaycast.to_global(shiftingRaycast.target_position), Color.ORANGE_RED)
		return false
	
	# getting obstacle depth:
	var scan_increments = 0.05
	var i = _local_bottomedge_point.z
	var end = _local_bottomedge_point.z - vaulting_obstacle_max_depth
	var _x = _local_bottomedge_point.x
	var _y = _local_bottomedge_point.y + 0.01
	var end_found = false
	while (i > end):
		scan_raycast(shiftingRaycast, Vector3(_x, _y, i), Vector3(0.0, -0.5, 0.0))
		if not shiftingRaycast.is_colliding(): # if not colliding, then the end of the obstacle is found
			DebugDraw3D.draw_line(shiftingRaycast.global_position + (Vector3.UP * 0.25), shiftingRaycast.to_global(shiftingRaycast.target_position), Color.SKY_BLUE)
			end_found = true
			break
		i -= scan_increments
	
	vault_obstacle_endpos = shiftingRaycast.global_position
	
	if end_found:
		DebugDraw3D.draw_line(global_bottomedge_point, shiftingRaycast.global_position, Color.GREEN)
		obstacle_depth = abs(_local_bottomedge_point.z - i)
	else:
		return false #TODO: check if climb on top is viable
	
	#check how high the floor is behind obstacle
	scan_raycast(shiftingRaycast, shiftingRaycast.position, Vector3.DOWN * 2.0) # scan down 2 meters
	if shiftingRaycast.is_colliding():
		landing_space_relative_height = abs(shiftingRaycast.get_collision_point().y - self.global_position.y)
	else:
		landing_space_relative_height = 2.1
	
	
	#DebugDraw3D.draw_line(bottom_right_global, top_right_global, Color.GREEN)
	#DebugDraw3D.draw_line(bottom_left_global, top_left_global, Color.GREEN)
	#DebugDraw3D.draw_line(bottom_left_global, bottom_right_global, Color.GREEN)
	
	vault_obstacle_startpos = global_bottomedge_point
	
	return true

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
	testHUD.updateLabel("speed", "actual speed: " + ("%0.2f" % velocity.length()) + " | horizontal speed (ignoring up/down) : " + ("%0.2f" % Vector3(velocity.x, 0.0, velocity.z).length()) + " | speed var: " + str(speed))

func vec3_to_str(vec3:Vector3, decimal_places:int) -> String:
	var temp = "%0." + str(decimal_places) + "f, %0." + str(decimal_places) + "f, %0." + str(decimal_places) + "f"
	return temp % [vec3.x, vec3.y, vec3.z]
func calculate_fall_gravity(height: float, time_to_descent: float) -> float:
	return -(2.0 * height) / pow(time_to_descent, 2.0)
func calculate_jump_gravity(height: float, time_to_peak: float) -> float:
	return -(2.0 * height) / pow(time_to_peak, 2.0)
func calculate_jump_velocity(height: float, time_to_peak: float) -> float:
	return -(-2.0 * height) / time_to_peak
func wrap_angle(angle: float) -> float:
	return wrapf(angle, -180.0, 180.0)
func angle_distance(a: float, b: float) -> float:
	return abs(wrapf(a - b, -180.0, 180.0))
func is_angle_between(angle: float, min_angle: float, max_angle: float) -> bool:
	angle = wrap_angle(angle)
	min_angle = wrap_angle(min_angle)
	max_angle = wrap_angle(max_angle)

	if min_angle <= max_angle:
		return angle >= min_angle and angle <= max_angle
	else:
		return angle >= min_angle or angle <= max_angle
func create_raycast(startingPos : Vector3, targetPos : Vector3) -> RayCast3D:
	var ray := RayCast3D.new()
	ray .position = startingPos
	ray.target_position = targetPos
	
	ray.enabled = false
	ray.add_exception(self)
	raycastsNode.add_child(ray)
	
	return ray
func scan_raycast(ray : RayCast3D, pos = null, target = null) -> RayCast3D:
	if pos == null: pos = ray.position
	if target == null: target = ray.target_position
	ray.position = pos
	ray.target_position = target
	ray.force_raycast_update()
	return ray
func flip_dir_horizontal(dir : Vector3) -> Vector3:
	return Vector3(-dir.x, dir.y, -dir.z)
func to_local_dir(global_direction : Vector3) -> Vector3:
	return global_transform.basis.inverse() * global_direction

func start_timer():
	TimerStartTime = Time.get_ticks_msec()
	TimerEndTime = 0
	timer_running = true

func stop_timer():
	if timer_running:
		TimerEndTime = Time.get_ticks_msec()
		TimerTotalRuntimeMS = TimerEndTime - TimerStartTime
		timer_running = false

func reset_timer():
	TimerEndTime = 0
	TimerStartTime = 0
	TimerTotalRuntimeMS = 0
	timer_running = false

func get_timer_time() -> int:
	if not timer_running:
		return TimerTotalRuntimeMS - int(pausedTime * 1000)
	if TimerEndTime == 0:
		return Time.get_ticks_msec() - TimerStartTime - int(pausedTime * 1000)
	TimerTotalRuntimeMS = TimerEndTime - TimerStartTime
	return TimerTotalRuntimeMS - int(pausedTime * 1000)
