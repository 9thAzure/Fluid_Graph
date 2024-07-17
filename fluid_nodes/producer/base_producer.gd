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
	# var isolated_pressure := pressure
	# TODO: deal with inflowing connections
	for i in blocked_connection_index:
		var connection := connections[i]
		var divider := size - (output_connection_index - blocked_connection_index) - i
		var split_flow_rate := flow_rate / divider
		# var split_pressure := split_flow_rate + isolated_pressure / (size - i)

		var ingoing_flow_rate := -connection.get_relative_flow_rate(self)
		var ingoing_pressure := ingoing_flow_rate + connection.flow_pressure
		if ingoing_pressure < split_flow_rate + pressure:
			push_back_overridden_flows(i, blocked_connection_index - i)
			break

		connection.flow_pressure += absf(connection.flow_rate)
		connection.flow_rate = 0
		connection.allowed_flow_rate = 0
		connection.get_connecting_node(self).queue_update()


	extra_flow_rate = 0

	var output_flow_below_limit := false
	for i in size - output_connection_index:
		var index := output_connection_index + i
		var connection := connections[index]
		var split_flow_rate := flow_rate / (size - index)

		connection.flow_pressure = 0
		connection.source_pressure = pressure
		if split_flow_rate > connection.allowed_flow_rate:
			connection.flow_pressure = split_flow_rate - connection.allowed_flow_rate
			split_flow_rate = connection.allowed_flow_rate
		elif pressure > 0 and not connection.is_allowed_flow_rate_default() and split_flow_rate < connection.allowed_flow_rate:
			output_flow_below_limit = true
		
		connection.set_relative_flow_rate(self, split_flow_rate)
		flow_rate -= split_flow_rate
		connection.get_connecting_node(self).queue_update()

	extra_flow_rate += flow_rate
	if not is_zero_approx(extra_flow_rate):
		return

	if output_flow_below_limit:
		_request_more_flow()

func _handle_backflow() -> void:
	print("source overflow by %s units/s" % extra_flow_rate)
	var index := -1
	for i in connections.size():
		if not is_zero_approx(connections[i].allowed_flow_rate):
			break
		index = i
	
	if index == -1:
		return
	
	var connection := connections[index]
	var ingoing_pressure := connection.flow_pressure
	pressure = ingoing_pressure - production_rate + extra_flow_rate
	connection.reset_allowed_flow_rate()
	queue_update()

func _request_more_flow() -> void:
	pressure = 0
	queue_update()
