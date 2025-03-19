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
@onready var main_ui = $"../CanvasLayer/UI"  # Reference to main UI
@onready var main_camera = $"../Camera2D"  # Reference to main camera
@onready var global_ui_manager = get_node("/root/GlobalUIManager")  # Reference to GlobalUIManager autoload

signal battle_started
signal battle_ended

var tile_size = 32  # TileMap cell size
var is_moving = false
var space_press_count = 0  # Accumulated spacebar presses (max 10)
var available_moves = 0
var target_position = Vector2.ZERO  # Destination position for movement
var can_move = true  # Flag to control movement (for dialogue system)

# Coin system
var coins = 0           # Current collected coins
var total_coins = 120   # Total coins in the game (will be updated by RoomManager)
var coins_per_room = 10 # Coins per room (will be updated by RoomManager)
var coin_threshold = 5  # Number of coins needed to unlock locked tile

# New variables for key/door system
var has_key = false
var key_instance = null
var previous_position = Vector2.ZERO  # Store the previous position for key following

# Battle system variables
var in_battle = false
var can_start_battle = true
var moves_since_battle = 0
var safe_moves_remaining = 0
var base_battle_chance = 0.05  # 5% chance (1 in 20)
var increased_battle_chance = 0.15  # +15% chance (becomes 20% total)

# NPC interaction related variables
var current_npc = null
var in_dialogue = false
var last_npc_check_position = Vector2.ZERO
var dialogue_cooldown = false # Add cooldown to prevent rapid dialogue triggering

func _ready():
	add_to_group("player")
	
	# Initialize UI
	space_bar_progress.max_value = 10
	space_bar_progress.value = 0
	move_counter.text = "Moves: 0"
	update_coin_display()
	
	# Connect timers
	decay_timer.timeout.connect(_decrease_space_bar_progress)
	no_input_timer.timeout.connect(_start_decay_timer)
	
	# Store initial position
	previous_position = global_position
	last_npc_check_position = global_position
	
	# Add main camera to cameras group
	if main_camera:
		main_camera.add_to_group("cameras")
	
	# Connect battle ended signal
	if battle_scene and not battle_scene.is_connected("battle_ended", _on_battle_ended):
		battle_scene.connect("battle_ended", _on_battle_ended)
	
	# Start the global UI if it doesn't exist
	if global_ui_manager:
		global_ui_manager.start_game()
		
	# Setup dialogue manager if it doesn't exist
	setup_dialogue_manager()

# Setup the dialogue manager if it doesn't exist yet
func setup_dialogue_manager():
	# Skip if already exists
	if get_node_or_null("../CanvasLayer/DialogueManager") or get_node_or_null("/root/DialogueManager"):
		return
		
	# Find or create CanvasLayer
	var canvas_layer = get_node_or_null("../CanvasLayer")
	if canvas_layer:
		# Create DialogueManager scene
		var dialogue_manager_scene = load("res://dialogue_manager.tscn")
		if dialogue_manager_scene:
			var dialogue_manager = dialogue_manager_scene.instantiate()
			dialogue_manager.add_to_group("dialogue_manager")
			canvas_layer.add_child(dialogue_manager)
			print("Dialogue Manager added to scene")
		else:
			print("ERROR: Could not load dialogue_manager.tscn")

func get_current_tile():
	return tile_map.local_to_map(global_position - Vector2(tile_size / 2, tile_size / 2))

