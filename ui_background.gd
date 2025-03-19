extends Sprite2D

var player = null

func _ready():
	# Find and connect to the player
	call_deferred("_find_and_connect_player")

func _find_and_connect_player():
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Try to find the player in the scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("UIBackground connected to player: ", player.name)
		
		# Connect to player's battle signals
		if not player.is_connected("battle_started", _on_battle_started):
			player.connect("battle_started", _on_battle_started)
		if not player.is_connected("battle_ended", _on_battle_ended):
			player.connect("battle_ended", _on_battle_ended)
	else:
		push_warning("UIBackground could not find a player node in the 'player' group.")
		# Try again in a moment
		await get_tree().create_timer(1.0).timeout
		_find_and_connect_player()

func _on_battle_started():
	print("UIBackground hiding for battle")
	visible = false

func _on_battle_ended():
	print("UIBackground showing after battle")
	visible = true
