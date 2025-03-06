extends Node2D

# Define each room's data.
# Rooms are arranged in three rows of four:
# Base row (row 1): centers at (0,0), (512,0), (1024,0), (1536,0)
# Row 2 (above): centers at (0,-512), (512,-512), (1024,-512), (1536,-512)
# Row 3 (top row): centers at (0,-1024), (512,-1024), (1024,-1024), (1536,-1024)
@export var room_data: Array = [
	{ "bounds": Rect2(-256, -256, 512, 512) },      # Room 1: Center (0,0)
	{ "bounds": Rect2(256, -256, 512, 512) },       # Room 2: Center (512,0)
	{ "bounds": Rect2(768, -256, 512, 512) },       # Room 3: Center (1024,0)
	{ "bounds": Rect2(1280, -256, 512, 512) },      # Room 4: Center (1536,0)
	{ "bounds": Rect2(-256, -768, 512, 512) },      # Room 5: Center (0,-512)
	{ "bounds": Rect2(256, -768, 512, 512) },       # Room 6: Center (512,-512)
	{ "bounds": Rect2(768, -768, 512, 512) },       # Room 7: Center (1024,-512)
	{ "bounds": Rect2(1280, -768, 512, 512) },      # Room 8: Center (1536,-512)
	{ "bounds": Rect2(-256, -1280, 512, 512) },     # Room 9: Center (0,-1024)
	{ "bounds": Rect2(256, -1280, 512, 512) },      # Room 10: Center (512,-1024)
	{ "bounds": Rect2(768, -1280, 512, 512) },      # Room 11: Center (1024,-1024)
	{ "bounds": Rect2(1280, -1280, 512, 512) }      # Room 12: Center (1536,-1024)
]

# We'll use player's global position as-is.
@export var player_offset: Vector2 = Vector2.ZERO

@export var tile_size: int = 32  # Not used directly here, but useful for reference.

var current_room_data: Dictionary = {}

signal room_changed(new_room_center: Vector2)

func _ready() -> void:
	var player = get_node_or_null("../Player")
	if player:
		current_room_data = _find_room(player.global_position - player_offset)
		if current_room_data != {}:
			var center = current_room_data["bounds"].position + current_room_data["bounds"].size * 0.5
			emit_signal("room_changed", center)
			print("Initial room: ", current_room_data["bounds"], " Center: ", center)
		else:
			print("Warning: Player is not inside any defined room!")
	else:
		print("Warning: Player not found in RoomManager _ready()!")

func _process(delta: float) -> void:
	var player = get_node_or_null("../Player")
	if player:
		var effective_pos = player.global_position - player_offset
		var new_room_data = _find_room(effective_pos)
		if new_room_data != {} and new_room_data != current_room_data:
			current_room_data = new_room_data
			var center = current_room_data["bounds"].position + current_room_data["bounds"].size * 0.5
			print("Room changed to: ", current_room_data["bounds"], " Center: ", center)
			emit_signal("room_changed", center)

	else:
		print("Warning: Player not found in _process() of RoomManager.")

func _find_room(pos: Vector2) -> Dictionary:
	for data in room_data:
		var bounds: Rect2 = data["bounds"]
		if bounds.has_point(pos):
			return data
	return {}
