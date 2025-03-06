extends Node2D

# References to nodes
@onready var player_sprite = $PlayerSprite
@onready var enemy_sprite = $EnemySprite
@onready var enemy_speech_bubble = $EnemySprite/SpeechBubble
@onready var enemy_speech_text = $EnemySprite/SpeechBubble/Text
@onready var player_attack_bar = $UI/AttackBar
@onready var direction_prompt = $UI/DirectionPrompt
@onready var attack_menu = $UI/AttackMenu
@onready var enemy_health = 1
@onready var attack_timer = $Timers/EnemyAttackTimer
@onready var speech_timer = $Timers/SpeechBubbleTimer

# Game state
var in_battle = false
var direction_inputs_correct = 0
var current_prompt_direction = ""
var attack_charging = false
var attack_menu_open = false
var selected_attack_index = 0

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

# Player attack names
var player_attacks = [
	"Heroic Punch",
	"Valiant Slash",
	"Righteous Beam",
	"Courageous Strike",
	"Legendary Smash"
]

# Direction mapping
var directions = ["up", "down", "left", "right"]

# Signal for when battle ends
signal battle_ended

func _ready():
	# Initially hide battle elements
	visible = false
	enemy_speech_bubble.visible = false
	attack_menu.visible = false
	direction_prompt.visible = false
	
	# Initialize the attack bar
	player_attack_bar.max_value = 50
	player_attack_bar.value = 0
	
	# Connect timers
	attack_timer.timeout.connect(_on_enemy_attack_timer_timeout)
	speech_timer.timeout.connect(_on_speech_timer_timeout)
	
	# Create debug sprites if needed
	create_debug_sprites()

func start_battle():
	print("Battle started!")
	in_battle = true
	
	# Show battle scene elements
	visible = true
	
	# Reset battle state
	enemy_health = 1
	direction_inputs_correct = 0
	player_attack_bar.value = 0
	attack_charging = true
	attack_menu_open = false
	selected_attack_index = 0
	
	# Show direction prompt
	direction_prompt.visible = true
	attack_menu.visible = false
	
	# Set a random initial prompt
	_set_new_direction_prompt()
	
	# Start enemy attack timer (random between 15-30 seconds)
	_start_random_enemy_attack_timer()

func _process(delta):
	if not in_battle:
		return
		
	if attack_charging and not attack_menu_open:
		# Check for direction inputs
		if Input.is_action_just_pressed("up"):
			_check_direction_input("up")
		elif Input.is_action_just_pressed("down"):
			_check_direction_input("down")
		elif Input.is_action_just_pressed("left"):
			_check_direction_input("left")
		elif Input.is_action_just_pressed("right"):
			_check_direction_input("right")
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
		# Correct input
		direction_inputs_correct += 1
		player_attack_bar.value = direction_inputs_correct
		
		# Check if attack bar is full
		if direction_inputs_correct >= 50:
			_open_attack_menu()
		else:
			# Set new direction prompt
			_set_new_direction_prompt()
	else:
		# Wrong input, reset progress
		direction_inputs_correct = 0
		player_attack_bar.value = 0
		
		# Set new direction prompt
		_set_new_direction_prompt()

func _set_new_direction_prompt():
	# Choose a random direction
	current_prompt_direction = directions[randi() % directions.size()]
	
	# Update the direction prompt UI
	direction_prompt.text = "Press " + current_prompt_direction.capitalize()

func _open_attack_menu():
	attack_charging = false
	attack_menu_open = true
	
	# Hide direction prompt, show attack menu
	direction_prompt.visible = false
	attack_menu.visible = true
	
	# Clear any existing buttons (in case we reopen the menu)
	for child in attack_menu.get_children():
		if child.name != "MenuLabel":  # Keep the label
			child.queue_free()
	
	# Create attack buttons vertically
	for i in range(5):
		var button = Button.new()
		button.text = player_attacks[i]
		button.name = "AttackButton" + str(i+1)
		
		# Add to menu
		attack_menu.add_child(button)
		
		# Connect button press to attack function
		button.pressed.connect(_execute_player_attack.bind(i))
	
	# Initialize selection
	selected_attack_index = 0
	_update_selected_attack()

func _update_selected_attack():
	# Highlight the selected button and unhighlight others
	for i in range(5):
		var button = attack_menu.get_node_or_null("AttackButton" + str(i+1))
		if button:
			if i == selected_attack_index:
				button.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
			else:
				button.remove_theme_color_override("font_color")

func _execute_player_attack(attack_index):
	print("Player used " + player_attacks[attack_index] + "!")
	
	# Shake the player sprite (animate back and forth)
	var tween = create_tween()
	tween.tween_property(player_sprite, "position:x", player_sprite.position.x + 10, 0.1)
	tween.tween_property(player_sprite, "position:x", player_sprite.position.x, 0.1)
	
	# Wait a bit before showing enemy reaction
	await get_tree().create_timer(0.5).timeout
	
	# Damage enemy (health is just 1)
	enemy_health = 0
	
	# Shake enemy sprite
	tween = create_tween()
	tween.tween_property(enemy_sprite, "position:x", enemy_sprite.position.x - 10, 0.1)
	tween.tween_property(enemy_sprite, "position:x", enemy_sprite.position.x, 0.1)
	
	# Show defeat message
	_show_enemy_speech_bubble(enemy_defeat_messages[randi() % enemy_defeat_messages.size()])
	
	# End battle after a short delay
	await get_tree().create_timer(2.0).timeout
	_end_battle()

func _on_enemy_attack_timer_timeout():
	# Enemy attacks - choose a random attack name
	var attack_name = enemy_attack_names[randi() % enemy_attack_names.size()]
	print("Enemy used " + attack_name + "!")
	
	# Show speech bubble with attack name
	_show_enemy_speech_bubble(attack_name)
	
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

func _show_enemy_speech_bubble(text):
	enemy_speech_text.text = text
	enemy_speech_bubble.visible = true
	
	# Start timer to hide speech bubble
	speech_timer.start(2.0)  # Show for 2 seconds

func _on_speech_timer_timeout():
	enemy_speech_bubble.visible = false

func _start_random_enemy_attack_timer():
	# Random time between 15-30 seconds
	var attack_delay = randf_range(15.0, 30.0)
	attack_timer.start(attack_delay)

func _end_battle():
	in_battle = false
	
	# Hide battle scene
	visible = false
	
	# Signal to the main game that battle is over
	emit_signal("battle_ended")

func create_debug_sprites():
	# Create player sprite placeholder if needed
	var player_sprite_node = get_node_or_null("PlayerSprite")
	if player_sprite_node and player_sprite_node.texture == null:
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
		player_sprite_node.texture = tex
		print("Created placeholder player battle sprite")
	
	# Create enemy sprite placeholder if needed
	var enemy_sprite_node = get_node_or_null("EnemySprite")
	if enemy_sprite_node and enemy_sprite_node.texture == null:
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
		enemy_sprite_node.texture = tex
		print("Created placeholder enemy battle sprite")
