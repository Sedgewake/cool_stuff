extends Node2D

var target_position : Vector2 = Vector2(500, 0)
var speed : float = 200  # Speed at which the door moves.

func _ready():
    start_moving()

# Function to start the movement
func start_moving():
    # Starts the movement coroutine
    move_door()

# Function to move the door
func move_door():
    var initial_position = position
    var distance = target_position - initial_position
    var duration = distance.length() / speed
    var timer = Timer.new()
    add_child(timer)
    timer.wait_time = duration
    timer.one_shot = true
    timer.start()

    # Yield for the timer to finish
    yield(timer, "timeout")
    position = target_position
    print("Door has finished moving.")
	
	
	
	
	
	
	
	
	
	
	extends Node2D

var target_position : Vector2 = Vector2(500, 0)
var speed : float = 200  # Speed at which the door moves.

func _ready():
    await move_door()

# Function to move the door
async func move_door():
    var initial_position = position
    var distance = target_position - initial_position
    var duration = distance.length() / speed
    var timer = Timer.new()
    add_child(timer)
    timer.wait_time = duration
    timer.one_shot = true
    timer.start()

    # Await the timer completion
    await timer.timeout
    position = target_position
    print("Door has finished moving.")
	






extends Node2D

var door : Node2D
var timer : Timer

func _ready():
    door = $Door
    timer = Timer.new()
    add_child(timer)
    timer.wait_time = 3  # Wait for 3 seconds
    timer.one_shot = true
    timer.start()
    timer.connect("timeout", self, "_on_timer_timeout")

# This function is called after the timer times out
func _on_timer_timeout():
    door.move()  # Move the door