func _process(_delta):
	if is_moving or in_battle or in_dialogue or not can_move:
		return

	# Immediately add one move when "X" is pressed
	# Only if we're not in battle
	if Input.is_action_just_pressed("add_move") and not in_battle:
		available_moves += 1
		move_counter.text = "Moves: " + str(available_moves)
		
		# Update the yen counter in GlobalUIManager
		if global_ui_manager:
			global_ui_manager.add_yen(27)
	
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
	if is_moving or available_moves <= 0 or in_battle or in_dialogue or not can_move:
		return
	
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
		# Check if it's a final boss door and all coins are collected
		elif collider.is_in_group("final_boss_door") and coins >= total_coins:
			print("Final boss door unlocked with all coins!")
			collider.unlock()
		# If it's a final boss door but not enough coins
		elif collider.is_in_group("final_boss_door"):
			print("Need to collect all coins to unlock the final boss door! Current: ", coins, "/", total_coins)
		
		return
	
	available_moves -= 1
	move_counter.text = "Moves: " + str(available_moves)
	
	var current_tile = tile_map.local_to_map(global_position - Vector2(tile_size / 2, tile_size / 2))
	var target_tile = current_tile + Vector2i(direction.x, direction.y)
	
	is_moving = true
	target_position = tile_map.map_to_local(target_tile) + Vector2(tile_size / 2, tile_size / 2)
	print("Moving to Tile:", target_tile, "-> New Position:", target_position)
	
	# Track moves for battle chance
	moves_since_battle += 1
	
	# Random battle chance logic
	if can_start_battle and safe_moves_remaining <= 0:
		var battle_roll = randf()
		var current_chance = base_battle_chance
		
		# Increase chance after 10 moves
		if moves_since_battle > 10:
			current_chance = base_battle_chance + increased_battle_chance
			
		# Print debug info about battle chance
		print("Battle chance: ", current_chance * 100, "%, Roll: ", battle_roll)
		
		if battle_roll < current_chance:
			# Set a flag to start the battle after movement is complete
			await get_tree().create_timer(0.1).timeout
			start_battle()
	else:
		if safe_moves_remaining > 0:
			safe_moves_remaining -= 1
			print("Safe moves remaining: ", safe_moves_remaining)

func _physics_process(delta):
	if is_moving and not in_battle and not in_dialogue:
		global_position = global_position.move_toward(target_position, 100 * delta)
		
		if global_position.distance_to(target_position) < 1:
			global_position = target_position
			is_moving = false
			
			# Update the key's position after player movement completes
			if has_key and key_instance != null and key_instance.following_player:
				key_instance.update_position(previous_position)
			
			# Check for nearby doors after movement
			check_nearby_doors()
			
			# Check for nearby NPCs after movement
			check_nearby_npcs()

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

# New function to check for NPCs within 1 grid square and trigger dialogue
func check_nearby_npcs():
	# Only check if we've actually moved to a new position
	if global_position.distance_to(last_npc_check_position) < 1:
		return
		
	last_npc_check_position = global_position
	
	# Skip if we're already in dialogue or in cooldown period
	if in_dialogue or dialogue_cooldown:
		return
		
	var player_tile = get_current_tile()
	var npcs = get_tree().get_nodes_in_group("npcs")
	
	for npc in npcs:
		# Get NPC's tile position
		var npc_pos = npc.global_position
		var npc_tile = tile_map.local_to_map(npc_pos - Vector2(tile_size / 2, tile_size / 2))
		
		# Check if adjacent (including diagonals)
		var dx = abs(player_tile.x - npc_tile.x)
		var dy = abs(player_tile.y - npc_tile.y)
		
		# If within 1 tile (manhattan distance)
		if dx <= 1 and dy <= 1:
			# Found an NPC within range, trigger dialogue
			current_npc = npc
			trigger_npc_dialogue(npc)
			break

func trigger_npc_dialogue(npc):
	if dialogue_cooldown:
		return
		
	dialogue_cooldown = true
	in_dialogue = true
	can_move = false
	
	# Find dialogue manager using improved search
	var dialogue_manager = find_dialogue_manager()
	
	if dialogue_manager and npc.has_method("show_dialogue"):
		npc.show_dialogue()
	elif npc.dialogues.size() > 0:
		# Fallback if dialogue manager not found
		var random_dialogue = npc.dialogues[randi() % npc.dialogues.size()]
		print("[NPC " + npc.npc_name + "]: " + random_dialogue)
		await get_tree().create_timer(2.0).timeout
		end_dialogue()
	
	# Reset cooldown after a short delay
	await get_tree().create_timer(2.0).timeout
	dialogue_cooldown = false

# Improved function to find dialogue manager
func find_dialogue_manager():
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		return dm
		
	dm = get_node_or_null("../CanvasLayer/DialogueManager")
	if dm:
		return dm
		
	# Try to find using group
	var potential_managers = get_tree().get_nodes_in_group("dialogue_manager")
	if potential_managers.size() > 0:
		return potential_managers[0]
		
	return null

func end_dialogue():
	in_dialogue = false
	can_move = true
	current_npc = null

func check_unlock_door(door):
	if has_key and key_instance != null:
		var is_near = key_instance.is_near_door(door.global_position)
		
		if is_near:
			print("Key and player are near door - unlocking!")
			door.unlock()
			key_instance.consume()
			has_key = false

func pickup_key():
	print("Key picked up!")
	has_key = true

