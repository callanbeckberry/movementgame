extends CanvasLayer

class_name ModalManager

# Modal types
enum ModalType {
	NONE,
	RECAP,
	WALLET,
	MYSTERY,
	MAIN_MENU,  # New type
	AFTERMATH
}

# Node references - existing modals
@onready var modal_container = $ModalContainer
@onready var modal_background = $ModalContainer/Background
@onready var modal_content = $ModalContainer/Content
@onready var modal_portrait = $ModalContainer/Content/Portrait
@onready var modal_title = $ModalContainer/Content/Title
@onready var modal_text = $ModalContainer/Content/Text
@onready var modal_timer_label = $ModalContainer/Content/TimerLabel
@onready var modal_next_button = $ModalContainer/Content/NextButton
@onready var modal_skip_button = $ModalContainer/Content/SkipButton
@onready var modal_inventory = $ModalContainer/Content/Inventory

# Node references - main menu modal (add these nodes to your scene)
@onready var main_menu_container = $MainMenuContainer
@onready var main_menu_background = $MainMenuContainer/Background
@onready var main_menu_content = $MainMenuContainer/Content
@onready var main_menu_image = $MainMenuContainer/Content/Image
@onready var main_menu_text = $MainMenuContainer/Content/Text
@onready var main_menu_button = $MainMenuContainer/Content/Button

# Node references - aftermath scene
@onready var aftermath_container = $AftermathContainer
@onready var aftermath_background = $AftermathContainer/Background
@onready var aftermath_content = $AftermathContainer/Content
@onready var aftermath_image = $AftermathContainer/Content/Image
@onready var aftermath_title = $AftermathContainer/Content/Title
@onready var aftermath_text = $AftermathContainer/Content/Text
@onready var aftermath_next_text = $AftermathContainer/Content/NextText
@onready var aftermath_timer_label = $AftermathContainer/Content/TimerLabel

# Signals
signal modal_closed(modal_type)

# State variables
var current_modal_type = ModalType.NONE
var is_modal_active = false
var current_recap_step = 0
var recap_data = []
var countdown_active = false
var countdown_timer = 0.0
var countdown_duration = 30.0
var text_animation_timer = 0.0
var text_animation_index = 0
var full_text = ""
var player_ref = null
var target_text = ""  # For recap text animation
var is_text_animating = false
var wallet_open_count = 0
var current_wallet_yen = 0  # Will be updated from GlobalUIManager

# Aftermath state variables - add these with your other variables
var current_aftermath_step = 0
var aftermath_text_animating = false
var aftermath_displayed_text = ""
var aftermath_full_text = ""
var aftermath_text_timer = 0.0
var aftermath_text_speed = 0.03  # Seconds per character

# Main menu specific variables
var idle_timer = null
var is_continue_mode = false

# Global UI Manager reference
var global_ui_manager = null

# Simple animation variables for skip button
var button_animation_active = false 
var button_scale_amount = 1.3   # How much to scale up
var button_animation_speed = 5.0 # Animation speed
var button_animation_time = 0.0  # Animation timer

# Called when the node enters the scene tree for the first time
func _ready():
	print("ModalManager: Ready")
	
	# Initialize modal system
	modal_container.visible = false
	main_menu_container.visible = false
	aftermath_container.visible = false
	
	
	call_deferred("connect_to_battle_scene")
	
	# Set up recap data
	setup_recap_data()
	
	# Find player reference
	player_ref = get_tree().get_nodes_in_group("player")[0] if get_tree().get_nodes_in_group("player").size() > 0 else null
	print("ModalManager: Player reference found: ", player_ref != null)
	
	# Find GlobalUIManager reference
	global_ui_manager = get_node_or_null("/root/GlobalUIManager")
	print("ModalManager: GlobalUIManager reference found: ", global_ui_manager != null)
	
	# Set up idle timer
	idle_timer = Timer.new()
	idle_timer.wait_time = 300.0  # 10 seconds for testing, change to 300 for 5 minutes
	idle_timer.one_shot = true
	idle_timer.autostart = false
	add_child(idle_timer)
	idle_timer.timeout.connect(_on_idle_timeout)
	
	# Start idle timer
	idle_timer.start()
	
	# Add to group for easy access
	add_to_group("modal_manager")

