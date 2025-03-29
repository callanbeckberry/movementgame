extends Node2D

# References to nodes (assumes these are set up in the editor)
@onready var player_sprite = $PlayerSprite
@onready var enemy_sprite = $EnemySprite
@onready var player_attack_bar = $UI/AttackBar
@onready var direction_prompt = $UI/DirectionPrompt
@onready var attack_menu = $UI/AttackMenu
@onready var transition_rect = $TransitionRect  # Add this manually in editor
@onready var camera = $Camera2D  # Add this manually in editor
@onready var attack_timer = $Timers/EnemyAttackTimer
@onready var global_ui_manager = get_node("/root/GlobalUIManager")  # Reference to GlobalUIManager autoload
@onready var speed_up_label = $UI/SpeedUpLabel 

# Preload the speech bubble scene
const SpeechBubbleScene = preload("res://SpeechBubble.tscn")

signal battle_started 

# Speech bubble instances - we'll create them in _ready()
var enemy_speech_bubble = null
var player_speech_bubble = null
 
# Game state
var in_battle = false
var direction_inputs_correct = 0
var current_prompt_direction = ""
var attack_charging = false
var attack_menu_open = false
var selected_attack_index = 0
var enemy_health = 1
var speed_up_counter = 0
var max_speed_up = 4
var current_boss = null  # Reference to boss NPC if this is a boss battle
var is_boss_battle = false  # Flag to indicate if this is a boss battle

# Transition effect variables
var transition_duration = 1.5  # Duration of transition
var transition_blocks = []  # Array to store transition block references

var is_final_boss = false

# Arrays for speech bubbles
var enemy_attack_names = [
	"Menacing Glare",
	"Intimidating Growl",
	"Mighty Roar",
	"Fierce Scratch",
	"Scary Face",
	"Tail Whip",
	"Fearsome Bite",
	"Evil Eye",
	"Spooky Dance",
	"Mysterious Chant"
]

var enemy_defeat_messages = [
	"Ouchie that hurt!",
	"I'll be back!",
	"You'll regret this!",
	"This isn't over!",
	"Nooooooo!",
	"How could you?!",
	"I was just kidding!",
	"My power failed me!",
	"Impossible!",
	"This is embarrassing..."
]

# Boss-specific messages
var boss_attack_names = [
	"Ultimate Destruction",
	"Dark Energy Blast",
	"Soul Drain",
	"Shadow Strike",
	"Void Crusher"
]

var boss_defeat_messages = [
	"This cannot be! I am... invincible...",
	"My power... how could a mere mortal...",
	"I shall return stronger than ever!",
	"Remember this day... for it marks the beginning of your doom...",
	"The darkness... it calls to me..."
]

# Player attack names
var player_attacks = [
	"Heroic Punch",
	"Valiant Slash",
	"Righteous Beam",
	"Courageous Strike",
	"Legendary Smash"
]

# Direction mapping
var directions = ["battleup", "battledown", "battleleft", "battleright"]

# Signal for when battle ends
signal battle_ended
signal final_boss_defeated 

func _ready():
	# Add to battle_scene group for easy finding
	add_to_group("battle_scene")
	

	# Initially hide battle elements
	visible = false
	
	# Make sure attack menu is not visible and reset menu state
	attack_menu.visible = false
	attack_menu_open = false
	attack_charging = false
	selected_attack_index = 0
	
	# Add camera to a group for global control
	if camera:
		camera.add_to_group("cameras")
		camera.enabled = false
	
	# Initialize the attack bar
	player_attack_bar.max_value = 20
	player_attack_bar.value = 0
	
	# Connect timers
	attack_timer.timeout.connect(_on_enemy_attack_timer_timeout)
	
	# Create debug sprites if needed
	create_debug_sprites()
	
	# Setup speech bubbles
	setup_speech_bubbles()
	
	# Hide direction prompt initially
	direction_prompt.visible = false
	
	# Ensure GlobalUI exists and persists through battle
	if global_ui_manager:
		global_ui_manager.ensure_global_ui_exists()

