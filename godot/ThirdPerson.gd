extends CharacterBody3D
class_name Player3

@export var player_camera: Camera3D
@export var character_mesh: Node3D
@export var move_speed: float = 5.0
@export var rotation_speed: float = 3.0

var frame_time: float = 0.0
var rotation_input: float
var look_input: float
var look_y: float = 0.0
var rotation_xq: Quaternion
var verticalVelocity = 0.0
var gravity = -12.0
var cam_dist = 1.5

# Called when the node enters the scene tree for the first time.
func _ready():
	floor_block_on_wall = false
	rotation_xq = transform.basis.get_rotation_quaternion()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pass # Replace with function body.

func _input(event):
	if event is InputEventMouseMotion:
		rotation_input = event.screen_relative.x * rotation_speed * -0.001
		look_input = event.screen_relative.y * rotation_speed * 0.001  # Make vertical look less sensitive

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float):
	frame_time = delta
	
	var h = Input.get_axis("ui_left", "ui_right")
	var v = Input.get_axis("ui_up", "ui_down")
	
	var input = Vector3(h, 0, v).normalized()
	
	var Cam_forward = player_camera.transform.basis.z
	var Cam_right = player_camera.transform.basis.x
	Cam_forward.y = 0
	Cam_right.y = 0
	Cam_forward = Cam_forward.normalized()
	Cam_right = Cam_right.normalized()
	var moveDir = Cam_forward * input.z + Cam_right * input.x;
	if is_on_floor():
		verticalVelocity = -1.0
	else:
		verticalVelocity += gravity * frame_time

	velocity = moveDir * move_speed + Vector3.UP * verticalVelocity;
	move_and_slide()
	if velocity.length() > 0.01:
		var look_dir = velocity.normalized()
		var target_rotation = atan2(look_dir.x, look_dir.z)
		character_mesh.rotation.y = lerp_angle(character_mesh.rotation.y, target_rotation, delta * 15.0)
	
	
	look_y -= look_input
	look_y = clamp(look_y, -1.55, 1.55)
	rotation_xq *= Quaternion.from_euler(Vector3(0, rotation_input, 0))
	rotation_input = 0.0
	look_input = 0.0
	var x2 = rotation_xq * Quaternion.from_euler(Vector3(look_y, 0, 0))
	var CamPosition = x2 * (-Vector3.FORWARD + Vector3(0.25, 0, 0)) * cam_dist;
	player_camera.transform.basis = Basis(x2)
	player_camera.global_position = global_position + CamPosition + Vector3(0, 0.5, 0)

	
