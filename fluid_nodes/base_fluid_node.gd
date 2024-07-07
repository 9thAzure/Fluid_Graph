@tool
extends Node2D
class_name BaseFluidNode

var parent_graph : FluidGraph = null

@export 
var node_size := 10.0:
	set(value):
		node_size = value
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, node_size, Color.WHITE)

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
	if parent_graph.controlled_update:
		await parent_graph.fluid_update
	if not is_queued:
		return # this means the method was called already during the delay time.
	is_queued = false
	update()

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

func update() -> void:
	is_queued = false
	_update()

func _update() -> void:
	sort_connections()

	var flow_rate := 0.0
	var size := connections.size()
	var input_flow_friction := 0.0
	for i in connections_input_output_divider:
		var connection := connections[i]
		var split_flow_rate := flow_rate / (size - i)

		var ingoing_flow_rate := -connection.get_relative_flow_rate(self)
		var ingoing_pressure := ingoing_flow_rate + connection.flow_friction
		if ingoing_pressure >= split_flow_rate: # inflowing flows are negative
			flow_rate += ingoing_flow_rate 
			# unaccounted_backflow_friction += connection.flow_friction
			input_flow_friction += connection.flow_friction
			continue
		
		# ingoing flow that is less thant split_flow_rate
		split_flow_rate -= ingoing_pressure
		connection.flow_friction = ingoing_pressure
		connection.set_relative_flow_rate(self, split_flow_rate)
		flow_rate -= split_flow_rate
		connection.get_connecting_node(self).queue_update()

	# TODO: testing, may not be necessary
	# var friction_from_backflow := connections[-1].flow_friction
	var expected_input_flow_friction := connections[-1].flow_friction * (connections.size() - connections_input_output_divider)

	# friction_from_backflow *= input_flow_friction / expected_input_flow_friction

	var difference := expected_input_flow_friction - input_flow_friction
	extra_flow_rate = 0
	if not is_zero_approx(difference):
		extra_flow_rate = difference
		flow_rate -= difference
		input_flow_friction += difference

	# friction_from_backflow = input_flow_friction / (connections.size() - connections_input_output_divider)
	var friction_from_backflow = input_flow_friction / (connections.size() - connections_input_output_divider)
	
	for i in size - connections_input_output_divider:
		var index := connections_input_output_divider + i
		var connection := connections[index]
		var split_flow_rate := flow_rate / (size - index)

		split_flow_rate -= maxf(connection.flow_friction - friction_from_backflow, 0)
		connection.set_relative_flow_rate(self, split_flow_rate)
		flow_rate -= split_flow_rate
		connection.get_connecting_node(self).queue_update()

	extra_flow_rate += flow_rate
	if not is_zero_approx(extra_flow_rate):
		_handle_backflow()
		return
	
	if expected_input_flow_friction < input_flow_friction:
		_request_more_flow()
	
func _handle_backflow() -> void:
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

func _request_more_flow() -> void:
	for i in connections_input_output_divider:
		var connection := connections[i]
		if is_zero_approx(connection.flow_friction):
			continue
		
		connection.flow_friction = 0
		connection.get_connecting_node(self).queue_update()