# Called every frame for animations and timers
func _process(delta):
	# Handle countdown timer if active
	if countdown_active and countdown_timer > 0:
		countdown_timer -= delta
		update_timer_display()
		
		if countdown_timer <= 0:
			countdown_active = false
			modal_timer_label.visible = false  # Hide timer when it reaches zero
			enable_next_button()
	
	# Handle text animation for mystery modal
	if current_modal_type == ModalType.MYSTERY and text_animation_index < full_text.length():
		text_animation_timer += delta
		if text_animation_timer >= 0.03:  # Speed of text reveal
			text_animation_timer = 0
			text_animation_index += 1
			modal_text.text = full_text.substr(0, text_animation_index)
	
	# Handle text animation for recap modal
	if current_modal_type == ModalType.RECAP and is_text_animating and text_animation_index < target_text.length():
		text_animation_timer += delta
		if text_animation_timer >= 0.03:  # Speed of text reveal
			text_animation_timer = 0
			text_animation_index += 1
			modal_text.text = target_text.substr(0, text_animation_index)
			
		if text_animation_index >= target_text.length():
			is_text_animating = false
	
	# Simple button animation - scale up and down
	if button_animation_active:
		button_animation_time += delta * button_animation_speed
		
		# Scale from normal to big and back to normal using sine wave
		var scale_factor = 1.0 + (button_scale_amount - 1.0) * max(0, sin(button_animation_time * PI))
		modal_skip_button.scale = Vector2(scale_factor, scale_factor)
		
		# End animation after one cycle
		if button_animation_time >= 1.0:
			button_animation_active = false
			button_animation_time = 0.0
			modal_skip_button.scale = Vector2(1, 1)  # Reset to normal scale
			
	if current_modal_type == ModalType.AFTERMATH and aftermath_text_animating:
		aftermath_text_timer += delta
		if aftermath_text_timer >= aftermath_text_speed:
			aftermath_text_timer = 0
			
			if aftermath_displayed_text.length() < aftermath_full_text.length():
				aftermath_displayed_text += aftermath_full_text[aftermath_displayed_text.length()]
				aftermath_text.text = aftermath_displayed_text
			else:
				aftermath_text_animating = false
				aftermath_next_text.visible = true

	# Handle aftermath countdown only on final section
	if (current_modal_type == ModalType.AFTERMATH and 
		current_aftermath_step == aftermath_data.size() - 1 and 
		aftermath_countdown_active):
		aftermath_countdown_timer -= delta
		
		# Update timer display using the new label
		if aftermath_timer_label:
			aftermath_timer_label.text = "Time until restart: " + str(int(aftermath_countdown_timer)) + "s"
			aftermath_timer_label.visible = true
		
		# Update next text display
		if aftermath_next_text:
			aftermath_next_text.text = "Restart in " + str(int(aftermath_countdown_timer)) + "s"
		
		# Check if countdown is complete
		if aftermath_countdown_timer <= 0:
			aftermath_countdown_active = false
			
			# Hide timer label
			if aftermath_timer_label:
				aftermath_timer_label.visible = false
			
			# Update next text
			if aftermath_next_text:
				aftermath_next_text.text = "Restart!"
				aftermath_next_text.visible = true

