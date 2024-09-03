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

#Preloaded Item Scenes
var scene_dict ={ 
"item1": preload("res://item1_scene.tscn"),
"item2": preload("res://item2_scene.tscn"),
}
#Item Orientations when grabbed
var item_orientations = {
	"item1": Transform3D(Basis(Quaternion(Vector3(1, 0, 0), deg_to_rad(25))), Vector3(0.1, 0.1, 0)),
	"item2": Transform3D(Basis(Quaternion(Vector3(0, 1, 0), deg_to_rad(45))), Vector3(0.1, -0.1, 0))
}

var item_to_spawn
var item_to_drop

#called to script
@onready var head = $head
@onready var camera = $head/Camera3D
@onready var pcap = $body_collision
@onready var hands = $head/Camera3D/hands
@onready var raycast_pickup = $head/Camera3D/raycast_pickup
@onready var drop_position = $head/drop_position
@onready var shapecast_drop = $head/Camera3D/shape_cast_drop
@onready var item_spawner = get_node("../items") 



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		$PauseMenu.pause()

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func grab():
	var item = raycast_pickup.get_collider()
	if item != null and item is RigidBody3D:
		print("Item Grabbed: ", item.name)
		#if item.is_in_group("junk"):	
		var base_name = item.name.split("_")[0] #Gets base name before any suffix
		if base_name in scene_dict:
			var scene_to_instantiate = scene_dict.get(base_name, null)
			if scene_to_instantiate: 
				var new_instance = scene_to_instantiate.instantiate()
				new_instance.name = item.name
				hands.add_child(new_instance)
				new_instance.collision_layer=0
				new_instance.set_deferred("freeze", true)
				var transform_to_apply = item_orientations[base_name]
				new_instance.global_transform = hands.global_transform * transform_to_apply
				item.queue_free()	
				print("JUNK")
func drop():
	var held_item = null
	
	if hands.get_child_count()> 0:
		held_item = hands.get_child(0)
		hands.remove_child(held_item)
		held_item.collision_layer=4
		held_item.set_deferred("freeze", false)
		item_spawner.add_child(held_item)
	# Create a new basis where Y rotation is zero
		var camera_basis = camera.global_transform.basis
		var new_basis = Basis(camera_basis.x, camera_basis.y, camera_basis.z)
		# Reset Y rotation
		new_basis.y = Vector3(0, 1, 0)  # Y axis is upright
		new_basis.x = camera_basis.x.normalized()  # X axis relative to the camera
		new_basis.z = camera_basis.z.normalized()  # Z axis relative to the camera
		held_item.global_transform.basis = new_basis
	if shapecast_drop.is_colliding():
		var base_name = held_item.name.split("_")[0]
		var transform_to_apply = item_orientations[base_name]
		held_item.global_transform = hands.global_transform * transform_to_apply
		held_item.linear_velocity = velocity
	else:
		var force = -18
		var player_rotation = camera.global_transform.basis.z
		var count = item_spawner.get_child_count()
		var last_child = item_spawner.get_child(count -1)
		print("count", count)
		print("last_child:", last_child)
		last_child.apply_central_impulse(player_rotation * force + Vector3(0, 3.5, 0))
		var base_name = held_item.name.split("_")[0]
		var transform_to_apply = item_orientations[base_name]
		held_item.global_transform = hands.global_transform * transform_to_apply
		
		print("THROW")
		
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
	#drop item
	if Input.is_action_just_pressed("drop") and hands.get_child_count() > 0:
		drop()
	
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
		
	
	move_and_slide()
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * Bob_Freq) * Bob_Amp
	pos.x = cos(time * Bob_Freq / 2) * Bob_Amp
	return pos
	