func setup_speech_bubbles():
	# Create enemy speech bubble
	enemy_speech_bubble = SpeechBubbleScene.instantiate()
	add_child(enemy_speech_bubble)
	
	# Configure it
	enemy_speech_bubble.set_target(enemy_sprite, Vector2(0, -50))
	enemy_speech_bubble.set_colors(Color(1, 0.8, 0.8), Color(0, 0, 0))  # Light red bubble
	
	# Create player speech bubble
	player_speech_bubble = SpeechBubbleScene.instantiate()
	add_child(player_speech_bubble)
	
	# Configure it
	player_speech_bubble.set_target(player_sprite, Vector2(0, -70))
	player_speech_bubble.set_colors(Color(0.8, 0.9, 1.0), Color(0, 0, 0))  # Light blue bubble

# Start a boss battle with the given boss NPC
func start_boss_battle(boss_npc = null):
	
	emit_signal("battle_started")
	
	# Optionally set z_index for all children
	for child in get_children():
		if child is CanvasItem:
			child.z_index = 1000
			
	print("Starting BOSS battle!")
	
	# Store reference to boss and set flag
	current_boss = boss_npc
	is_final_boss = boss_npc.is_final_boss if boss_npc else false
	is_boss_battle = true
	
	# Use special battle settings
	enemy_health = 1  # Make boss harder
	
	# Maybe use a different enemy sprite
	if boss_npc and enemy_sprite:
		# If boss has a portrait, use it for battle
		if boss_npc.portrait_texture:
			enemy_sprite.texture = boss_npc.portrait_texture
			print("Using boss portrait as battle sprite")
	
	# If boss speech bubble exists, make it more intimidating
	if enemy_speech_bubble:
		enemy_speech_bubble.set_colors(Color(0.5, 0.1, 0.1, 0.9), Color(1, 0.8, 0.8))  # Dark red with light text
	
	# Start with special intro
	show_enemy_speech("So, you dare to challenge me?")
	
	# Ensure battle scene is rendered on top
	z_index = 100  # Set a high z-index to ensure it renders above other elements
	
	# Ensure all battle UI elements are on top
	for child in get_children():
		if child is CanvasItem:
			child.z_index = 100
	
	# Continue with normal battle start
	start_battle_with_transition()

func start_battle_with_transition():
	# Make scene visible but prepare for transition
	visible = true
	
	# Reset battle menu state
	attack_menu.visible = false
	attack_menu_open = false
	attack_charging = false
	direction_inputs_correct = 0
	player_attack_bar.value = 0
	
	# Hide all NPCs
	for npc in get_tree().get_nodes_in_group("npcs"):
		npc.visible = false
	
	# Ensure GlobalUI stays visible
	if global_ui_manager:
		global_ui_manager.ensure_global_ui_exists()
	
	# Set camera to a consistent position
	camera.position = Vector2.ZERO  
	camera.global_position = Vector2.ZERO
	camera.offset = Vector2.ZERO
	
	# Make sure it has no limits
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	
	# Enable camera with correct settings
	camera.enabled = true
	camera.make_current()
	
	# Force camera update to take effect immediately
	camera.force_update_scroll()
	
	# Debug output for camera
	print("Battle camera position: ", camera.global_position)
	print("Battle camera offset: ", camera.offset)
	print("Battle camera enabled: ", camera.enabled)
	
	# Start the digital transition
	_start_digital_transition_in()

func start_battle():
	print("Battle started!")
	in_battle = true
	
	# Reset battle state
	if not is_boss_battle:
		enemy_health = 1
	# Boss health is set in start_boss_battle
	
	direction_inputs_correct = 0
	player_attack_bar.value = 0
	attack_charging = true
	attack_menu_open = false
	selected_attack_index = 0
	
	if speed_up_label:
		speed_up_label.text = "Speed up the battle: 0/100 yen added"
	
	# Show direction prompt
	direction_prompt.visible = true
	attack_menu.visible = false
	
	# Set a random initial prompt
	_set_new_direction_prompt()
	
	# Start enemy attack timer (random between 5-20 seconds)
	_start_random_enemy_attack_timer()