# Global input handler
func _input(event):
	# Reset idle timer on any input if not in a modal
	if not is_modal_active and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		if event.is_pressed() and not event.is_echo():
			if idle_timer:
				idle_timer.start()
	
	# Return if no modal is active
	if not is_modal_active:
		return
		
	# Handle the "select" button for main menu
	if current_modal_type == ModalType.MAIN_MENU:
		if Input.is_action_just_pressed("ui_select"):
			_on_main_menu_button_pressed()
		return
	
	# Handle button presses based on current modal
	if current_modal_type == ModalType.RECAP:
		handle_recap_input(event)
	elif current_modal_type == ModalType.WALLET:
		handle_wallet_input(event)
	elif current_modal_type == ModalType.MYSTERY:
		handle_mystery_input(event)

	if current_modal_type == ModalType.AFTERMATH:
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			if event.is_pressed() and not event.is_echo():
				if aftermath_text_animating:
					# Skip to the end of text animation
					aftermath_displayed_text = aftermath_full_text
					aftermath_text.text = aftermath_displayed_text
					aftermath_text_animating = false
					aftermath_next_text.visible = true
				elif aftermath_countdown_active:
					# Add move pressed to skip countdown (like recap modal)
					if Input.is_action_just_pressed("add_move"):
						aftermath_countdown_active = false
						aftermath_countdown_timer = 0
						
						# Update timer label and next text
						if aftermath_timer_label:
							aftermath_timer_label.visible = false
						
						if aftermath_next_text:
							aftermath_next_text.text = "Restart!"
							aftermath_next_text.visible = true
					else:
						# Existing mashing logic
						aftermath_countdown_timer = max(0, aftermath_countdown_timer - 1)
						
						# Update timer label when mashing
						if aftermath_timer_label:
							aftermath_timer_label.text = "Time until restart: " + str(int(aftermath_countdown_timer)) + "s"
						
						# Check if countdown is skipped entirely
						if aftermath_countdown_timer <= 0:
							aftermath_countdown_active = false
							
							# Hide timer label
							if aftermath_timer_label:
								aftermath_timer_label.visible = false
							
							if aftermath_next_text:
								aftermath_next_text.text = "Restart!"
								aftermath_next_text.visible = true
				else:
					# Advance to next part or end
					advance_aftermath()
		return

# Idle timeout handler
func _on_idle_timeout():
	if not is_modal_active:
		open_main_menu(true)  # Open in continue mode

# Open main menu modal
func open_main_menu(continue_mode = false):
	if is_modal_active:
		return
	
	print("ModalManager: Opening main menu modal, continue mode: ", continue_mode)
	current_modal_type = ModalType.MAIN_MENU
	is_modal_active = true
	is_continue_mode = continue_mode
	
	# Pause the game
	get_tree().paused = true
	
	# Set up the modal
	main_menu_container.visible = true
	
	# Set content
	if continue_mode:
		main_menu_text.text = "Press SELECT to Continue"
	else:
		main_menu_text.text = "Press SELECT to Start"
	
	# Set background image
	if ResourceLoader.exists("res://assets/main_menu_background.png"):
		var texture = load("res://assets/main_menu_background.png")
		main_menu_image.texture = texture

# Main menu button handler
func _on_main_menu_button_pressed():
	print("ModalManager: Main menu button pressed, continue mode: ", is_continue_mode)
	
	# Close modal and restart idle timer
	close_modal()
	
	# If this is a new game, could add reset logic here
	if not is_continue_mode:
		# Reset game state if needed
		pass

# Prepare the recap data
func setup_recap_data():
	recap_data = [
		{
			"title": "Chapter 1: The Beginning",
			"text": "You awake in a mysterious dungeon with no memory of how you got here. Your only guide is a talking wizard turtle who offers cryptic advice.",
			"portrait": "res://assets/recap_1.png"
		},
		{
			"title": "Chapter 2: The Discovery",
			"text": "While exploring the dungeon, you discover that collecting special coins can unlock hidden areas and powerful abilities.",
			"portrait": "res://assets/recap_2.png"
		},
		{
			"title": "Chapter 3: The Enemies",
			"text": "Strange creatures lurk in the shadows. Some can be battled, some avoided, and some might even help you on your quest.",
			"portrait": "res://assets/recap_3.png"
		},
		{
			"title": "Chapter 4: The Mission",
			"text": "Your ultimate goal is to collect all 120 coins and face the final boss to escape the dungeon and discover the truth about your past.",
			"portrait": "res://assets/recap_4.png"
		}
	]
	print("ModalManager: Recap data set up with ", recap_data.size(), " entries")

