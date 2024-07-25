@tool
extends BaseFluidNode
class_name BaseConsumer

@export_range(0.0, 10.0, 0.01, "or_greater", "hide_slider")
var consumption_rate := 0.0:
	set(value):
		consumption_rate = value
		if not Engine.is_editor_hint() and is_inside_tree():
			queue_update()

var efficiency := 1.0

func _init() -> void:
	self_modulate = Color.RED

# func _update() -> void:
# 	# output_connection_index = connections.size()
# 	sort_connections()

func _handle_outputs() -> void:
	for i in connections.size() - output_connection_index:
		var index := output_connection_index + i
		var connection := connections[index]
		if is_zero_approx(connection.flow_rate) and is_zero_approx(connection.source_pressure) and is_zero_approx(connection.flow_pressure):
			continue
		
		# allowed_flow_rate doesn't really matter here, nodes overriding it should reset it anyways.
		connection.flow_rate = 0
		connection.flow_pressure = 0
		connection.source_pressure = 0
		connection.queue_update_connected_node(self)

	efficiency = 1.0
	extra_flow_rate -= consumption_rate
	stabilize_input_flows()
	if extra_flow_rate < 0:
		if is_zero_approx(stored_amount):
			efficiency = 1 - -extra_flow_rate / consumption_rate
		# _request_more_flow()

# from excess flow to deficit flow
# func _storage_flow_sort(a : FluidConnection, b : FluidConnection) -> bool:
# 	var node_a := a.get_connecting_node(self)
# 	var node_b := b.get_connecting_node(self)

# 	if not is_equal_approx(node_a.stored_amount, node_b.stored_amount):
# 		return node_a.stored_amount > node_b.stored_amount
	
# 	# we subtract to ignore the deficit flow rate from the connections to this node.
# 	var deficit_a := node_a.extra_flow_rate + (a.allowed_flow_rate - a.flow_rate)
# 	var deficit_b := node_b.extra_flow_rate + (b.allowed_flow_rate - b.flow_rate)
# 	return deficit_a > deficit_b # deficits should be negative

# func deal_with_extra_flow() -> void:
# 	connections.sort_custom(_storage_flow_sort)
