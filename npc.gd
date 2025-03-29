extends Area2D

class_name NPC

# Basic NPC properties
@export var npc_name: String = "Villager"
@export var portrait_texture: Texture2D
@export var interaction_distance: float = 50.0
@export_multiline var first_time_dialogue: String = "This is my special first meeting dialogue!"
@export_multiline var dialogues: Array[String] = [
	"Hello there, traveler!",
	"Nice weather we're having.",
	"Have you collected all the coins yet?"
]

# Animation properties
@export var sprite_frames: SpriteFrames
@export var default_animation: String = "idle"
@export_enum("idle", "talk", "walk", "react") var current_animation: String = "idle"

# References
var player = null
var dialogue_manager = null
var in_range = false
var dialogue_cooldown = false
var is_talking = false

# Track if first dialogue has been shown
var has_shown_first_dialogue := false

# Autoload reference for persistent data
var save_data = null

# Called when the node enters the scene tree for the first time
func _ready():
	add_to_group("npcs")
	
	# Initialize or get the global save manager
	_ensure_global_save_manager()
	
	# Load this NPC's dialogue state
	_load_npc_state()
	
	# Set up the animated sprite if provided
	var animated_sprite = $AnimatedSprite2D
	if animated_sprite and sprite_frames:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play(default_animation)
		print("NPC " + npc_name + " playing animation: " + default_animation)
	else:
		print("NPC " + npc_name + " missing AnimatedSprite2D or SpriteFrames!")
	
	# Connect signal for player entering/exiting interaction zone
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Find dialogue manager in scene tree - try multiple paths
	dialogue_manager = find_dialogue_manager()

func _process(_delta):
	# Handle animation states
	if is_talking and current_animation != "talk":
		play_animation("talk")
	elif not is_talking and in_range and current_animation != "react":
		play_animation("react")  # React when player is nearby
	elif not is_talking and not in_range and current_animation != default_animation:
		play_animation(default_animation)  # Return to default when nothing happens

# Create or get access to a global save manager
func _ensure_global_save_manager():
	# Create a simple dictionary to store our data
	# We'll use a more straightforward approach with a class variable instead of Engine.register_singleton
	if save_data == null:
		# Access the global script singleton if it exists
		var root = get_tree().get_root()
		var global_data = root.get_node_or_null("NPCSaveManager")
		
		if global_data:
			# Use existing global singleton
			save_data = global_data
		else:
			# Initialize our own local copy of the data
			save_data = {"dialogue_states": {}}
			
			# We'll sync with disk instead of using a global object
			_load_from_disk()
	
	# For debugging - comment out in production
	# print("NPC save data: ", save_data)

# Find the dialogue manager in the scene tree
func find_dialogue_manager():
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		print("Found DialogueManager at /root/DialogueManager")
		return dm
		
	dm = get_node_or_null("../CanvasLayer/DialogueManager")
	if dm:
		print("Found DialogueManager at ../CanvasLayer/DialogueManager")
		return dm
		
	# Try to find it anywhere in the scene
	var potential_managers = get_tree().get_nodes_in_group("dialogue_manager")
	if potential_managers.size() > 0:
		print("Found DialogueManager via group")
		return potential_managers[0]
		
	# Not found, will need to be assigned later
	return null

# Check if player is in range
func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Player entered NPC range: " + npc_name)
		player = body
		in_range = true
		
		# Play reaction animation
		play_animation("react")
		
		# Check if the dialogue manager exists
		if not dialogue_manager:
			dialogue_manager = find_dialogue_manager()
		
		# Auto-trigger dialogue after short delay
		if not dialogue_cooldown:
			get_tree().create_timer(0.2).timeout.connect(func(): 
				if in_range and not dialogue_cooldown:
					print("Auto-triggering dialogue for: " + npc_name)
					show_dialogue()
			)

