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

var connections_input_output_divider := -1

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

# functions have to be sorted first input, then output
#   input: ingoing flow rate (- relative flow)
#     - has to further be sorted from largest relative flow rate to smallest relative flow rate
#  output: other flow rate
#     - further sorted from largest friction to smallest

# if true, a and b is sorted
func _custom_connection_comparer(a : FluidConnection, b : FluidConnection) -> bool:
	var flow_rate_a := a.get_relative_flow_rate(self)
	var flow_rate_b := b.get_relative_flow_rate(self)

	var a_is_input := flow_rate_a < 0
	var b_is_input := flow_rate_b < 0

	if a_is_input and not b_is_input:
		return true
	if b_is_input and not a_is_input:
		return false
	
	if a_is_input and b_is_input:
		return flow_rate_a < flow_rate_b # ingoing flow rates are negative, so in actuality, checking that flow_rate_a is greater
	
	# both a and b are not input connections
	return a.flow_friction > b.flow_friction

func sort_connections() -> void:
	connections.sort_custom(_custom_connection_comparer)
	for i in connections.size():
		if connections[i].get_relative_flow_rate(self) >= 0.0:
			connections_input_output_divider = i
			return
	connections_input_output_divider = connections.size()

func _update() -> void:
	is_queued = false
	sort_connections()
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
		
		connection.get_connecting_node(self).queue_update()
	
	extra_flow_rate = outflowing_rate
	if is_zero_approx(outflowing_rate):
		return
	
	handle_backflow()
	
func handle_backflow() -> void:
	# to handle backflow, input sources have to be capped
	# 2 options as I see it, we stop flow of a pipe one by one or slow down all of them. Going with the second option
	var inflowing_pressure := 0.0
	var inflowing_connections : Array[FluidConnection] = []
	for connection in connections:
		var flow := connection.get_relative_flow_rate(self)
		if flow >= 0.0:
			continue

		inflowing_connections.append(connection)
		inflowing_pressure += -flow + connection.flow_friction
	
	var friction_multiplier := extra_flow_rate / inflowing_pressure
	for connection in inflowing_connections:
		var pressure := absf(connection.flow_rate) + connection.flow_friction
		connection.flow_friction = pressure * friction_multiplier
		connection.set_relative_flow_rate(self, -(pressure - connection.flow_friction))
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