func _process(_delta):
	if not in_battle:
		return
		
	# First, handle "X" key presses for speeding up battle
	if Input.is_action_just_pressed("add_move"):  # This is your "X" key
		speed_up_counter += 1
		var yen_added = speed_up_counter * 25
		
		# Update the speed up label
		if speed_up_label:
			speed_up_label.text = "Speed up the battle: " + str(yen_added) + "/100 yen added"
		
		# If we've reached the threshold, open the attack menu
		if speed_up_counter >= max_speed_up:
			# Add yen to global UI manager
			if global_ui_manager:
				global_ui_manager.add_yen(100)  # Add 100 yen to the global counter
			
			# Skip to attack menu
			_open_attack_menu()
			
			# Reset counter
			speed_up_counter = 0
			if speed_up_label:
				speed_up_label.text = "Speed up the battle: 0/100 yen added"
		
		return  # Process no further input for this frame
	
	if attack_charging and not attack_menu_open:
		# Check for direction inputs
		if Input.is_action_just_pressed("battleup"):
			_check_direction_input("battleup")
		elif Input.is_action_just_pressed("battledown"):
			_check_direction_input("battledown")
		elif Input.is_action_just_pressed("battleleft"):
			_check_direction_input("battleleft")
		elif Input.is_action_just_pressed("battleright"):
			_check_direction_input("battleright")
	elif attack_menu_open:
		# Handle menu navigation
		if Input.is_action_just_pressed("up"):
			selected_attack_index = max(0, selected_attack_index - 1)
			_update_selected_attack()
		elif Input.is_action_just_pressed("down"):
			selected_attack_index = min(4, selected_attack_index + 1)
			_update_selected_attack()
		elif Input.is_action_just_pressed("ui_accept"):
			_execute_player_attack(selected_attack_index)

func _check_direction_input(input_direction):
	if input_direction == current_prompt_direction:
		# Correct input - animate prompt
		_animate_prompt_success()
		
		# Correct input
		direction_inputs_correct += 1
		player_attack_bar.value = direction_inputs_correct
		
		# Check if attack bar is full
		if direction_inputs_correct >= 20:
			_open_attack_menu()
		else:
			# Set new direction prompt after animation
			await get_tree().create_timer(0.3).timeout
			_set_new_direction_prompt()
	else:
		# Wrong input - animate error
		_animate_prompt_error()
		
		# Wrong input, reset progress
		direction_inputs_correct = 0
		player_attack_bar.value = 0
		
		# Set new direction prompt after animation
		await get_tree().create_timer(0.5).timeout
		_set_new_direction_prompt()

