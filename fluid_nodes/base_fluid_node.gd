@tool
extends Node2D
class_name BaseFluidNode

var parent_graph : FluidGraph = null

@export_range(0.0, 10.0, 0.01, "or_greater", "hide_slider")
var node_size := 10.0:
	set(value):
		node_size = value
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, node_size, Color.WHITE)

@export_range(0.0, 10.0, 0.01, "or_greater", "hide_slider")
var capacity :=  500

var stored_amount := 0.0

var extra_flow_rate := 0.0

## Emitted when stored liquid has met capacity.
signal reached_capacity()

@export
var connections : Array[FluidConnection] = []

# var connections_input_output_divider := -1
var blocked_connection_index := -1
var output_connection_index := -1

var current_flow_rate := 0.0
var current_flow_pressure := 0.0
var current_source_pressure := 0.0

func _ready() -> void:
	reached_capacity.connect(_on_overflow)
	var meter := preload("res://fluid_nodes/drawers/capacity/storage_display.tscn").instantiate()
	meter.fluid_node = self
	add_child(meter)

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

	var connection_type_a := get_connection_type(a)
	var connection_type_b := get_connection_type(b)

	if connection_type_a != connection_type_b:
		return connection_type_a < connection_type_b

	# both connections are the same type here.
	if connection_type_a == 2: # output connection
		return a.allowed_flow_rate < b.allowed_flow_rate

	return (-flow_rate_a + a.flow_pressure + a.source_pressure) > (-flow_rate_b + b.flow_pressure + b.source_pressure) # ingoing flow rates are negative


# 0 = input connection, 1 = blocked connection, 2 = output connection.
func get_connection_type(connection : FluidConnection) -> int:
	if connection.get_relative_flow_rate(self) < 0:
		return 0
	elif is_zero_approx(connection.allowed_flow_rate):
		return 1
	return 2

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
		if not is_zero_approx(connections[index].allowed_flow_rate):
			output_connection_index = index
			break


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
		pushed_back_connection.reset_allowed_flow_rate()
		connections[index1 - length] = pushed_back_connection
	
	if start_i < blocked_connection_index:
		blocked_connection_index = maxi(start_i, blocked_connection_index - length)
	if start_i < output_connection_index:
		output_connection_index = maxi(start_i, output_connection_index - length)

func is_input_restricting_flow() -> bool:
	for i in blocked_connection_index:
		var connection := connections[i]
		if connection.allowed_flow_rate < connection.max_flow_rate:
			return true
	return false

func _process(delta : float) -> void:
	process_extra_flow(delta)

func process_extra_flow(delta : float) -> void:
	if is_zero_approx(extra_flow_rate):
		return

	if extra_flow_rate > 0.0:
		if stored_amount >= capacity:
			return

		stored_amount += extra_flow_rate * delta
		if stored_amount >= capacity:
			stored_amount = capacity
			reached_capacity.emit()
		return

	if stored_amount <= 0.0:
		return

	stored_amount += extra_flow_rate * delta
	if stored_amount <= 0:
		stored_amount = 0
		# TODO: emit some equivalent to signal 'reached_capacity'.
	return


func update() -> void:
	is_queued = false
	_update()

func _update() -> void:
	sort_connections()

	_update_inputs()
	_update_outputs()

func _update_inputs() -> void:
	var size := connections.size()
	current_flow_rate = 0
	current_flow_pressure = 0
	current_source_pressure = 0
	for i in blocked_connection_index: # input_connections
		var connection := connections[i]
		var divider := size - (output_connection_index - blocked_connection_index) - i
		var split_flow_rate := current_flow_rate / divider
		var split_pressure := split_flow_rate + current_flow_pressure / divider + current_source_pressure / divider

		var ingoing_flow_rate := -connection.get_relative_flow_rate(self)
		var ingoing_pressure := ingoing_flow_rate + connection.flow_pressure + connection.source_pressure
		if ingoing_pressure < split_pressure:
			var length := blocked_connection_index - i
			push_back_overridden_flows(i, length)
			break
		
		if is_equal_approx(ingoing_pressure, split_pressure):
			connection.flow_pressure += abs(connection.flow_rate)
			connection.flow_rate = 0
			connection.allowed_flow_rate = 0
			connection.queue_update_connected_node(self)
			if blocked_connection_index > i:
				blocked_connection_index = i
			continue

		current_flow_rate += ingoing_flow_rate 
		current_flow_pressure += connection.flow_pressure
		current_source_pressure += connection.source_pressure
	