# Handle input for recap modal
func handle_recap_input(event):
	# Space or Interact pressed to advance (only if text animation completed)
	if event is InputEventKey:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
			if is_text_animating:
				# Skip to the end of text animation
				text_animation_index = target_text.length()
				modal_text.text = target_text
				is_text_animating = false
				return
				
			# Decrease timer by 1 second if countdown is active
			if countdown_active:
				countdown_timer -= 1.0
				# Trigger button animation
				animate_skip_button()
				
				if countdown_timer <= 0:
					countdown_active = false
					modal_timer_label.visible = false  # Hide timer when it reaches zero
					enable_next_button()
				update_timer_display()
				return
				
			# If countdown is over, advance to next recap
			if not countdown_active:
				if current_recap_step < recap_data.size() - 1:
					advance_recap()
				else:
					close_modal()
		
		# Add move pressed to skip countdown
		if Input.is_action_just_pressed("add_move") and countdown_active:
			skip_countdown()

# Function to animate the skip button (simple scale animation)
func animate_skip_button():
	button_animation_active = true
	button_animation_time = 0.0

# Handle input for wallet modal
func handle_wallet_input(event):
	# Space or Interact pressed to close
	if event is InputEventKey:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
			close_modal()

# Handle input for mystery modal
func handle_mystery_input(event):
	# Space or Interact pressed to close (only if text animation is complete)
	if event is InputEventKey:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
			if text_animation_index < full_text.length():
				# Skip to the end of text animation
				text_animation_index = full_text.length()
				modal_text.text = full_text
			else:
				close_modal()

# Open the recap modal
func open_recap_modal():
	if is_modal_active:
		return
		
	print("ModalManager: Opening recap modal")
	current_modal_type = ModalType.RECAP
	is_modal_active = true
	current_recap_step = 0
	
	# Pause the game
	get_tree().paused = true
	
	# Set up the modal
	modal_container.visible = true
	modal_inventory.visible = false
	modal_portrait.visible = true
	modal_timer_label.visible = true
	modal_skip_button.visible = true
	modal_next_button.visible = false
	
	# Reset button scale
	modal_skip_button.scale = Vector2(1, 1)
	
	# Display first recap step
	display_recap_step(current_recap_step)
	
	# Start countdown
	start_countdown()

# Open the wallet modal
func open_wallet_modal():
	if is_modal_active:
		return
		
	print("ModalManager: Opening wallet modal")
	current_modal_type = ModalType.WALLET
	is_modal_active = true
	
	# Pause the game
	get_tree().paused = true
	
	# Set up the modal
	modal_container.visible = true
	modal_inventory.visible = true
	modal_portrait.visible = true
	modal_timer_label.visible = false
	modal_skip_button.visible = false
	
	# Set wallet content
	modal_title.text = "Your Wallet"
	modal_text.text = ""
	
	# Set portrait texture
	if ResourceLoader.exists("res://assets/wallet_portrait.png"):
		var texture = load("res://assets/wallet_portrait.png")
		modal_portrait.texture = texture
	
	# Setup inventory items (safely)
	update_inventory_display()
	
	# Setup next button
	modal_next_button.text = "Back"
	modal_next_button.visible = true
	
	# Add small animation to the wallet
	var tween = create_tween()
	tween.tween_property(modal_content, "scale", Vector2(1.05, 1.05), 0.2)
	tween.tween_property(modal_content, "scale", Vector2(1.0, 1.0), 0.1)

