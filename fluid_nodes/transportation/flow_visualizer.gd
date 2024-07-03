extends Node2D
# const FluidConnection := preload("res://fluid_nodes/transportation/fluid_connection.gd")

@export
var connection : FluidConnection = null

@export
var speed := 1.0

var scaling_factor := 1.0

func _draw() -> void:
	var rect := Rect2(-10, -5, 20, 10)
	draw_rect(rect, Color.CYAN)

var t := 0.5

func _ready() -> void:
	if connection == null:
		set_process(false)
		return
	if not connection.is_complete():
		set_process(false)
		return
	
	scaling_factor = 1 / (connection.node1.position - connection.node2.position).length()
	rotation = connection.node1.position.angle_to(connection.node2.position)
	set_process(true)

func _process(delta: float) -> void:
	t += delta * speed * connection.flow_rate * scaling_factor
	t = wrapf(t, 0.0, 1.1)

	position = lerp(connection.node1.position, connection.node2.position, t)