func _on_body_exited(body):
	if body.is_in_group("player"):
		print("Player exited NPC range: " + npc_name)
		player = null
		in_range = false
		
		# Return to default animation
		if not is_talking:
			play_animation(default_animation)

# Play a specific animation
func play_animation(anim_name: String):
	var animated_sprite = $AnimatedSprite2D
	if animated_sprite and sprite_frames and sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		current_animation = anim_name
		print("NPC " + npc_name + " playing animation: " + anim_name)

# Show dialogue from the NPC - special first time or random from list
func show_dialogue():
	if dialogue_manager == null:
		dialogue_manager = find_dialogue_manager()
		
	if dialogue_manager and not dialogue_cooldown:
		print("Showing dialogue for: " + npc_name)
		# Set cooldown to prevent dialogue spam
		dialogue_cooldown = true
		
		# Start talking animation
		is_talking = true
		play_animation("talk")
		
		var dialogue_text = ""
		
		# Check if this is the first interaction and use first-time dialogue
		if not has_shown_first_dialogue and first_time_dialogue.strip_edges() != "":
			dialogue_text = first_time_dialogue
			has_shown_first_dialogue = true
			# Save the state after first dialogue is shown
			_save_npc_state()
			print("Showing FIRST-TIME dialogue for: " + npc_name + " - " + first_time_dialogue)
		# Otherwise, pick a random dialogue from the list
		elif dialogues.size() > 0:
			dialogue_text = dialogues[randi() % dialogues.size()]
			print("Selected random dialogue: " + dialogue_text)
		else:
			# Fallback if no regular dialogues
			dialogue_text = "..."
			print("No dialogues available for NPC: " + npc_name)
		
		# Display the dialogue with NPC info
		if dialogue_manager.has_method("show_dialogue"):
			print("Calling dialogue_manager.show_dialogue()")
			dialogue_manager.show_dialogue(npc_name, dialogue_text, portrait_texture)
			
			# Connect to dialogue hidden signal if available and not already connected
			if dialogue_manager.has_signal("dialogue_hidden") and not dialogue_manager.is_connected("dialogue_hidden", _on_dialogue_hidden):
				dialogue_manager.connect("dialogue_hidden", _on_dialogue_hidden)
		else:
			print("ERROR: dialogue_manager doesn't have show_dialogue method!")
			# End talking state after a delay
			get_tree().create_timer(2.0).timeout.connect(func(): is_talking = false)
		
		# Stop player movement during dialogue
		if player and player.has_method("set_can_move"):
			player.set_can_move(false)
		
		# Reset cooldown after a delay
		get_tree().create_timer(2.0).timeout.connect(func(): dialogue_cooldown = false)
	elif not dialogue_manager:
		print("ERROR: dialogue_manager is null when trying to show dialogue!")

# Called when dialogue is hidden
func _on_dialogue_hidden():
	print("Dialogue ended for " + npc_name)
	is_talking = false
	
	# Return to react animation if player is still nearby, or idle if not
	if in_range:
		play_animation("react")
	else:
		play_animation(default_animation)

# Save NPC state to persistent storage
func _save_npc_state():
	# Make sure we have access to the global save data
	_ensure_global_save_manager()
	
	if save_data and "dialogue_states" in save_data:
		# Get unique NPC ID
		var npc_id = _get_npc_id()
		
		# Save to in-memory store
		save_data["dialogue_states"][npc_id] = has_shown_first_dialogue
		
		# Also save to disk
		_save_to_disk()
		
		print("Saved dialogue state for " + npc_name + ": " + str(has_shown_first_dialogue))

