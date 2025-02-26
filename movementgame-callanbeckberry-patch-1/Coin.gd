extends Area2D

func _ready():
	# Connect the body_entered signal to _on_body_entered using a Callable.
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	# Check if the colliding body has the add_coin() method.
	if body.has_method("add_coin"):
		body.add_coin()
		queue_free()  # Remove the coin from the scene.
