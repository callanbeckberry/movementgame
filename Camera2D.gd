extends Camera2D

var room_size : int = 512  # Each room is 512x512 pixels
var smoothing_time : float = 0.25  # Lower value means faster transition
var target_position : Vector2

func _ready():
	# Initialize target_position as the current position.
	target_position = global_position
	make_current()  # Make sure this camera is active.
	print("Camera ready. Initial position: ", global_position)

func _process(delta: float) -> void:
	# Find the player node (adjust the path if necessary)
	var player = get_node_or_null("../Player")
	if player:
		# Calculate room indices by dividing player's global position by room_size.
		var room_x = floor(player.global_position.x / room_size)
		var room_y = floor(player.global_position.y / room_size)
		# Calculate the center of that room.
		target_position = Vector2((room_x + 0.5) * room_size, (room_y + 0.5) * room_size)
		# Debug: Uncomment to check calculated centers:
		# print("Calculated room center: ", target_position)
	
	# Smoothly interpolate from current camera position toward the target room center.
	global_position = global_position.lerp(target_position, delta / smoothing_time)