# Load NPC state from persistent storage
func _load_npc_state():
	# Make sure we have access to the global save data
	_ensure_global_save_manager()
	
	# Default state - hasn't shown first dialogue yet
	has_shown_first_dialogue = false
	
	# Get unique NPC ID
	var npc_id = _get_npc_id()
	
	if save_data and save_data.has("dialogue_states"):
		# Check if we have saved state for this NPC
		if npc_id in save_data["dialogue_states"]:
			has_shown_first_dialogue = save_data["dialogue_states"][npc_id]
			print("Loaded dialogue state for " + npc_name + ": " + str(has_shown_first_dialogue))
		else:
			print("No saved dialogue state for " + npc_name + ", using default (false)")
	
	# Also try loading from disk if memory store is empty
	if save_data and save_data.has("dialogue_states") and save_data["dialogue_states"].is_empty():
		_load_from_disk()
		
		# Check again after loading from disk
		if save_data.has("dialogue_states") and npc_id in save_data["dialogue_states"]:
			has_shown_first_dialogue = save_data["dialogue_states"][npc_id]
			print("Loaded dialogue state from disk for " + npc_name + ": " + str(has_shown_first_dialogue))

# Get a unique identifier for this NPC
func _get_npc_id() -> String:
	# Create a case-sensitive, unique ID by replacing spaces with underscores
	# This ensures "Villager", "Farmer", etc. all get separate IDs
	return npc_name

# Save all NPC states to disk
func _save_to_disk():
	var config = ConfigFile.new()
	var save_path = "user://npc_states.cfg"
	
	# First try to load existing file if it exists
	if FileAccess.file_exists(save_path):
		var err = config.load(save_path)
		if err != OK and err != ERR_FILE_NOT_FOUND:
			print("Error loading NPC save file: ", err)
	
	# Save all the in-memory NPC states to disk
	if "dialogue_states" in save_data:
		for npc_id in save_data["dialogue_states"]:
			config.set_value("npc_dialogues", npc_id, save_data["dialogue_states"][npc_id])
	
	# Write the file
	var err = config.save(save_path)
	if err != OK:
		print("Error saving NPC states: ", err)
	else:
		print("NPC dialogue states saved to disk")

# Load all NPC states from disk
func _load_from_disk():
	var config = ConfigFile.new()
	var save_path = "user://npc_states.cfg"
	
	# Check if file exists
	if not FileAccess.file_exists(save_path):
		print("No NPC save file found")
		return
	
	# Load the file
	var err = config.load(save_path)
	if err != OK:
		print("Error loading NPC save file: ", err)
		return
	
	# Make sure our data structure is initialized
	if not save_data.has("dialogue_states"):
		save_data["dialogue_states"] = {}
	
	# Read all the saved NPC states
	var section_keys = config.get_section_keys("npc_dialogues")
	for npc_id in section_keys:
		var dialogue_shown = config.get_value("npc_dialogues", npc_id, false)
		save_data["dialogue_states"][npc_id] = dialogue_shown
		print("Loaded from disk: " + npc_id + " = " + str(dialogue_shown))

# Function to reset this NPC's dialogue state (call from inspector for testing)
func reset_dialogue_state():
	has_shown_first_dialogue = false
	
	# Also update the persistent storage
	_ensure_global_save_manager()
	
	if save_data and "dialogue_states" in save_data:
		var npc_id = _get_npc_id()
		save_data["dialogue_states"][npc_id] = false
		_save_to_disk()
	
	print("*** RESET DIALOGUE STATE FOR: " + npc_name + " ***")

# Function you can call directly from the Inspector for testing
func test_first_time_dialogue():
	print("*** TESTING FIRST TIME DIALOGUE FOR: " + npc_name + " ***")
	
	# Force reset this NPC's dialogue state
	has_shown_first_dialogue = false
	
	# Trigger dialogue immediately
	if not is_talking and not dialogue_cooldown:
		show_dialogue()
	
	# Let the user know how to set this up permanently
	print("TIP: To make this permanent, call reset_dialogue_state()")

# Static function to reset ALL NPC dialogue states
static func reset_all_dialogue_states():
	# Delete the save file
	var save_path = "user://npc_states.cfg"
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(save_path)
			print("*** ALL NPC DIALOGUE STATES RESET ***")
			
	# Note: Each NPC will reset its own state when it loads next time
