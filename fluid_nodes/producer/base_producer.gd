@tool
extends BaseFluidNode
class_name BaseProducer 

@export_range(0.0, 10.0, 0.01, "or_greater", "hide_slider")
var production_rate := 0.0:
	set(value):
		production_rate = value
		current_flow_rate = value

func _init() -> void:
	self_modulate = Color.CYAN

func _update() -> void:
	is_queued = false
	# connections.sort_custom(func(a: FluidConnection, b: FluidConnection) -> bool: return a.flow_friction > b.flow_friction)
	sort_connections()

	var flow_rate := production_rate
	for i in connections.size():
		var connection := connections[i]
		var split_flow_rate := flow_rate / (size - i)
		if i >= connections_input_output_divider:
			split_flow_rate -= connection.flow_friction
			connection.set_relative_flow_rate(self, split_flow_rate)
			flow_rate -= split_flow_rate
			connection.get_connecting_node(self).queue_update()
			continue

		var ingoing_flow_rate := -connection.get_relative_flow_rate(self)
		var ingoing_pressure := ingoing_flow_rate + connection.flow_friction
		if ingoing_pressure >= split_flow_rate: # inflowing flows are negative
			connection.flow_rate = 0
			connection.flow_friction = ingoing_pressure
			connection.get_connecting_node(self).queue_update()
			continue
		
		# ingoing flow that is less thant split_flow_rate
		split_flow_rate -= ingoing_pressure
		connection.flow_friction = ingoing_pressure
		connection.set_relative_flow_rate(self, split_flow_rate)
		flow_rate -= split_flow_rate
		connection.get_connecting_node(self).queue_update()
	
	extra_flow_rate = flow_rate
	# extra_flow_rate = outflowing_rate
	if is_zero_approx(extra_flow_rate):
		return
	
	_handle_backflow()

func _handle_backflow() -> void:
	print("source overflow by %s units/s" % extra_flow_rate)