# Open the mystery modal
func open_mystery_modal():
	if is_modal_active:
		return
		
	print("ModalManager: Opening mystery modal")
	current_modal_type = ModalType.MYSTERY
	is_modal_active = true
	
	# Pause the game
	get_tree().paused = true
	
	# Set up the modal
	modal_container.visible = true
	modal_inventory.visible = false
	modal_portrait.visible = true
	modal_timer_label.visible = false
	modal_skip_button.visible = false
	
	# Set mystery content
	modal_title.text = "???"
	
	# Get random mysterious phrases
	var mystery_phrases = [
		"The turtles hold the secret to everything...",
		"Did you notice the pattern in the coins?",
		"Sometimes moving backwards is the way forward.",
		"The walls have ears, and possibly coins too.",
		"Not everything that glitters is a coin, but it might be worth checking.",
		"The wizard turtle isn't telling you everything."
	]
	
	# Select random phrase
	full_text = mystery_phrases[randi() % mystery_phrases.size()]
	modal_text.text = ""
	text_animation_index = 0
	text_animation_timer = 0
	
	# Set portrait texture
	if ResourceLoader.exists("res://assets/mystery_portrait.png"):
		var texture = load("res://assets/mystery_portrait.png")
		modal_portrait.texture = texture
	
	# Setup next button
	modal_next_button.text = "Cool"
	modal_next_button.visible = true

# Close the current modal
func close_modal():
	if not is_modal_active:
		return
	
	print("ModalManager: Closing modal of type ", current_modal_type)
	
	# Save current type before resetting
	var previous_type = current_modal_type
	
	# Reset state
	is_modal_active = false
	current_modal_type = ModalType.NONE
	countdown_active = false
	is_text_animating = false
	
	# Hide the modal containers
	modal_container.visible = false
	main_menu_container.visible = false
	aftermath_container.visible = false
	
	# Unpause the game
	get_tree().paused = false
	
	# Restart idle timer
	if idle_timer:
		idle_timer.start()
	
	# Emit signal
	emit_signal("modal_closed", previous_type)

# Display the current recap step
func display_recap_step(step_index):
	if step_index < 0 or step_index >= recap_data.size():
		return
	
	var step = recap_data[step_index]
	
	# Set content
	modal_title.text = step.title
	
	# Start text animation
	target_text = step.text
	text_animation_index = 0
	text_animation_timer = 0
	modal_text.text = ""
	is_text_animating = true
	
	# Set portrait if available
	if ResourceLoader.exists(step.portrait):
		var texture = load(step.portrait)
		modal_portrait.texture = texture
	
	# Setup next/done button text
	if step_index < recap_data.size() - 1:
		modal_next_button.text = "Next"
	else:
		modal_next_button.text = "Done"

# Advance to the next recap step
func advance_recap():
	current_recap_step += 1
	if current_recap_step < recap_data.size():
		display_recap_step(current_recap_step)
		modal_next_button.visible = false
		start_countdown()
	else:
		close_modal()

# Start the countdown timer
func start_countdown():
	countdown_timer = countdown_duration
	countdown_active = true
	modal_timer_label.visible = true  # Make sure timer is visible for each new step
	modal_next_button.visible = false
	modal_skip_button.text = "Insert coin to speed up"
	modal_skip_button.visible = true
	update_timer_display()

# Update the timer display
func update_timer_display():
	var seconds = int(countdown_timer)
	modal_timer_label.text = str(seconds) + "s"

# Skip the countdown
func skip_countdown():
	countdown_active = false
	countdown_timer = 0
	modal_timer_label.visible = false  # Hide the timer when skipping
	enable_next_button()

# Enable the next button and hide timer
func enable_next_button():
	modal_skip_button.visible = false
	modal_next_button.visible = true
	modal_timer_label.visible = false  # Hide the timer when countdown is over

