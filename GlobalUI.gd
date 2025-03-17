extends CanvasLayer

# UI elements
@onready var time_label = $PersistentUI/TimeLabel
@onready var yen_label = $PersistentUI/YenLabel
@onready var timer = $Timer

# State tracking
var start_time = 0
var elapsed_seconds = 0
var yen_spent = 0
var x_press_count = 0
var debug_counter = 0  # For debugging timer functionality

func _ready():
	print("GlobalUI: _ready() called")
	
	# Initialize time tracking
	start_time = Time.get_unix_time_from_system()
	print("GlobalUI: Start time set to ", start_time)
	
	# Check if UI elements exist
	if time_label:
		print("GlobalUI: TimeLabel found")
		time_label.text = "Time: 00:00"
	else:
		print("ERROR: TimeLabel not found!")
		
	if yen_label:
		print("GlobalUI: YenLabel found")
		yen_label.text = "¥ 0 spent"
	else:
		print("ERROR: YenLabel not found!")
	
	# Ensure this UI stays on top
	layer = 100
	
	# Connect timer signal manually to ensure it's connected
	if timer:
		print("GlobalUI: Timer found")
		if not timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.connect(_on_timer_timeout)
			print("GlobalUI: Timer timeout signal connected manually")
		timer.wait_time = 1.0
		timer.start()
		print("GlobalUI: Timer started with interval", timer.wait_time)
	else:
		print("ERROR: Timer node not found!")

func _process(delta):
	# Check for X key press
	if Input.is_action_just_pressed("add_move"):
		add_yen(27)
		print("GlobalUI: X pressed, yen added")

	# Force timer update every 5 seconds for debugging
	debug_counter += delta
	if debug_counter >= 5.0:
		debug_counter = 0
		print("GlobalUI: 5 second debug update")
		update_time()
		print("GlobalUI: Current time label: ", time_label.text)

func _on_timer_timeout():
	print("GlobalUI: Timer timeout called")
	update_time()

func update_time():
	var current_time = Time.get_unix_time_from_system()
	elapsed_seconds = current_time - start_time
	print("GlobalUI: Current time: ", current_time)
	print("GlobalUI: Elapsed seconds: ", elapsed_seconds)
	
	# Format time as HH:MM with dynamic hour width
	var total_minutes = int(elapsed_seconds / 60)
	var hours = int(total_minutes / 60)
	var minutes = total_minutes % 60
	
	print("GlobalUI: Hours: ", hours, ", Minutes: ", minutes)
	
	# Format hours with proper width based on value
	var hours_str = ""
	if hours < 10:
		hours_str = "0" + str(hours) # 00-09 hours
	elif hours < 100:
		hours_str = str(hours)       # 10-99 hours
	elif hours < 1000:
		hours_str = str(hours)       # 100-999 hours
	else:
		hours_str = str(hours)       # 1000+ hours
	
	# Format minutes always as two digits
	var minutes_str = "%02d" % minutes
	
	var new_text = "Time: " + hours_str + ":" + minutes_str
	print("GlobalUI: Setting time label to: ", new_text)
	time_label.text = new_text

func add_yen(amount: int):
	yen_spent += amount
	x_press_count += 1
	yen_label.text = "¥ %d spent" % yen_spent
	print("GlobalUI: Yen updated to ", yen_spent)
	
	# Add a small animation effect
	var tween = create_tween()
	tween.tween_property(yen_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(yen_label, "scale", Vector2(1.0, 1.0), 0.1)
