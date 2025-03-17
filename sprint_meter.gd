extends Node2D

signal sprint_state_changed(state)

enum SprintState {
	IDLE,
	JOGGING,
	RUNNING,
	SPRINTING
}

# Animation nodes
@onready var animated_sprite: AnimatedSprite2D = $RabbitSprite
@onready var cooldown_timer: Timer = $CooldownTimer

# Sprint parameters
@export var current_presses: int = 0
@export var cooldown_time: float = 5.0
@export var jogging_threshold: int = 1
@export var running_threshold: int = 21
@export var sprinting_threshold: int = 41

# Player reference
var player = null
var space_press_tracked = 0
var current_state: SprintState = SprintState.IDLE
var debug_label: Label = null

func _ready():
	# Make sure required nodes exist
	if cooldown_timer == null:
		# Create the timer if it doesn't exist
		cooldown_timer = Timer.new()
		add_child(cooldown_timer)
		cooldown_timer.name = "CooldownTimer"
	
	# Explicitly connect the timeout signal (previous connection might be failing)
	if cooldown_timer.timeout.is_connected(_on_cooldown_timer_timeout):
		cooldown_timer.timeout.disconnect(_on_cooldown_timer_timeout)
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	
	# Initialize the cooldown timer
	cooldown_timer.wait_time = cooldown_time
	cooldown_timer.one_shot = false
	
	# Add debug label
	_add_debug_label()
	
	# Check if RabbitSprite exists
	if animated_sprite == null:
		animated_sprite = find_child("RabbitSprite")
		
	if animated_sprite == null:
		push_warning("RabbitSprite not found. Please add an AnimatedSprite2D named 'RabbitSprite' as a child.")
	else:
		# Verify animations exist
		_verify_animations()
		# Initialize animation state
		_update_animation()
	
	# Find and connect to the player
	call_deferred("_find_and_connect_player")
	
	# Start the timer to check for inactivity
	cooldown_timer.start()
	
	print("Sprint Meter initialized. Cooldown timer: ", cooldown_timer.wait_time, "s")

func _add_debug_label():
	# Add a debug label to see what's happening
	debug_label = Label.new()
	debug_label.position = Vector2(0, -30) # Position above the sprite
	debug_label.text = "Sprint: IDLE"
	add_child(debug_label)

func _verify_animations():
	# Check if all required animations exist
	var sprite_frames = animated_sprite.sprite_frames
	if sprite_frames == null:
		push_error("No SpriteFrames resource assigned to AnimatedSprite2D")
		return
		
	var required_animations = ["idle", "jogging", "running", "sprinting"]
	var missing_animations = []
	
	for anim in required_animations:
		if not sprite_frames.has_animation(anim):
			missing_animations.append(anim)
	
	if missing_animations.size() > 0:
		push_warning("Missing animations: " + str(missing_animations))

func _find_and_connect_player():
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Try to find the player in the scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("Sprint meter connected to player: ", player.name)
	else:
		push_warning("Could not find a player node in the 'player' group.")

func _process(_delta):
	if player == null:
		# Try to find player again if not found
		_find_and_connect_player()
		return
		
	# Check if the player's space bar count has changed
	var new_space_count = player.space_press_count
	
	if new_space_count != space_press_tracked:
		# Space bar has been pressed, increment our counter
		if new_space_count > space_press_tracked:
			current_presses += 1
			
			# Reset the cooldown timer
			if cooldown_timer:
				cooldown_timer.stop()
				cooldown_timer.start()
			
			# Update animation based on new press count
			_update_state()
			_update_animation()
		
		# Update our tracked value
		space_press_tracked = new_space_count
		
	# Update debug info
	if debug_label:
		var state_names = ["IDLE", "JOGGING", "RUNNING", "SPRINTING"]
		debug_label.text = "Sprint: " + state_names[current_state] + " (" + str(current_presses) + ")\nTimer: " + str(int(cooldown_timer.time_left)) + "s"

func _on_cooldown_timer_timeout():
	print("Cooldown timer timeout! Current state:", current_state)
	
	# Decrease state by one level after cooldown
	if current_presses > 0:
		match current_state:
			SprintState.SPRINTING:
				current_presses = running_threshold
				print("Decreasing from SPRINTING to RUNNING")
			SprintState.RUNNING:
				current_presses = jogging_threshold
				print("Decreasing from RUNNING to JOGGING")
			SprintState.JOGGING:
				current_presses = 0
				print("Decreasing from JOGGING to IDLE")
		
		# Update animation based on new state
		_update_state()
		_update_animation()
		
		# Restart timer if not at idle
		if current_state != SprintState.IDLE:
			cooldown_timer.start()
	else:
		print("No presses to decrease")

func _update_state():
	# Determine the current state based on press count
	var new_state
	if current_presses >= sprinting_threshold:
		new_state = SprintState.SPRINTING
	elif current_presses >= running_threshold:
		new_state = SprintState.RUNNING
	elif current_presses >= jogging_threshold:
		new_state = SprintState.JOGGING
	else:
		new_state = SprintState.IDLE
	
	# Only update if state changed
	if new_state != current_state:
		current_state = new_state
		
		# Emit signal when state changes
		emit_signal("sprint_state_changed", current_state)
		print("Sprint state changed to: ", current_state)

func _update_animation():
	# Only update animation if sprite exists
	if animated_sprite and animated_sprite.sprite_frames:
		# Change animation based on current state
		var anim_name = ""
		match current_state:
			SprintState.IDLE:
				anim_name = "idle"
			SprintState.JOGGING:
				anim_name = "jogging"
			SprintState.RUNNING:
				anim_name = "running"
			SprintState.SPRINTING:
				anim_name = "sprinting"
		
		# Check if animation exists before playing
		if animated_sprite.sprite_frames.has_animation(anim_name):
			print("Playing animation: ", anim_name)
			animated_sprite.play(anim_name)
		else:
			push_error("Animation not found: " + anim_name)
	else:
		# Print debug info about current state even without sprite
		print("Cannot play animation - sprite or frames missing")

# Public method to reset counter
func reset_counter():
	current_presses = 0
	_update_state()
	_update_animation()

# Get current state (for other scripts to check)
func get_current_state() -> int:
	return current_state
