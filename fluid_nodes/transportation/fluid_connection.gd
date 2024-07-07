# TODO: implement pressure
@tool
extends Node2D
class_name FluidConnection

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
	if new_node != null:
		new_node.connections.append(self)

@export
var max_flow_rate := 100.0

# from node1 to node2, negative values indicate flows from node2 to node1.
var flow_rate := 0.0

var allowed_flow_rate := 0.0

func _ready() -> void:
	reset_allowed_flow_rate()

func reset_allowed_flow_rate() -> void:
	allowed_flow_rate = max_flow_rate

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

func _draw() -> void:
	if not is_complete():
		return

	draw_polyline_colors([node1.position, node2.position], [node1.self_modulate, node2.self_modulate], 3, true)
