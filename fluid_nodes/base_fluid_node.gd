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
#     - has to further be sorted from largest relative pressure to smallest relative pressure
#  output: other flow rate
#     - further sorted from Smallest allowed flow to largest

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
		return (-flow_rate_a + a.pressure) > (-flow_rate_b + b.pressure) # ingoing flow rates are negative
	
	# both a and b are not input connections
	return a.allowed_flow_rate < b.allowed_flow_rate

func sort_connections() -> void:
	connections.sort_custom(_custom_connection_comparer)
	for i in connections.size():
		if connections[i].get_relative_flow_rate(self) >= 0.0:
			connections_input_output_divider = i
			return
	connections_input_output_divider = connections.size()

func push_back_overridden_flows(start_i : int) -> void:
	var jump_distance := connections_input_output_divider - start_i

	@warning_ignore("integer_division")
	var jump_recursion_amount := (connections.size() - connections_input_output_divider) / jump_distance
	for i1 in jump_distance:
		var index1 := start_i + i1
		var connection := connections[start_i + i1]
		for i2 in jump_recursion_amount:
			var index2 := index1 + i2 * jump_distance
			connections[index2] = connections[index2 + jump_distance]
		
		connection.reset_allowed_flow_rate()
		connections[index1 + jump_recursion_amount * jump_distance] = connection


func update() -> void:
	is_queued = false
	_update()

func _update() -> void:
	sort_connections()

	var flow_rate := 0.0
	var size := connections.size()
	var isolated_pressure := 0.0
	var input_restricts_flow := false
	for i in connections_input_output_divider:
		var connection := connections[i]
		var split_flow_rate := flow_rate / (size - i)

		var ingoing_flow_rate := -connection.get_relative_flow_rate(self)
		var ingoing_pressure := ingoing_flow_rate + connection.pressure
		if ingoing_pressure < split_flow_rate:
			push_back_overridden_flows(i)
			connections_input_output_divider = i
			break

		flow_rate += ingoing_flow_rate 
		isolated_pressure += connection.pressure
		input_restricts_flow = input_restricts_flow or connection.allowed_flow_rate < connection.max_flow_rate # no or-assignment :(

	# TODO: testing, may not be necessary
	# var friction_from_backflow := connections[-1].flow_friction
	# var expected_input_flow_friction := connections[-1].flow_friction * (connections.size() - connections_input_output_divider)

	# friction_from_backflow *= input_flow_friction / expected_input_flow_friction

	# var difference := expected_input_flow_friction - input_flow_friction
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

		connection.pressure = isolated_pressure / (size - connections_input_output_divider)
		if split_flow_rate > connection.allowed_flow_rate:
			connection.pressure += split_flow_rate - connection.allowed_flow_rate
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
	# to handle backflow, input sources have to be capped
	# 2 options as I see it, we stop flow of a pipe one by one or slow down all of them. Going with the second option
	
	var inflowing_rate := 0.0
	var inflowing_pressure := 0.0
	for i in connections_input_output_divider:
		var connection := connections[i]
		var flow := connection.get_relative_flow_rate(self)
		if flow >= 0.0:
			continue

		inflowing_rate += -flow
		inflowing_pressure += connection.pressure
	inflowing_pressure += inflowing_rate
	
	var proportion_pressure_as_limit := (inflowing_rate - extra_flow_rate) / inflowing_pressure
	for i in connections_input_output_divider:
		var connection := connections[i]
		var flow := connection.get_relative_flow_rate(self)
		if flow >= 0.0:
			continue

		var pressure = -flow + connection.pressure
		connection.allowed_flow_rate = pressure * proportion_pressure_as_limit
		connection.set_relative_flow_rate(self, -pressure * proportion_pressure_as_limit)
		connection.pressure = pressure - connection.allowed_flow_rate
		connection.get_connecting_node(self).queue_update()

func _request_more_flow() -> void:
	# TODO: reimplement better, by knowing amount to reduce allowed_flow_rate by.
	for i in connections_input_output_divider:
		var connection := connections[i]
		if connection.get_relative_flow_rate(self) > 0 or is_equal_approx(connection.allowed_flow_rate, connection.max_flow_rate):
			continue
		
		connection.reset_allowed_flow_rate()
		connection.get_connecting_node(self).queue_update()