func spawn_and_attach_key():
	var key_scene = load("res://key.tscn")  # Make sure to create this scene
	key_instance = key_scene.instantiate()
	get_parent().add_child(key_instance)
	key_instance.start_following(self)
	has_key = true

# Function to enable/disable player movement (used by DialogueManager)
func set_can_move(value):
	can_move = value
	
	# If we can move again, we're not in dialogue
	if value == true:
		in_dialogue = false

# COIN SYSTEM

func add_coin():
	coins += 1
	print("Coin added. Total coins:", coins, "/", total_coins)
	update_coin_display()
	
	# Check if all coins are collected
	if coins >= total_coins:
		unlock_final_boss()
	
	# Play coin collection sound
	# $CoinSound.play()

func update_coin_display():
	inventory_label.text = "Coins: " + str(coins) + "/" + str(total_coins)

func unlock_final_boss():
	print("All coins collected! Final boss door unlocked!")
	
	# Find the final boss door and unlock it
	var final_doors = get_tree().get_nodes_in_group("final_boss_door")
	for door in final_doors:
		door.unlock()
	
	# Maybe display a special message or play a sound
	var popup_label = Label.new()
	popup_label.text = "All Coins Collected! Final door unlocked!"
	popup_label.position = Vector2(512, 300)  # Center of screen
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.add_theme_font_size_override("font_size", 24)
	get_node("../CanvasLayer").add_child(popup_label)
	
	# Remove the message after 3 seconds
	var t = get_tree().create_timer(3.0)
	t.timeout.connect(func(): popup_label.queue_free())

# BATTLE SYSTEM CODE

func start_battle():
	print("A battle has started!")
	in_battle = true
	
	emit_signal("battle_started")
	
	# Hide main UI
	if main_ui:
		main_ui.visible = false
	
	# Hide key if it's following the player
	if has_key and key_instance != null:
		key_instance.visible = false
	
	var ui_background = get_node_or_null("../CanvasLayer/UIBackground")
	if ui_background:
		ui_background.visible = false
	
	# Hide the wizard turtle
	var wizard_turtle = get_node_or_null("../CanvasLayer/WizardTurtleUI")
	if wizard_turtle:
		wizard_turtle.hide_wizard_turtle()
	
	# Hide all collectibles (coins, etc.)
	for collectible in get_tree().get_nodes_in_group("collectibles"):
		collectible.visible = false
	
	# Hide all NPCs
	for npc in get_tree().get_nodes_in_group("npcs"):
		npc.visible = false
	
	# Disable main camera if it exists
	if main_camera:
		main_camera.enabled = false
	
	# Ensure GlobalUI remains visible during battle
	if global_ui_manager:
		global_ui_manager.ensure_global_ui_exists()
	
	# Show and start the battle scene with transition
	if battle_scene:
		battle_scene.visible = true
		battle_scene.start_battle_with_transition()
		
		# Disable player movement during battle
		set_process(false)
		set_physics_process(false)
	else:
		print("ERROR: Battle scene not found!")
		in_battle = false

func _on_battle_ended():
	
	print("Battle ended, returning to main game")
	
	emit_signal("battle_ended")
	
	# Resume normal game processing
	set_process(true)
	set_physics_process(true)
	
	# Show main UI again
	if main_ui:
		main_ui.visible = true
	
	var ui_background = get_node_or_null("../CanvasLayer/UIBackground")
	if ui_background:
		ui_background.visible = true
	
	var wizard_turtle = get_node_or_null("../CanvasLayer/WizardTurtleUI")
	if wizard_turtle:
		wizard_turtle.show_wizard_turtle()
	
	# After battle ends and when returning to the main game scene
	if wizard_turtle:
		wizard_turtle.battle_ended()
	
	# Show key again if the player has one
	if has_key and key_instance != null:
		key_instance.visible = true
	
	# Show all collectibles again
	for collectible in get_tree().get_nodes_in_group("collectibles"):
		collectible.visible = true
	
	# Show all NPCs again
	for npc in get_tree().get_nodes_in_group("npcs"):
		npc.visible = true
	
	# Re-enable main camera if it exists
	if main_camera:
		main_camera.enabled = true
	
	# Reset battle state
	in_battle = false
	
	# Reset battle tracking
	moves_since_battle = 0
	safe_moves_remaining = 5
	
	# Prevent immediate battle starting again
	can_start_battle = false
	get_tree().create_timer(2.0).timeout.connect(_enable_battles)

# Function to enable battles again after cooldown
func _enable_battles():
	can_start_battle = true
