extends Node2D

# Define your rooms explicitly:
@export var rooms: Array[Rect2] = [
	Rect2(-224, -256, 512, 512),   # Room 1 boundaries: covers x from -224 to 288.
	Rect2(288, -256, 512, 512)      # Room 2 boundaries: covers x from 288 to 800.
]

# Set player_offset to (0,0) so that effective position equals global position.
@export var player_offset: Vector2 = Vector2(0, 0)

# We'll use a zero rectangle literal to represent "no room found."
var current_room: Rect2 = Rect2(0, 0, 0, 0)

signal room_changed(new_room_center: Vector2)

func _ready() -> void:
	var player = get_node_or_null("../Player")
	if player:
		current_room = _find_room(player.global_position - player_offset)
		if current_room != Rect2(0, 0, 0, 0):
			var center = current_room.position + current_room.size * 0.5
			emit_signal("room_changed", center)
			print("Initial room: ", current_room, " Center: ", center)
		else:
			print("Warning: Player is not inside any defined room!")
	else:
		print("Warning: Player not found in RoomManager _ready()!")

func _process(delta: float) -> void:
	var player = get_node_or_null("../Player")
	if player:
		# Effective position is player's global position (since offset is (0,0))
		var effective_pos = player.global_position - player_offset
		var new_room = _find_room(effective_pos)
		if new_room != Rect2(0, 0, 0, 0) and new_room != current_room:
			current_room = new_room
			var center = current_room.position + current_room.size * 0.5
			print("Room changed to: ", current_room, " Center: ", center)
			emit_signal("room_changed", center)
	else:
		print("Warning: Player not found in _process() of RoomManager.")

func _find_room(pos: Vector2) -> Rect2:
	for r in rooms:
		if r.has_point(pos):
			return r
	return Rect2(0, 0, 0, 0)