func _update_outputs() -> void:
	# TODO: convert extra_current_pressure into source_pressure, such that flow_rate + flow_pressure <= max_flow_rate is true. This simplifies '_request_more_flow'
	var size := connections.size()
	var deficit_flow_rate := 0.0
	var flow_rate := current_flow_rate
	var split_flow_pressure := current_flow_pressure / (size - output_connection_index)
	var split_source_pressure := current_source_pressure / (size - output_connection_index)
	for i in size - output_connection_index:
		var index := output_connection_index + i
		var connection := connections[index]
		var split_flow_rate := flow_rate / (size - index)

		connection.flow_pressure = split_flow_pressure
		connection.source_pressure = split_source_pressure
		if split_flow_rate > connection.allowed_flow_rate:
			connection.flow_pressure += split_flow_rate - connection.allowed_flow_rate
			split_flow_rate = connection.allowed_flow_rate
		elif split_flow_rate < connection.allowed_flow_rate:
			deficit_flow_rate += connection.allowed_flow_rate - split_flow_rate
		
		connection.set_relative_flow_rate(self, split_flow_rate)
		flow_rate -= split_flow_rate
		connection.queue_update_connected_node(self)

	extra_flow_rate = flow_rate - deficit_flow_rate
	if not is_zero_approx(flow_rate) and not is_zero_approx(deficit_flow_rate):
		printerr("%s | %s" % [flow_rate, deficit_flow_rate])
	
	if deficit_flow_rate > 0.0 and is_input_restricting_flow():
		_request_more_flow()
	
func _on_overflow() -> void:
	# Try to override completely blocked flows, if their pressure is different from attempted pressure flow
	# that's just extra_flow_rate

	var output_connection_count := connections.size() - output_connection_index
	var predicted_pressure := extra_flow_rate + current_flow_pressure / (output_connection_count + 1) + current_source_pressure / (output_connection_count + 1) 
	for i in output_connection_index - blocked_connection_index:
		var index := output_connection_index - i - 1
		var connection := connections[index]
		if connection.flow_pressure + connection.source_pressure > predicted_pressure:
			continue
		
		connection.allowed_flow_rate = extra_flow_rate
		queue_update()
		return

	# to handle backflow, input sources have to be capped
	# 2 options as I see it, we stop flow of a pipe one by one or slow down all of them. Going with the second option
	var proportion_pressure_as_limit := (current_flow_rate - extra_flow_rate) / (current_flow_rate + current_flow_pressure)
	for i in blocked_connection_index:
		var connection := connections[i]
		var flow := connection.get_relative_flow_rate(self)
		if flow >= 0.0:
			continue

		var pressure = -flow + connection.flow_pressure
		connection.allowed_flow_rate = pressure * proportion_pressure_as_limit
		connection.set_relative_flow_rate(self, -pressure * proportion_pressure_as_limit)
		connection.flow_pressure = pressure - connection.allowed_flow_rate
		connection.queue_update_connected_node(self)

func get_effective_current_flow_pressure() -> float:
	if is_zero_approx(current_flow_pressure):
		return 0

	var effective_current_flow_pressure := 0.0
	for i in blocked_connection_index:
		var connection := connections[i]
		effective_current_flow_pressure += connection.flow_pressure

		var extra_pressure := absf(connection.flow_rate) + connection.flow_pressure - connection.max_flow_rate
		if extra_pressure > 0:
			effective_current_flow_pressure += connection.flow_pressure - extra_pressure

	return effective_current_flow_pressure


func _request_more_flow() -> void:
	assert(extra_flow_rate < 0)
	var effective_current_flow_pressure := get_effective_current_flow_pressure()
	if is_zero_approx(effective_current_flow_pressure):
		return
	
	var pressure_to_flow_proportion := minf(-extra_flow_rate / effective_current_flow_pressure, 1)
	for i in blocked_connection_index: # input connections
		var connection := connections[i]
		var effective_flow_pressure := connection.flow_pressure
		var extra_pressure := absf(connection.flow_rate) + connection.flow_pressure - connection.max_flow_rate
		if extra_pressure > 0:
			effective_flow_pressure -= extra_pressure

		connection.allowed_flow_rate += effective_flow_pressure * pressure_to_flow_proportion
		if connection.allowed_flow_rate > connection.max_flow_rate:
			printerr("allowed_flow_rate has exceeded max_flow_rate")
			connection.reset_allowed_flow_rate()

		connection.queue_update_connected_node(self)
