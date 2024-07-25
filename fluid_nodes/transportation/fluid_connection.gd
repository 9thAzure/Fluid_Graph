@tool
extends Node2D
class_name FluidConnection

# All values should be positive, and flow from node1 to node2.

@export
var node1 : BaseFluidNode = null:
	set(value):
		change_connection(node1, value)
		node1 = value
		queue_redraw()

@export
var node2 : BaseFluidNode = null:
	set(value):
		change_connection(node2, value)
		node2 = value
		queue_redraw()

func change_connection(old_node : BaseFluidNode, new_node : BaseFluidNode) -> void:
	if Engine.is_editor_hint():
		return

	if old_node != null:
		old_node.connections.erase(self)
		old_node.updated.disconnect(conditions_changed)
	if new_node != null:
		new_node.connections.append(self)
		new_node.updated.connect(conditions_changed)

@export
var max_flow_rate := 100.0

var flow_rate := 0.0

var allowed_flow_rate := 0.0

var flow_pressure := 0.0

var source_pressure := 0.0

func _ready() -> void:
	reset_allowed_flow_rate()
	set_process(false)

func conditions_changed() -> void:
	return

	var input_extra_flow := node1.extra_flow_rate
	var input_stored := node1.stored_amount
	var input_at_capacity := is_equal_approx(node1.stored_amount, node1.capacity)
	var output_extra_flow := node2.extra_flow_rate
	var output_stored := node2.stored_amount
	var output_at_capacity := is_equal_approx(node2.stored_amount, node2.capacity)

	if not is_equal_approx(input_stored, output_stored):
		if input_stored > output_stored:
			# try to pump more into output
			reset_allowed_flow_rate()
			node1.queue_update()
			return
		
		# ! This likely requires a rework of flow overriding
		# output_stored < input_stored
		# swap direction	
		# queue new input for update
		
		pass
	# if is_equal_approx(node2.stored_amount, node2.capacity):
	# 	if not is_zero_approx(allowed_flow_rate):
	# 		allowed_flow_rate = 0
	# 		flow_pressure += flow_rate
	# 		flow_rate = 0
	# 		node1.queue_update()
	# 	return
	


func _process(_delta: float) -> void:
	pass

func reset_allowed_flow_rate() -> void:
	allowed_flow_rate = max_flow_rate

func is_allowed_flow_rate_default() -> bool:
	return is_equal_approx(allowed_flow_rate, max_flow_rate)

func swap_direction() -> void:
	var temp := node1
	node1 = node2
	node2 = temp

func is_input_connection(source_node : BaseFluidNode) -> bool:
	return is_same(source_node, node2)

func is_blocked_connection() -> bool:
	return is_zero_approx(allowed_flow_rate)

func is_complete() -> bool:
	return node1 != null and node2 != null

func flow_multiplier(source_node: BaseFluidNode) -> int:
	if is_same(source_node, node1):
		return 1
	
	assert(is_same(source_node, node2))
	return -1

func get_connecting_node(source_node : BaseFluidNode) -> BaseFluidNode:
	if is_same(source_node, node1):
		return node2
	
	assert(is_same(source_node, node2))
	return node1

func queue_update_connected_node(source_node : BaseFluidNode) -> void:
	get_connecting_node(source_node).queue_update()

func get_relative_flow_rate(source_node : BaseFluidNode) -> float:
	return flow_rate * flow_multiplier(source_node)

func set_relative_flow_rate(source_node : BaseFluidNode, value : float) -> void:
	flow_rate = value * flow_multiplier(source_node)
	if flow_rate < 0:
		flow_rate = -flow_rate
		swap_direction()

func _draw() -> void:
	if not is_complete():
		return

	draw_polyline_colors([node1.position, node2.position], [node1.self_modulate, node2.self_modulate], 3, true)
