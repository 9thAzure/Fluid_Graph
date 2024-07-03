@tool
extends BaseFluidNode
class_name BaseConsumer

@export_range(0.0, 10.0, 0.01, "or_greater", "hide_slider")
var consumption_rate := 0.0

var efficiency := 1.0

func _init() -> void:
	self_modulate = Color.RED

func _update() -> void:
	connections_input_output_divider = connections.size()

	var inflowing_rate := 0.0
	for connection in connections:
		var flow_rate = -connection.get_relative_flow_rate(self)
		assert(flow_rate >= 0.0, "unexpected flow rate: consumer is giving flow away")
		inflowing_rate += flow_rate

	if inflowing_rate < consumption_rate:
		efficiency = inflowing_rate / consumption_rate
		extra_flow_rate = 0.0
		_request_more_flow()
		return
	
	efficiency = 1.0
	extra_flow_rate = inflowing_rate - consumption_rate

	if is_zero_approx(extra_flow_rate):
		return

	_handle_backflow()

func _request_more_flow() -> void:
	var required_flow_increase := consumption_rate * (1 - efficiency)
	var total_flow_friction := 0.0
	for connection in connections:
		total_flow_friction += connection.flow_friction
	
	print(required_flow_increase, total_flow_friction)
	
	if total_flow_friction <= required_flow_increase:
		if is_zero_approx(total_flow_friction):
			return

		for connection in connections:
			if is_zero_approx(connection.flow_friction):
				continue

			connection.flow_friction = 0
			connection.get_connecting_node(self).queue_update()
		return

	var decrease_rate := 1 - required_flow_increase / total_flow_friction
	for connection in connections:
		if is_zero_approx(connection.flow_friction):
			continue

		connection.flow_friction *= decrease_rate
		if is_zero_approx(connection.flow_friction):
			connection.flow_friction = 0
		
		connection.get_connecting_node(self).queue_update()
