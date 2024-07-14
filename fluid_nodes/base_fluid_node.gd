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

# var connections_input_output_divider := -1
var blocked_connection_index := -1
var output_connection_index := -1

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
#  input: ingoing flow rate (- relative flow)
#    - has to further be sorted from largest relative pressure to smallest relative pressure
#  blocked (allowed_flow_rate == 0):
#    - further sorted by pressure, largest to smallest (like inputs)
#    - this has overlap with both other types of connections
#  output: other flow rate
#    - further sorted from Smallest allowed flow to largest

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
	
	if a_is_input and b_is_input\
		or is_zero_approx(a.allowed_flow_rate) and is_zero_approx(b.allowed_flow_rate):
		return (-flow_rate_a + a.flow_pressure + a.source_pressure) > (-flow_rate_b + b.flow_pressure + b.source_pressure) # ingoing flow rates are negative
	
	# both a and b are not input connections nor blocked connections
	return a.allowed_flow_rate < b.allowed_flow_rate

func sort_connections() -> void:
	connections.sort_custom(_custom_connection_comparer)
	var size := connections.size()
	blocked_connection_index = size
	output_connection_index = size
	for i in size:
		if connections[i].get_relative_flow_rate(self) >= 0.0:
			blocked_connection_index = i
			break

	for i in size - blocked_connection_index:
		var index := i + blocked_connection_index
		if is_zero_approx(connections[index].allowed_flow_rate):
			output_connection_index = index


func push_back_overridden_flows(start_i : int, length : int) -> void:
	# the order that the pushed back connections don't matter

	var size := connections.size()
	for i1 in length:
		var index1 := start_i + i1
		var pushed_back_connection := connections[index1]
		index1 += length
		while index1 < size:
			connections[index1 - length] = connections[index1]
			index1 += length
		connections[index1 - length] = pushed_back_connection

func update() -> void:
	is_queued = false
	_update()

func _update() -> void:
	sort_connections()

	var flow_rate := 0.0
	var size := connections.size()
	var flow_pressure := 0.0
	var source_pressure := 0.0
	var input_restricts_flow := false
	for i in connections_input_output_divider:
		var connection := connections[i]
		var divider := size - i
		var split_flow_rate := flow_rate / divider
		var split_pressure := split_flow_rate + flow_pressure / divider + source_pressure / divider

		var ingoing_flow_rate := -connection.get_relative_flow_rate(self)
		var ingoing_pressure := ingoing_flow_rate + connection.flow_pressure + connection.source_pressure
		if ingoing_pressure < split_pressure:
			push_back_overridden_flows(i)
			connections_input_output_divider = i
			break

		flow_rate += ingoing_flow_rate 
		flow_pressure += connection.flow_pressure
		source_pressure += connection.source_pressure
		input_restricts_flow = input_restricts_flow or connection.allowed_flow_rate < connection.max_flow_rate # no or-assignment :(

	# TODO: testing, may not be necessary
	# var friction_from_backflow := connections[-1].flow_friction
	# var expected_input_flow_friction := connections[-1].flow_friction * (connections.size() - connections_input_output_divider)

	# friction_from_backflow *= input_flow_friction / expected_input_flow_friction

	# var difference := expected_input_flow_friction - input_flow_friction
	current_flow_rate = flow_rate
	extra_flow_rate = 0
	# if not is_zero_approx(difference):
	# 	extra_flow_rate = difference
	# 	flow_rate -= difference
	# 	input_flow_friction += difference

	# friction_from_backflow = input_flow_friction / (connections.size() - connections_input_output_divider)
	# var friction_from_backflow = input_flow_friction / (connections.size() - connections_input_output_divider)
	var output_flow_below_limit := false
	for i in size - connections_input_output_divider:
		var index := connections_input_output_divider + i
		var connection := connections[index]
		var split_flow_rate := flow_rate / (size - index)

		connection.flow_pressure = flow_pressure / (size - connections_input_output_divider)
		connection.source_pressure = source_pressure / (size - connections_input_output_divider)
		if split_flow_rate > connection.allowed_flow_rate:
			connection.flow_pressure += split_flow_rate - connection.allowed_flow_rate
			split_flow_rate = connection.allowed_flow_rate
		elif input_restricts_flow and split_flow_rate < connection.allowed_flow_rate:
			output_flow_below_limit = true
		
		connection.set_relative_flow_rate(self, split_flow_rate)
		flow_rate -= split_flow_rate
		connection.get_connecting_node(self).queue_update()

	extra_flow_rate += flow_rate
	if not is_zero_approx(extra_flow_rate):
		_handle_backflow()
		return
	
	if output_flow_below_limit:
		_request_more_flow()
	
func _handle_backflow() -> void:
	# Try to override completely blocked flows, if their pressure is different from attempted pressure flow
	# we would have to reconstruct the initial scenario. Multiple blocked flows will be an issue without changing sorting

	# to handle backflow, input sources have to be capped
	# 2 options as I see it, we stop flow of a pipe one by one or slow down all of them. Going with the second option
	
	# var current_flow_rate := 0.0
	var inflowing_flow_pressure := 0.0
	for i in connections_input_output_divider:
		var connection := connections[i]
		inflowing_flow_pressure += connection.flow_pressure

	inflowing_flow_pressure += current_flow_rate
	
	var proportion_pressure_as_limit := (current_flow_rate - extra_flow_rate) / inflowing_flow_pressure
	for i in connections_input_output_divider:
		var connection := connections[i]
		var flow := connection.get_relative_flow_rate(self)
		if flow >= 0.0:
			continue

		var pressure = -flow + connection.flow_pressure
		connection.allowed_flow_rate = pressure * proportion_pressure_as_limit
		connection.set_relative_flow_rate(self, -pressure * proportion_pressure_as_limit)
		connection.flow_pressure = pressure - connection.allowed_flow_rate
		connection.get_connecting_node(self).queue_update()

func _request_more_flow() -> void:
	# TODO: reimplement better, by knowing amount to reduce allowed_flow_rate by.
	for i in connections_input_output_divider:
		var connection := connections[i]
		if connection.get_relative_flow_rate(self) > 0 or is_equal_approx(connection.allowed_flow_rate, connection.max_flow_rate):
			continue
		
		connection.reset_allowed_flow_rate()
		connection.get_connecting_node(self).queue_update()