func _animate_prompt_success():
	var original_pos = direction_prompt.position
	var tween = create_tween()
	tween.tween_property(direction_prompt, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(direction_prompt, "scale", Vector2(1.0, 1.0), 0.1)
	# Optional: Change text color to green temporarily
	direction_prompt.add_theme_color_override("font_color", Color(0, 1, 0))
	await get_tree().create_timer(0.2).timeout
	direction_prompt.remove_theme_color_override("font_color")

func _animate_prompt_error():
	var original_pos = direction_prompt.position
	var tween = create_tween()
	
	# Shake effect
	for i in range(5):
		var offset = 5
		tween.tween_property(direction_prompt, "position:x", original_pos.x - offset, 0.05)
		tween.tween_property(direction_prompt, "position:x", original_pos.x + offset, 0.05)
	
	tween.tween_property(direction_prompt, "position:x", original_pos.x, 0.05)
	
	# Red color flash
	direction_prompt.add_theme_color_override("font_color", Color(1, 0, 0))
	await get_tree().create_timer(0.4).timeout
	direction_prompt.remove_theme_color_override("font_color")

func _set_new_direction_prompt():
	# Choose a random direction
	current_prompt_direction = directions[randi() % directions.size()]
	
	# Update the direction prompt UI with a more descriptive name
	var display_name = current_prompt_direction.substr(6).capitalize()  # Remove 'battle' prefix
	direction_prompt.text = "Press " + display_name
	
	# Reset scale/position in case it was changed by animations
	direction_prompt.scale = Vector2(1, 1)
	direction_prompt.remove_theme_color_override("font_color")

func _open_attack_menu():
	attack_charging = false
	attack_menu_open = true
	
	# Hide direction prompt, show attack menu
	direction_prompt.visible = false
	
	# Clear any existing buttons
	for child in attack_menu.get_children():
		if child.name != "MenuLabel":  # Keep the label
			child.queue_free()
	
	# Create attack buttons vertically using a different approach
	for i in range(5):
		var button = Button.new()
		button.text = player_attacks[i]
		button.name = "AttackButton" + str(i+1)
		
		# Set custom style for easy highlighting
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.2, 0.4, 0.5, 1.0)  # Dark teal
		normal_style.set_corner_radius_all(4)
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.25, 0.45, 0.55, 1.0)  # Slightly lighter
		hover_style.set_corner_radius_all(4)
		
		var selected_style = StyleBoxFlat.new()
		selected_style.bg_color = Color(0.3, 0.6, 0.8, 1.0)  # Highlight blue
		selected_style.set_corner_radius_all(4)
		
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
		
		# Add to menu
		attack_menu.add_child(button)
		
		# Connect button press to attack function using an intermediate variable
		var attack_idx = i  # Store index in a variable to avoid lambda capture issues
		button.pressed.connect(func(): _execute_player_attack(attack_idx))
	
	# Force a full rebuild of the menu to ensure nodes are updated
	attack_menu.visible = true
	
	# Initialize selection after a short delay to ensure buttons are added
	selected_attack_index = 0
	call_deferred("_apply_selection_after_delay")

func _apply_selection_after_delay():
	# Wait two frames to ensure UI has updated
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Now apply initial selection
	_update_selected_attack()
	print("Selection applied after delay - index:", selected_attack_index)

func _update_selected_attack():
	print("Updating selected attack to index:", selected_attack_index)
	
	# First reset all buttons
	for i in range(5):
		var button_name = "AttackButton" + str(i+1)
		var button = attack_menu.get_node_or_null(button_name)
		if button:
			# Get the default style
			var style = button.get_theme_stylebox("normal")
			if style is StyleBoxFlat:
				style.bg_color = Color(0.2, 0.4, 0.5, 1.0)  # Reset to normal color
			
			# Reset text color
			button.add_theme_color_override("font_color", Color(1, 1, 1))
	
	# Now highlight the selected button
	var selected_button_name = "AttackButton" + str(selected_attack_index + 1)
	var selected_button = attack_menu.get_node_or_null(selected_button_name)
	
	if selected_button:
		# Apply selection style
		var style = selected_button.get_theme_stylebox("normal")
		if style is StyleBoxFlat:
			style.bg_color = Color(0.3, 0.6, 0.8, 1.0)  # Highlight blue
		
		# Make text yellow
		selected_button.add_theme_color_override("font_color", Color(1, 0.9, 0, 1))
		print("Highlighted button:", selected_button_name)
	else:
		print("ERROR: Button not found for highlighting:", selected_button_name)
		# Fall back to listing available buttons
		var children = attack_menu.get_children()
		print("Available buttons:", children.size())
		for child in children:
			print(" - ", child.name)

