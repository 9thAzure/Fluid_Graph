@tool
extends Node2D
class_name BaseFluidNode

var parent_graph : FluidGraph = null

@export 
var size := 10.0:
	set(value):
		size = value
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, size, Color.WHITE)
	for node in connections:
		if node == null:
			continue
		draw_line(Vector2.ZERO, node.global_position - global_position, Color(1, 1, 1, 0.5), 1)

@export
var connections : Array[FluidConnection] = []

var previous_position := position
func _process(_delta) -> void:
	if position.is_equal_approx(previous_position):
		return

	previous_position = position
	for connection in connections:
		connection.queue_redraw()

var current_flow_rate := 0.0
var extra_flow_rate := 0.0

var is_queued := false
func queue_update() -> void:
	if is_queued:
		return
	
	is_queued = true
	await get_tree().process_frame
	if not is_queued:
		return # this means the method was called already during the delay time.
	is_queued = false
	_update()

func _update() -> void:
	is_queued = false
	# var inflowing_rate := _get_ingoing_flow_rate()
	var inflowing_connections : Array[FluidConnection] = []
	var outflowing_connections : Array[FluidConnection] = []
	var inflowing_rate := 0.0
	for connection in connections:
		var rate := connection.get_relative_flow_rate(self)
		if rate < 0:
			inflowing_rate += -rate
			inflowing_connections.append(connection)
		else:
			outflowing_connections.append(connection)

	outflowing_connections.sort_custom(func(a : FluidConnection, b : FluidConnection): return a.flow_friction > b.flow_friction)

	var outflowing_rate := inflowing_rate
	if outflowing_rate == 0.0:
		return

	var array_size := outflowing_connections.size()
	for i in array_size:
		var connection := connections[i]
		var sub_outflowing_rate := outflowing_rate / (array_size - i)
		sub_outflowing_rate -= connection.flow_friction

		connection.set_relative_flow_rate(self, sub_outflowing_rate)
		outflowing_rate -= sub_outflowing_rate
		# if sub_outflowing_rate < connection.max_flow_rate:
		# 	connection.set_relative_flow_rate(self, sub_outflowing_rate)
		# 	outflowing_rate -= sub_outflowing_rate
		# else:
		# 	connection.set_relative_flow_rate(self, connection.max_flow_rate)
		# 	outflowing_rate -= connection.max_flow_rate
		
		connection.get_connecting_node(self).queue_update()
	
	extra_flow_rate = outflowing_rate
	if is_zero_approx(outflowing_rate):
		return
	
	# TODO: handle backflow
	
	# to handle backflow, input sources have to be capped
	# 2 options as I see it, we stop flow of a pipe one by one or slow down all of them. Going with the second option

	var friction_multiplier := extra_flow_rate / inflowing_rate
	for connection in inflowing_connections:
		connection.flow_friction = abs(connection.flow_rate) * friction_multiplier
		connection.set_relative_flow_rate(self, connection.get_relative_flow_rate(self) + connection.flow_friction)
		connection.get_connecting_node(self).queue_update()

func _get_ingoing_flow_rate() -> float:
	var total := 0.0
	for connection in connections:
		total += max(0, -connection.get_relative_flow_rate(self))
	return total

func set_max_flow_rate() -> void:
	for connection in connections:
		var connected_node := connection.get_connecting_node(self)
		if connected_node is BaseConsumer:
			connection.set_relative_max_flow_rate(self, connected_node.consumption_rate)
