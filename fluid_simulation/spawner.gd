extends Node2D

const ball_scene := preload("res://fluid_simulation/ball.tscn")

@export_range(0, 10, 0.01, "or_greater","hide_slider")
var spawn_rate := 10.0

@export_range(0, 10, 0.01, "or_greater","hide_slider")
var spawn_force := 10.0

var idle_elapsed := 0.0
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	idle_elapsed += delta
	var spawn_delta := 1 / spawn_rate
	while idle_elapsed > spawn_delta:
		idle_elapsed -= spawn_delta
		var ball := ball_scene.instantiate()
		add_child(ball)
		ball.apply_impulse(Vector2(cos(PI * randf()), cos(PI * randf())) * spawn_force * randf())