func _execute_player_attack(attack_index):
	print("Player preparing to use " + player_attacks[attack_index] + "!")
	
	# Show player speech bubble with attack name
	show_player_speech(player_attacks[attack_index])
	
	# Wait 1 second before performing the attack
	await get_tree().create_timer(1.0).timeout
	
	print("Player used " + player_attacks[attack_index] + "!")
	
	# Shake the player sprite
	var tween = create_tween()
	tween.tween_property(player_sprite, "position:x", player_sprite.position.x + 10, 0.1)
	tween.tween_property(player_sprite, "position:x", player_sprite.position.x, 0.1)
	
	# Wait a bit before showing enemy reaction
	await get_tree().create_timer(0.5).timeout
	
	# Damage enemy
	if is_boss_battle:
		enemy_health -= 1
		
		# Check if boss is defeated
		if enemy_health <= 0:
			# Boss defeated
			_handle_boss_defeat()
		else:
			# Boss took damage but still alive
			show_enemy_speech("You're stronger than I thought... but not strong enough!")
			
			# Continue battle
			attack_menu_open = false
			attack_charging = true
			direction_inputs_correct = 0
			player_attack_bar.value = 0
			
			# Show direction prompt again
			direction_prompt.visible = true
			attack_menu.visible = false
			
			# Set a new prompt
			_set_new_direction_prompt()
	else:
		# Regular enemy - just defeat them
		enemy_health = 0
		
		# Shake enemy sprite
		tween = create_tween()
		tween.tween_property(enemy_sprite, "position:x", enemy_sprite.position.x - 10, 0.1)
		tween.tween_property(enemy_sprite, "position:x", enemy_sprite.position.x, 0.1)
		
		# Show defeat message
		show_enemy_speech(enemy_defeat_messages[randi() % enemy_defeat_messages.size()])
		
		# End battle after a short delay
		await get_tree().create_timer(2.0).timeout
		end_battle_with_transition()

func _handle_boss_defeat():
	# Show boss defeat message
	show_enemy_speech(boss_defeat_messages[randi() % boss_defeat_messages.size()])
	
	# Shake enemy sprite more dramatically
	var tween = create_tween()
	for i in range(3):
		tween.tween_property(enemy_sprite, "position:x", enemy_sprite.position.x - 15, 0.1)
		tween.tween_property(enemy_sprite, "position:x", enemy_sprite.position.x + 15, 0.1)
	tween.tween_property(enemy_sprite, "position:x", enemy_sprite.position.x, 0.1)
	
	# Wait for transition out to complete before emitting final boss defeated
	await get_tree().create_timer(2.0).timeout  # Adjust timing to match your fade-out duration
	
	# Check if this was the final boss - add extra debug prints
	print("Boss defeated! is_final_boss flag =", is_final_boss)
	
	if is_final_boss:
		print("FINAL BOSS DEFEATED! Emitting signal final_boss_defeated...")
		# Signal that the final boss was defeated
		emit_signal("final_boss_defeated")
	
	# End battle after a slightly longer delay
	await get_tree().create_timer(3.0).timeout
	end_battle_with_transition()
	
func _on_enemy_attack_timer_timeout():
	# Choose attack name based on whether this is a boss battle
	var attack_name
	if is_boss_battle:
		attack_name = boss_attack_names[randi() % boss_attack_names.size()]
	else:
		attack_name = enemy_attack_names[randi() % enemy_attack_names.size()]
	
	print("Enemy preparing to use " + attack_name + "!")
	
	# Show speech bubble with attack name first
	show_enemy_speech(attack_name)
	
	# Wait 1 second before performing the attack
	await get_tree().create_timer(1.0).timeout
	
	# Now perform the attack
	print("Enemy used " + attack_name + "!")
	
	# Shake the enemy sprite
	var tween = create_tween()
	tween.tween_property(enemy_sprite, "position:x", enemy_sprite.position.x - 5, 0.1)
	tween.tween_property(enemy_sprite, "position:x", enemy_sprite.position.x, 0.1)
	
	# Wait a bit before shaking player (as if attack landed)
	await get_tree().create_timer(0.5).timeout
	
	# Shake the player sprite
	tween = create_tween()
	tween.tween_property(player_sprite, "position:x", player_sprite.position.x + 5, 0.1)
	tween.tween_property(player_sprite, "position:x", player_sprite.position.x, 0.1)
	
	# Start the timer for next attack
	_start_random_enemy_attack_timer()

