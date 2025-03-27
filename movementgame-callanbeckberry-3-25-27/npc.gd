extends Area2D

class_name NPC

# Basic NPC properties
@export var npc_name: String = "Villager"
@export var portrait_texture: Texture2D
@export var interaction_distance: float = 50.0
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

# Called when the node enters the scene tree for the first time
func _ready():
	add_to_group("npcs")
	
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

# Show a random dialogue from the NPC
func show_dialogue():
	if dialogue_manager == null:
		dialogue_manager = find_dialogue_manager()
		
	if dialogue_manager and dialogues.size() > 0 and not dialogue_cooldown:
		print("Showing dialogue for: " + npc_name)
		# Set cooldown to prevent dialogue spam
		dialogue_cooldown = true
		
		# Start talking animation
		is_talking = true
		play_animation("talk")
		
		# Pick a random dialogue
		var random_dialogue = dialogues[randi() % dialogues.size()]
		print("Selected dialogue: " + random_dialogue)
		
		# Display the dialogue with NPC info
		if dialogue_manager.has_method("show_dialogue"):
			print("Calling dialogue_manager.show_dialogue()")
			dialogue_manager.show_dialogue(npc_name, random_dialogue, portrait_texture)
			
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
	elif dialogues.size() == 0:
		print("ERROR: No dialogues available for NPC: " + npc_name)

# Called when dialogue is hidden
func _on_dialogue_hidden():
	print("Dialogue ended for " + npc_name)
	is_talking = false
	
	# Return to react animation if player is still nearby, or idle if not
	if in_range:
		play_animation("react")
	else:
		play_animation(default_animation)
