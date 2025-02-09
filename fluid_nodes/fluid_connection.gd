extends Node2D
class_name FluidConnection

var node1 : BaseFluidNode = null:
	set(value):
		if node1 != null:
			node1.connections.erase(self)
		if value != null:
			value.connections.append(self)
		node1 = value
		
var node2 : BaseFluidNode = null:
	set(value):
		if node1 != null:
			node1.connections.erase(self)
		if value != null:
			value.connections.append(self)
		node1 = value

# from node1 to node2, negative values indicate flows from node2 to node1.
var flow_rate := 0.0

var flow_friction := 0.0

func is_complete() -> bool:
	return node1 != null and node2 != null

func get_connecting_node(source_node : BaseFluidNode) -> BaseFluidNode:
	if is_same(source_node, node1):
		return node2
	
	assert(is_same(source_node, node2))
	return node1

func get_relative_flow_rate(source_node : BaseFluidNode) -> float:
	if is_same(source_node, node1):
		return flow_rate
	
	assert(is_same(source_node, node2))
	return -flow_rate

func set_relative_flow_rate(source_node : BaseFluidNode, value : float) -> void:
	if is_same(source_node, node1):
		flow_rate = value
		return
	
	assert(is_same(source_node, node2))
	flow_rate = -value

# func get_relative_max_flow_rate(source_node : BaseFluidNode) -> float:
# 	if is_same(source_node, node1):
# 		return max_flow_rate
	
# 	assert(is_same(source_node, node2))
# 	return -max_flow_rate

# func set_relative_max_flow_rate(source_node : BaseFluidNode, value : float) -> void:
# 	if is_same(source_node, node1):
# 		max_flow_rate = value
# 		return
	
# 	assert(is_same(source_node, node2))
# 	max_flow_rate = -value

func _draw() -> void:
	draw_multiline_colors([node1.position, node2,position], [node1.self_modulate, node2.self_modulate], 3)