# Updated speech handling using the new SpeechBubble class
func show_enemy_speech(text_content):
	if enemy_speech_bubble:
		enemy_speech_bubble.show_message(text_content)

func show_player_speech(text_content):
	if player_speech_bubble:
		player_speech_bubble.show_message(text_content)

func _start_random_enemy_attack_timer():
	# Random time between 5-20 seconds for regular enemies
	# Shorter time (3-12 seconds) for boss battles
	var attack_delay
	if is_boss_battle:
		attack_delay = randf_range(3.0, 12.0)  # Boss attacks more frequently
	else:
		attack_delay = randf_range(5.0, 20.0)
		
	attack_timer.start(attack_delay)

func end_battle_with_transition():
	# Reset speed up counter
	speed_up_counter = 0
	if speed_up_label:
		speed_up_label.text = "Speed up the battle: 0/100 yen added"
	
	# Ensure GlobalUI remains visible before transition
	if global_ui_manager:
		global_ui_manager.ensure_global_ui_exists()
	
	# Hide any speech bubbles
	if enemy_speech_bubble:
		enemy_speech_bubble.hide_bubble()
	if player_speech_bubble:
		player_speech_bubble.hide_bubble()
	
	# Start the digital transition out
	_start_digital_transition_out()

func _end_battle():
	in_battle = false
	is_boss_battle = false
	current_boss = null
	
	# Reset battle UI state thoroughly
	attack_menu.visible = false
	direction_prompt.visible = false
	attack_menu_open = false
	attack_charging = false
	selected_attack_index = 0
	
	# Clear menu buttons
	for child in attack_menu.get_children():
		if child.name != "MenuLabel":
			child.queue_free()
	
	# Disable battle camera
	camera.enabled = false
	
	# Hide battle scene
	visible = false
	
	# Show all NPCs again
	for npc in get_tree().get_nodes_in_group("npcs"):
		npc.visible = true
		
	# Reset boss battle flag in player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.is_boss_battle = false
	
	# Signal to the main game that battle is over
	emit_signal("battle_ended")

# DIGITAL BLOCK TRANSITION EFFECT
# Creates a grid of colored blocks that fade in/out for a pixelated effect
func _start_digital_transition_in():
	print("Starting digital transition IN")
	
	# Start with black screen
	if transition_rect:
		transition_rect.visible = true
		transition_rect.material = null  # No shader
		transition_rect.color = Color(0, 0, 0, 1)
	
	# First fade to partially transparent
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.8, 0.4)
	await tween.finished
	
	# Get viewport size to position blocks across entire screen
	var viewport_size = get_viewport_rect().size
	
	# Create grid of digital blocks
	_create_digital_blocks(viewport_size, true)
	
	# Add a short delay
	await get_tree().create_timer(0.5).timeout
	
	# Final fade out to reveal battle scene
	tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.0, 0.5)
	tween.finished.connect(func(): start_battle())

# Creates digital blocks for the transition effect
func _create_digital_blocks(viewport_size, is_intro):
	# Clear any existing blocks
	for block in transition_blocks:
		if is_instance_valid(block):
			block.queue_free()
	transition_blocks.clear()
	
	# Settings
	var block_count = 50  # Number of blocks to create
	var max_size = 60.0   # Maximum block size
	var min_size = 10.0   # Minimum block size
	
	# Create random blocks
	for i in range(block_count):
		var block = ColorRect.new()
		add_child(block)
		transition_blocks.append(block)
		
		# Random position and size
		var size = randf_range(min_size, max_size)
		block.size = Vector2(size, size)
		block.position = Vector2(
			randf_range(0, viewport_size.x - size),
			randf_range(0, viewport_size.y - size)
		)
		
		# Different colors for intro vs outro
		if is_intro:
			block.color = Color(
				randf_range(0.2, 0.9),
				randf_range(0.2, 0.9),
				randf_range(0.2, 0.9),
				0.0  # Start transparent
			)
		else:
			block.color = Color(
				randf_range(0.0, 0.5),
				randf_range(0.0, 0.5),
				randf_range(0.0, 0.5),
				0.0  # Start transparent
			)
		
		# Animate blocks
		var block_tween = create_tween()
		
		if is_intro:
			# For intro, fade in then out
			block_tween.tween_property(block, "color:a", randf_range(0.5, 0.9), randf_range(0.1, 0.5))
			block_tween.tween_property(block, "color:a", 0.0, randf_range(0.2, 0.7))
		else:
			# For outro, just fade in and stay
			block_tween.tween_property(block, "color:a", randf_range(0.5, 0.9), randf_range(0.1, 0.5))
		
		# Queue free at the end of animation if intro
		if is_intro:
			block_tween.tween_callback(func(): _remove_block(block))

