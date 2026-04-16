extends Node3D

enum Axis { X, Y, Z }
enum DoorState { CLOSED, OPEN_CW, OPEN_CCW }

@export var axis: Axis = Axis.Y
@export var angle: float = 90.0
@export var speed: float = 90.0 # degrees per second
@export var close_delay: float = 0.0
@export var ccw: bool = false
@export var auto_dir: bool = true

var is_open := false
var moving := false
var open_dir := true # true = CW

var closed_rotation: Vector3
var current_tween: Tween

func _ready():
    closed_rotation = rotation_degrees
    open_dir = !ccw


# 🔘 Main trigger (like activate/trigger in Unity)
func activate(actor: Node3D = null):
    if moving:
        return

    if is_open:
        await close_door()
    else:
        if actor and auto_dir and axis == Axis.Y:
            var local = to_local(actor.global_position)

            if ccw:
                open_dir = local.x > 0
            else:
                open_dir = local.x < 0

        await open_door()


# 🚪 OPEN
func open_door():
    moving = true

    var target_angle = angle if open_dir else -angle
    var target_rot = closed_rotation

    match axis:
        Axis.X: target_rot.x += target_angle
        Axis.Y: target_rot.y += target_angle
        Axis.Z: target_rot.z += target_angle

    current_tween = create_tween()
    current_tween.set_trans(Tween.TRANS_SINE)
    current_tween.set_ease(Tween.EASE_OUT)

    current_tween.tween_property(self, "rotation_degrees", target_rot, angle / speed)

    await current_tween.finished

    moving = false
    is_open = true

    if close_delay > 0:
        await get_tree().create_timer(close_delay).timeout
        if is_open and not moving:
            await close_door()


# 🚪 CLOSE
func close_door():
    moving = true

    current_tween = create_tween()
    current_tween.set_trans(Tween.TRANS_SINE)
    current_tween.set_ease(Tween.EASE_IN)

    current_tween.tween_property(self, "rotation_degrees", closed_rotation, angle / speed)

    await current_tween.finished

    moving = false
    is_open = false