func update_inventory_display():
	print("ModalManager: Updating inventory display")
	
	# Get coin count from player safely
	var coin_count = 0
	if player_ref and player_ref.get("coins") != null:
		coin_count = player_ref.coins
	
	# Generate a random yen amount between 1-1000
	var random_yen = randi() % 1000 + 1
	
	# Check if player is carrying a key
	var has_key = false
	if player_ref and player_ref.get("has_key") != null:
		has_key = player_ref.has_key
	
	# Setup inventory text with bullet points and single line spacing
	var inventory_text = "• ¥%d based on current exchange rate\n" % [random_yen]
	inventory_text += "• Roughly half a protein bar\n"
	inventory_text += "• 3/10 free coffee stamps punched\n"
	inventory_text += "• %d Turtle Coins\n" % [coin_count]
	
	# Add key-rrot entry if the player has a key (using RichTextLabel formatting)
	if has_key:
		# Use BBCode for dark orange color if RichTextLabel is used
		if modal_inventory is RichTextLabel:
			inventory_text += "• [color=#FF8C00]1 key-rrot[/color]\n"
		else:
			# If it's a regular Label, we'll still add it without color
			inventory_text += "• 1 key-rrot\n"
	
	# Always end with the good attitude
	inventory_text += "• A good attitude!"
	
	# Set text directly
	modal_inventory.text = inventory_text
	
	# If we're using a RichTextLabel, need to enable BBCode
	if modal_inventory is RichTextLabel:
		modal_inventory.bbcode_enabled = true

# Button signal handlers
func _on_next_button_pressed():
	if current_modal_type == ModalType.RECAP:
		if current_recap_step < recap_data.size() - 1:
			advance_recap()
		else:
			close_modal()
	else:
		close_modal()

func _on_skip_button_pressed():
	if current_modal_type == ModalType.RECAP and countdown_active:
		skip_countdown()

func open_aftermath_sequence():
	if is_modal_active:
		return
	
	print("ModalManager: Opening aftermath sequence")
	current_modal_type = ModalType.AFTERMATH
	is_modal_active = true
	current_aftermath_step = 0
	
	# Pause the game
	get_tree().paused = true
	
	# Set up the modal - make it visible here
	aftermath_container.visible = true
	
	# Show first part
	show_aftermath_part(current_aftermath_step)

var aftermath_countdown_active = false
var aftermath_countdown_timer = 0.0
var aftermath_countdown_duration = 100.0  # 100 seconds
var aftermath_countdown_skipped = false

var aftermath_data = [
	{
		"title": "The Aftermath",
		"text": "As the final boss crumbles to dust, the dungeon begins to shake. The walls crack and sunlight streams in for the first time in what feels like centuries. Your journey through this mysterious place is finally coming to an end.",
		"image": "res://assets/finale_image_1.png"
	},
	{
		"title": "The Truth",
		"text": "The wizard turtle approaches you, no longer speaking in riddles. 'You have broken the curse that bound this place. The 120 coins you collected were fragments of an ancient seal. By gathering them all, you've restored what was lost.'",
		"image": "res://assets/finale_image_2.png"
	},
	{
		"title": "The Revelation",
		"text": "Memories flood back into your mind. You weren't trapped here by chance. You came willingly to break the curse, knowing you might forget yourself in the process. The world outside has been waiting for your return.",
		"image": "res://assets/finale_image_3.png"
	},
	{
		"title": "The Beginning",
		"text": "As you step out into the light, the wizard turtle gives you one final gift - a single golden coin. 'Should you ever wish to return and attempt this journey again, this will be your key.' You pocket the coin and face the open world before you.",
		"image": "res://assets/finale_image_4.png"
	},
	{
		"title": "Ready to Play Again?",
		"text": "I'm so excited you want to play my game! Mash the buttons or insert a coin to play again.",
		"image": "res://assets/finale_image_5.png"
	}
]
# Function to show a specific part of the aftermath
func show_aftermath_part(part_index):
	if part_index < 0 or part_index >= aftermath_data.size():
		return
	
	var part = aftermath_data[part_index]
	
	# Set title
	aftermath_title.text = part.title
	
	# Set up text animation
	aftermath_full_text = part.text
	aftermath_displayed_text = ""
	aftermath_text.text = ""
	aftermath_text_animating = true
	aftermath_text_timer = 0
	
	# Reset countdown flags
	aftermath_countdown_active = false
	aftermath_countdown_timer = 0
	
	# Hide timer label initially
	if aftermath_timer_label:
		aftermath_timer_label.visible = false
	
	# Hide next text until animation completes
	aftermath_next_text.visible = false
	
	# Update next text based on whether this is the last part
	if part_index == aftermath_data.size() - 1:
		# For the final section, start a countdown
		aftermath_countdown_active = true
		aftermath_countdown_timer = aftermath_countdown_duration
		
		# Show timer label for final section
		if aftermath_timer_label:
			aftermath_timer_label.visible = true
			aftermath_timer_label.text = "Time until restart: " + str(int(aftermath_countdown_timer)) + "s"
		
		aftermath_next_text.text = "Restart in " + str(int(aftermath_countdown_timer)) + "s"
	else:
		# For other sections, set to "Next"
		aftermath_next_text.text = "Next"
	
	# Set image
	if ResourceLoader.exists(part.image):
		var texture = load(part.image)
		aftermath_image.texture = texture