# Helper to remove a block and clean up the array
func _remove_block(block):
	if is_instance_valid(block):
		block.queue_free()
		
	var index = transition_blocks.find(block)
	if index >= 0:
		transition_blocks.remove_at(index)

# Transition out of battle
func _start_digital_transition_out():
	print("Starting digital transition OUT")
	
	# Start with transparent overlay
	if transition_rect:
		transition_rect.visible = true
		transition_rect.material = null
		transition_rect.color = Color(0, 0, 0, 0)
	
	# First fade to partially visible
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.4, 0.3)
	await tween.finished
	
	# Get viewport size
	var viewport_size = get_viewport_rect().size
	
	# Create digital blocks for exit
	_create_digital_blocks(viewport_size, false)
	
	# Add a short delay
	await get_tree().create_timer(0.4).timeout
	
	# Final fade to black
	tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.7)
	
	# Switch to battle end when done
	tween.finished.connect(func(): 
		# Clean up any remaining blocks
		for block in transition_blocks:
			if is_instance_valid(block):
				block.queue_free()
		transition_blocks.clear()
		
		# End the battle
		_end_battle()
	)

func create_debug_sprites():
	# Create player sprite placeholder if needed
	if player_sprite and player_sprite.texture == null:
		# Create placeholder player texture
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.2, 0.5, 0.8, 0.9))  # Blue for player
		
		# Add simple details
		for i in range(64):
			# Add face features
			if i > 20 and i < 44:
				if i > 25 and i < 30:
					img.set_pixel(i, 25, Color.BLACK)  # Left eye
				if i > 34 and i < 39:
					img.set_pixel(i, 25, Color.BLACK)  # Right eye
				if i > 28 and i < 36:
					img.set_pixel(i, 35, Color.BLACK)  # Mouth
			
			# Add outline
			img.set_pixel(i, 0, Color.WHITE)
			img.set_pixel(i, 63, Color.WHITE)
			img.set_pixel(0, i, Color.WHITE)
			img.set_pixel(63, i, Color.WHITE)
		
		var tex = ImageTexture.create_from_image(img)
		player_sprite.texture = tex
		print("Created placeholder player battle sprite")
	
	# Create enemy sprite placeholder if needed
	if enemy_sprite and enemy_sprite.texture == null:
		# Create placeholder enemy texture
		var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0.2, 0.2, 0.9))  # Red for enemy
		
		# Add simple details
		for i in range(48):
			# Add face features
			if i > 15 and i < 33:
				if i > 18 and i < 22:
					img.set_pixel(i, 20, Color.BLACK)  # Left eye
				if i > 26 and i < 30:
					img.set_pixel(i, 20, Color.BLACK)  # Right eye
				if i > 20 and i < 28:
					img.set_pixel(i, 30, Color.BLACK)  # Mouth (angry)
			
			# Add outline
			img.set_pixel(i, 0, Color.WHITE)
			img.set_pixel(i, 47, Color.WHITE)
			img.set_pixel(0, i, Color.WHITE)
			if i < 48:
				img.set_pixel(47, i, Color.WHITE)
		
		var tex = ImageTexture.create_from_image(img)
		enemy_sprite.texture = tex
		print("Created placeholder enemy battle sprite")
