extends Area2D

# Node references 
@onready var tile_map = $"../TileMap"
@onready var space_bar_progress = $"../CanvasLayer/UI/SpaceBarProgress"
@onready var move_counter = $"../CanvasLayer/UI/MoveCounter"
@onready var decay_timer = $"../CanvasLayer/Timers/SpaceBarDecayTimer"
@onready var no_input_timer = $"../CanvasLayer/Timers/NoInputTimer"
@onready var ray = $RayCast2D
@onready var inventory_label = $"../CanvasLayer/UI/InventoryLabel"  # For displaying coin count

var tile_size = 32  # TileMap cell size
var is_moving = false
var space_press_count = 0  # Accumulated spacebar presses (max 10)
var available_moves = 0
var target_position = Vector2.ZERO  # Destination position for movement
var coins = 0
var coin_threshold = 5  # Number of coins needed to unlock locked tile

func _ready():
	# Initialize UI
	space_bar_progress.max_value = 10
	space_bar_progress.value = 0
	move_counter.text = "Moves: 0"
	inventory_label.text = "Coins: " + str(coins)
	
	# Snap player to the center of the current tile:
	#var snapped_tile = tile_map.local_to_map(global_position)
	#global_position = tile_map.map_to_local(snapped_tile) + Vector2(tile_size / 2, tile_size / 2)
	#print("Starting Position (Tile Snapped):", global_position)
	
	# Connect timers
	decay_timer.timeout.connect(_decrease_space_bar_progress)
	no_input_timer.timeout.connect(_start_decay_timer)

func _process(_delta):
	if is_moving:
		return

	# Immediately add one move when "X" is pressed
	if Input.is_action_just_pressed("add_move"):
		available_moves += 1
		move_counter.text = "Moves: " + str(available_moves)
	
	# Spacebar press logic for banking moves
	if Input.is_action_just_pressed("ui_accept"):
		space_press_count += 1
		space_bar_progress.value = space_press_count
		
		if space_press_count >= 10:
			available_moves += 1
			move_counter.text = "Moves: " + str(available_moves)
			space_press_count = 0
			space_bar_progress.value = 0
		
		no_input_timer.stop()
		no_input_timer.start()
		decay_timer.stop()
	
	# Process movement input (W, S, A, D) if moves are available
	if available_moves > 0:
		if Input.is_action_just_pressed("up"):
			move(Vector2.UP)
		elif Input.is_action_just_pressed("down"):
			move(Vector2.DOWN)
		elif Input.is_action_just_pressed("left"):
			move(Vector2.LEFT)
		elif Input.is_action_just_pressed("right"):
			move(Vector2.RIGHT)

func _start_decay_timer():
	decay_timer.start()

func _decrease_space_bar_progress():
	if space_bar_progress.value > 0:
		space_press_count = max(space_press_count - 1, 0)
		space_bar_progress.value = space_press_count
	else:
		decay_timer.stop()

func move(direction: Vector2):
	if is_moving or available_moves <= 0:
		return  # Prevent movement if already moving or no moves available
	
	# Use RayCast2D to check for obstacles:
	ray.target_position = direction * tile_size
	ray.force_raycast_update()
	if ray.is_colliding():
		print("❌ BLOCKED: Collision detected with", ray.get_collider())
		return
	
	available_moves -= 1
	move_counter.text = "Moves: " + str(available_moves)
	
	var current_tile = tile_map.local_to_map(global_position - Vector2(tile_size / 2, tile_size / 2))
	var target_tile = current_tile + Vector2i(direction.x, direction.y)
	
	is_moving = true
	target_position = tile_map.map_to_local(target_tile) + Vector2(tile_size / 2, tile_size / 2)
	print("Moving to Tile:", target_tile, "-> New Position:", target_position)
	
	# Random battle chance: 5% (1 in 20 chance)
	if randi() % 20 == 0:
		start_battle()

func _physics_process(delta):
	if is_moving:
		global_position = global_position.move_toward(target_position, 100 * delta)
		if global_position.distance_to(target_position) < 1:
			global_position = target_position
			is_moving = false

func add_coin():
	coins += 1
	inventory_label.text = "Coins: " + str(coins)
	print("Coin added. Total coins:", coins)
	if coins >= coin_threshold:
		unlock_tile()

func unlock_tile():
	# Change the tile at a specific cell (e.g., a blocked door) to an unlocked tile.
	var door_cell = Vector2i(5, 3)  # Adjust this to your desired cell
	var unlocked_tile_index = 7     # Replace with the tile index for the unlocked door
	tile_map.set_cell(0, door_cell, unlocked_tile_index)
	print("Tile at", door_cell, "has been unlocked!")

func start_battle():
	print("A battle has started!")
