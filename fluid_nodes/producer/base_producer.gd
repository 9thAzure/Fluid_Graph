@tool
extends BaseFluidNode
class_name BaseProducer 

@export_range(0.0, 10.0, 0.01, "or_greater", "hide_slider")
var production_rate := 0.0:
	set(value):
		production_rate = value
		current_flow_rate = value
		if not Engine.is_editor_hint() and is_inside_tree():
			queue_update()

# @export_range(0.0, 10.0, 0.01, "or_greater", "hide_slider")
var pressure := 0.0

func _init() -> void:
	self_modulate = Color.CYAN

func _update() -> void:
	sort_connections()

	var flow_rate := production_rate
	var size := connections.size()
	var isolated_pressure := pressure
	# TODO: deal with inflowing connections
	for i in connections_input_output_divider:
		var connection := connections[i]
		var split_flow_rate := flow_rate / (size - i)
		var split_pressure := split_flow_rate + isolated_pressure / (size - i)

		var ingoing_flow_rate := -connection.get_relative_flow_rate(self)
		var ingoing_pressure := ingoing_flow_rate + connection.pressure
		if ingoing_pressure < split_pressure:
			push_back_overridden_flows(i)
			connections_input_output_divider = i
			break

		connection.pressure += absf(connection.flow_rate)
		connection.flow_rate = 0
		connection.allowed_flow_rate = 0
		connection.get_connecting_node(self).queue_update()


	extra_flow_rate = 0

	for i in size - connections_input_output_divider:
		var index := connections_input_output_divider + i
		var connection := connections[index]
		var split_flow_rate := flow_rate / (size - index)

		connection.pressure = isolated_pressure / (size - connections_input_output_divider)
		if split_flow_rate > connection.allowed_flow_rate:
			connection.pressure = split_flow_rate - connection.allowed_flow_rate
			split_flow_rate = connection.allowed_flow_rate
		elif pressure > 0 and connection.is_allowed_flow_rate_default():
			connection.allowed_flow_rate = split_flow_rate
		
		connection.set_relative_flow_rate(self, split_flow_rate)
		flow_rate -= split_flow_rate
		connection.get_connecting_node(self).queue_update()

	extra_flow_rate += flow_rate
	if not is_zero_approx(extra_flow_rate):
		_handle_backflow()
		return

func _handle_backflow() -> void:
	print("source overflow by %s units/s" % extra_flow_rate)
	if connections_input_output_divider == 0:
		return
	
	var connection := connections[connections_input_output_divider - 1]
	var ingoing_pressure := absf(connection.flow_rate) + connection.pressure
	pressure = ingoing_pressure * (connections.size() - connections_input_output_divider + 1) - production_rate + 1
	connection.reset_allowed_flow_rate()
	queue_update()
