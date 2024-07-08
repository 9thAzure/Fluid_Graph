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

func _init() -> void:
	self_modulate = Color.CYAN

func _update() -> void:
	sort_connections()

	var flow_rate := production_rate
	var size := connections.size()
	# TODO: deal with inflowing connections
	for i in connections_input_output_divider:
		var connection := connections[i]
		connection.allowed_flow_rate = 0

	extra_flow_rate = 0

	for i in size - connections_input_output_divider:
		var index := connections_input_output_divider + i
		var connection := connections[index]
		var split_flow_rate := flow_rate / (size - index)

		connection.pressure = 0
		if split_flow_rate > connection.allowed_flow_rate:
			connection.pressure = split_flow_rate - connection.allowed_flow_rate
			split_flow_rate = connection.allowed_flow_rate
		
		connection.set_relative_flow_rate(self, split_flow_rate)
		flow_rate -= split_flow_rate
		connection.get_connecting_node(self).queue_update()

	extra_flow_rate += flow_rate
	if not is_zero_approx(extra_flow_rate):
		_handle_backflow()
		return

func _handle_backflow() -> void:
	print("source overflow by %s units/s" % extra_flow_rate)
