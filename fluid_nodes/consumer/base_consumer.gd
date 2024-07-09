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

func _update() -> void:
	connections_input_output_divider = connections.size()
	var inflowing_rate := 0.0
	for connection in connections:
		var flow_rate = -connection.get_relative_flow_rate(self)
		if flow_rate < 0:
			printerr("unexpected flow rate: consumer is giving flow away to %s" % connection.get_connecting_node(self))
			continue

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
