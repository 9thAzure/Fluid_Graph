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

func _update_inputs() -> void:
	var size := connections.size()
	for i in blocked_connection_index:
		var connection := connections[i]
		var divider := size - (output_connection_index - blocked_connection_index) - i
		var split_total_pressure := (production_rate + current_flow_pressure + current_source_pressure) / divider

		var total_ingoing_pressure := absf(connection.flow_rate) + connection.source_pressure + connection.flow_pressure
		if total_ingoing_pressure < split_total_pressure:
			push_back_overridden_flows(i, blocked_connection_index - i)
			break

		connection.flow_pressure += absf(connection.flow_rate)
		connection.flow_rate = 0
		connection.allowed_flow_rate = 0
		connection.get_connecting_node(self).queue_update()
	
	assert(is_equal_approx(current_flow_rate, production_rate), "production_rate (%s) different from current_flow_rate (%s) | difference: %s" % [production_rate, current_flow_rate, production_rate - current_flow_rate]) 

func _on_overflow() -> void:
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
