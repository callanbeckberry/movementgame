extends StaticBody2D

var tile_position: Vector2i
var tile_map = null
var is_unlocked = false
var required_coins = 120  # Should match total_coins in Player.gd

func _ready():
	add_to_group("final_boss_door")
	
	# Setup visuals to indicate this is a special door
	if not has_node("Sprite2D") or get_node("Sprite2D").texture == null:
		create_debug_visual()

func setup(tilemap_ref, door_tile_position):
	tile_map = tilemap_ref
	tile_position = door_tile_position
	
	# Position the door at the center of the tile
	if tile_map and tile_map.tile_set:
		var tile_size = tile_map.tile_set.tile_size
		global_position = tile_map.map_to_local(tile_position) + Vector2(tile_size.x / 2, tile_size.y / 2)
		print("Final boss door positioned at: ", global_position, " (Tile: ", tile_position, ")")
	else:
		print("Warning: TileMap not provided or invalid for final boss door setup")

func unlock():
	if is_unlocked:
		return
		
	is_unlocked = true
	print("Final boss door unlocked!")
	
	# Remove collision
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	# Update tilemap if available
	if tile_map and tile_position:
		var walkable_tile_index = 1  # Replace with your walkable tile index
		tile_map.set_cell(0, tile_position, walkable_tile_index)
	
	# Play special animation/sound for final door
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(2, 2, 2, 1), 0.5)  # Bright flash
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.0)  # Fade out
	await tween.finished
	
	# Remove the door
	queue_free()

func _process(delta):
	# Optional: Add some visual effect to make the final door stand out
	if not is_unlocked:
		# Pulsating effect
		var pulse = (sin(Time.get_ticks_msec() * 0.003) + 1) * 0.5  # 0 to 1 pulsating value
		modulate = Color(1.0, 0.5 + pulse * 0.5, 0.5 + pulse * 0.5)  # Pulsate between normal and more intense

func create_debug_visual():
	# Create a distinctive door sprite
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	
	# Create a door texture with special appearance
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	
	# Fill with a special color (purple/gold for final door)
	var door_color = Color(0.6, 0.2, 0.8)  # Purple
	var highlight_color = Color(1.0, 0.8, 0.2)  # Gold
	var dark_color = Color(0.3, 0.1, 0.4)  # Dark purple
	
	# Fill background
	img.fill(door_color)
	
	# Add border
	for x in range(32):
		for y in range(32):
			if x < 2 or x > 29 or y < 2 or y > 29:
				img.set_pixel(x, y, dark_color)
	
	# Add decorative elements - diagonal cross
	for i in range(32):
		if i > 2 and i < 29:
			img.set_pixel(i, i, highlight_color)
			img.set_pixel(i, 31-i, highlight_color)
	
	# Add central emblem
	for x in range(12, 20):
		for y in range(12, 20):
			if (x == 12 or x == 19 or y == 12 or y == 19):
				img.set_pixel(x, y, highlight_color)
	
	# Create a crown-like shape at the top
	for i in range(8):
		var x = 12 + i*1
		if i % 2 == 0:
			for y in range(4, 8):
				img.set_pixel(x, y, highlight_color)
		else:
			for y in range(2, 6):
				img.set_pixel(x, y, highlight_color)
	
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	add_child(sprite)
	
	# Also add a collision shape if missing
	if not has_node("CollisionShape2D"):
		var collision = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(32, 32)
		collision.shape = rect_shape
		add_child(collision)
	
	# Add a label indicating this is the final door
	var label = Label.new()
	label.text = "FINAL"
	label.position = Vector2(-20, -40)
	label.modulate = Color(1, 0.8, 0.2)  # Gold text
	add_child(label)
	
	print("Created debug final boss door visuals")