# Function to advance to next part of aftermath
func advance_aftermath():
	current_aftermath_step += 1
	
	if current_aftermath_step < aftermath_data.size():
		# Show next part
		show_aftermath_part(current_aftermath_step)
	else:
		# End sequence and restart game
		restart_game()

# Function to restart the game
func restart_game():
	# Close the modal
	close_modal()
	
	# Directly use the scene path
	var scene_path = "res://node_2D.tscn"
	
	if ResourceLoader.exists(scene_path):
		# Use change_scene_to_file for a clean restart
		var error = get_tree().change_scene_to_file(scene_path)
		
		if error == OK:
			print("Scene reloaded successfully")
			# Use a timer to delay opening main menu to ensure scene is fully loaded
			var timer = Timer.new()
			timer.wait_time = 0.1  # Small delay
			timer.one_shot = true
			timer.timeout.connect(func():
				# Try to find modal manager in the new scene
				var root = get_tree().root
				if root:
					var modal_managers = root.get_nodes_in_group("modal_manager")
					if modal_managers.size() > 0:
						var modal_manager = modal_managers[0]
						modal_manager.open_main_menu(false)
					else:
						print("Could not find modal manager to open main menu")
				else:
					print("Could not access scene tree root")
			)
			# Add the timer to the scene and start it
			add_child(timer)
			timer.start()
		else:
			print("Error reloading scene: ", error)
	else:
		print("Could not find scene: ", scene_path)

func _open_main_menu_after_restart():
	# Find the modal manager in the new scene
	var modal_managers = get_tree().get_nodes_in_group("modal_manager")
	if modal_managers.size() > 0:
		var modal_manager = modal_managers[0]
		modal_manager.open_main_menu(false)
	else:
		print("Could not find modal manager to open main menu")

# Connect to BattleScene to trigger aftermath
func connect_to_battle_scene():
	var battle_scene = get_tree().get_nodes_in_group("battle_scene")[0] if get_tree().get_nodes_in_group("battle_scene").size() > 0 else null
	
	if battle_scene and battle_scene.has_signal("final_boss_defeated"):
		if not battle_scene.is_connected("final_boss_defeated", _on_final_boss_defeated):
			battle_scene.connect("final_boss_defeated", _on_final_boss_defeated)
			print("ModalManager: Connected to final_boss_defeated signal")

# Handler for when final boss is defeated
func _on_final_boss_defeated():
	print("ModalManager: Final boss defeated, showing aftermath sequence")
	call_deferred("open_aftermath_sequence")
