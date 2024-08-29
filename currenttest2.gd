extends CharacterBody3D

#movement speed
var speed
const WALK_SPEED = 4.5
const SPRINT_SPEED = 6.0
const CROUCH_MOVE_SPEED = 2.5
#speed at which character crouches
var CROUCHING_SPEED = 20
#player height
var default_height = 1.5
var crouch_height = .75
#jump height
const JUMP_VELOCITY = 4.5
#mouse sensitivity
var SENSITIVITY = 0.0025  # Initialize with a default sensitivity value
#headbob variables
const Bob_Freq = 3.5
const Bob_Amp = .04
var t_bob = 0.0
# FOV variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5
# Custom gravity variables
var normal_gravity = Vector3(0, -9.8, 0)  # Normal gravity value for reference
var increased_gravity = Vector3(0, -12.0, 0)  # Increased gravity for faster fall

#called to script
@onready var head = $head
@onready var camera = $head/Camera3D
@onready var pcap = $body_collision
@onready var hands = $head/Camera3D/hands
@onready var rc_pickup = $head/Camera3D/rc_pickup

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func grab():
	var item = rc_pickup.get_collider()
	if item != null and item is RigidBody3D:
		if item.is_in_group("junk"):
			print("YOU FOUND JUNK") 
		else:
			print("NO JUNK HERE")
	
func _input(event):
	# Handle player movement
	if event is InputEventMouseMotion:
			head.rotate_y(-event.relative.x * SENSITIVITY)
			camera.rotate_x(-event.relative.y * SENSITIVITY)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(85))

func _physics_process(delta: float) -> void:
	# Apply gravity based on whether the player is jumping or falling
	if not is_on_floor():
		if velocity.y > 0:
			velocity += normal_gravity * delta
		else:
			velocity += increased_gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY  # Maintain jump height
		
	#pickup item
	if Input.is_action_just_pressed("pickup"):
		grab()
	
	# Crouching logic
	if Input.is_action_pressed("Crouch"):
		pcap.shape.height = max(crouch_height, pcap.shape.height - CROUCHING_SPEED * delta)
		speed = CROUCH_MOVE_SPEED
	else:
		pcap.shape.height = min(default_height, pcap.shape.height + CROUCHING_SPEED * delta)
		speed = WALK_SPEED  # Ensure speed is reset to walk speed when not crouching

	# Handle Sprint.
	if Input.is_action_pressed("Sprint") and not Input.is_action_pressed("Crouch"):
		speed = SPRINT_SPEED
	
	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("Left", "Right", "Foward", "Backward")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	# Smooth acceleration and deceleration
	var target_velocity = direction * speed
	
	if is_on_floor():
		velocity.x = lerp(velocity.x, target_velocity.x, delta * 10.0)
		velocity.z = lerp(velocity.z, target_velocity.z, delta * 10.0)
	else:
		# Apply a smaller lerp factor for smoother airborne movement
		velocity.x = lerp(velocity.x, target_velocity.x, delta * 3.0)
		velocity.z = lerp(velocity.z, target_velocity.z, delta * 3.0)
		
		# HEADBOB
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	if Input.is_action_pressed("Sprint") and not Input.is_action_pressed("Crouch"):
		var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
		var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
		camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	else:
		# Reset FOV to base value when not sprinting
		camera.fov = lerp(camera.fov, BASE_FOV, delta * 8.0)
	
	# Maintain the desired distance from the player
	move_and_slide()
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * Bob_Freq) * Bob_Amp
	pos.x = cos(time * Bob_Freq / 2) * Bob_Amp
	return pos
