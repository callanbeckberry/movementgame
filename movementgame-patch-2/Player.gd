extends Area2D

# Node references 
@onready var tile_map = $"../TileMap"
@onready var space_bar_progress = $"../CanvasLayer/UI/SpaceBarProgress"
@onready var move_counter = $"../CanvasLayer/UI/MoveCounter"
@onready var decay_timer = $"../CanvasLayer/Timers/SpaceBarDecayTimer"
@onready var no_input_timer = $"../CanvasLayer/Timers/NoInputTimer"
@onready var ray = $RayCast2D
@onready var inventory_label = $"../CanvasLayer/UI/InventoryLabel"  # For displaying coin count
@onready var battle_scene = $"../BattleScene"  # Reference to the battle scene

var tile_size = 32  # TileMap cell size
var is_moving = false
var space_press_count = 0  # Accumulated spacebar presses (max 10)
var available_moves = 0
var target_position = Vector2.ZERO  # Destination position for movement
var coins = 0
var coin_threshold = 5  # Number of coins needed to unlock locked tile

# New variables for key/door system
var has_key = false
var key_instance = null
var previous_position = Vector2.ZERO  # Store the previous position for key following

# Battle system variables
var in_battle = false
var can_start_battle = true

func _ready():
	add_to_group("player")
	
	# Initialize UI
	space_bar_progress.max_value = 10
	space_bar_progress.value = 0
	move_counter.text = "Moves: 0"
	inventory_label.text = "Coins: " + str(coins)
	
	# Connect timers
	decay_timer.timeout.connect(_decrease_space_bar_progress)
	no_input_timer.timeout.connect(_start_decay_timer)
	
	# Store initial position
	previous_position = global_position
	
	# Set up battle scene
	if battle_scene:
		battle_scene.visible = false
		if not battle_scene.is_connected("battle_ended", _on_battle_ended):
			battle_scene.connect("battle_ended", _on_battle_ended)
	else:
		print("WARNING: BattleScene not found! Make sure it's added to the scene.")

func get_current_tile():
	return tile_map.local_to_map(global_position - Vector2(tile_size / 2, tile_size / 2))

func _process(_delta):
	if is_moving or in_battle:
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
	if is_moving or available_moves <= 0 or in_battle:
		return  # Prevent movement if already moving, no moves available, or in battle
	
	# Store the current position before moving
	previous_position = global_position
	
	# Use RayCast2D to check for obstacles:
	ray.target_position = direction * tile_size
	ray.force_raycast_update()
	if ray.is_colliding():
		var collider = ray.get_collider()
		print("❌ BLOCKED: Collision detected with", collider)
		
		# Check if it's a locked door and we have a key
		if collider.is_in_group("door") and has_key:
			check_unlock_door(collider)
		
		return
	
	available_moves -= 1
	move_counter.text = "Moves: " + str(available_moves)
	
	var current_tile = tile_map.local_to_map(global_position - Vector2(tile_size / 2, tile_size / 2))
	var target_tile = current_tile + Vector2i(direction.x, direction.y)
	
	is_moving = true
	target_position = tile_map.map_to_local(target_tile) + Vector2(tile_size / 2, tile_size / 2)
	print("Moving to Tile:", target_tile, "-> New Position:", target_position)
	
	# Random battle chance: 5% (1 in 20 chance)
	if can_start_battle and randi() % 20 == 0:
		# Set a flag to start the battle after movement is complete
		# This ensures the player is properly positioned first
		await get_tree().create_timer(0.1).timeout
		start_battle()

func _physics_process(delta):
	if is_moving and not in_battle:
		global_position = global_position.move_toward(target_position, 100 * delta)
		
		if global_position.distance_to(target_position) < 1:
			global_position = target_position
			is_moving = false
			
			# Update the key's position after player movement completes
			if has_key and key_instance != null and key_instance.following_player:
				key_instance.update_position(previous_position)
			
			# Check for nearby doors after movement
			check_nearby_doors()

func check_nearby_doors():
	if has_key and key_instance != null:
		# Get all doors in the scene
		var doors = get_tree().get_nodes_in_group("door")
		for door in doors:
			# Check if player is next to the door
			var player_tile = get_current_tile()
			var door_tile = door.tile_position
			
			# Check if adjacent (not diagonal)
			if (abs(player_tile.x - door_tile.x) == 1 and player_tile.y == door_tile.y) or \
			   (abs(player_tile.y - door_tile.y) == 1 and player_tile.x == door_tile.x):
				check_unlock_door(door)

func check_unlock_door(door):
	print("Checking door unlock...")
	print("Player has key: ", has_key)
	print("Key instance exists: ", key_instance != null)
	
	if has_key and key_instance != null:
		print("Checking if key is near door...")
		var is_near = key_instance.is_near_door(door.global_position)
		print("Key is near door: ", is_near)
		
		if is_near:
			print("Key and player are near door - unlocking!")
			door.unlock()
			key_instance.consume()
			has_key = false
		else:
			print("Key is not close enough to the door")

func pickup_key():
	print("Key picked up!")
	has_key = true

func spawn_and_attach_key():
	var key_scene = load("res://key.tscn")  # Make sure to create this scene
	key_instance = key_scene.instantiate()
	get_parent().add_child(key_instance)
	key_instance.start_following(self)
	has_key = true

func add_coin():
	coins += 1
	inventory_label.text = "Coins: " + str(coins)
	print("Coin added. Total coins:", coins)
	if coins >= coin_threshold:
		unlock_tile()

func unlock_tile():
	var door_cell = Vector2i(5, 3)  # Adjust this to your desired cell.
	var unlocked_tile_index = 7     # Replace with your actual unlocked tile index.
	tile_map.set_cell(0, door_cell, unlocked_tile_index)
	print("Tile at", door_cell, "has been unlocked!")

# BATTLE SYSTEM CODE

func start_battle():
	print("A battle has started!")
	in_battle = true
	
	# Store current game state if needed
	# (game progress, player position, etc)
	
	# Show and start the battle scene
	if battle_scene:
		battle_scene.visible = true
		battle_scene.start_battle()
		
		# Disable player movement during battle
		set_process(false)
		set_physics_process(false)
	else:
		print("ERROR: Battle scene not found!")
		in_battle = false

func _on_battle_ended():
	print("Battle ended, returning to main game")
	
	# Resume normal game processing
	set_process(true)
	set_physics_process(true)
	
	# Hide battle scene
	if battle_scene:
		battle_scene.visible = false
	
	# Reset battle state
	in_battle = false
	
	# Prevent immediate battle starting again
	can_start_battle = false
	get_tree().create_timer(2.0).timeout.connect(_enable_battles)

# Function to enable battles again after cooldown
func _enable_battles():
	can_start_battle = true
