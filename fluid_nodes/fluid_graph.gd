extends Node2D
class_name FluidGraph

var producers : Array[BaseProducer] = []
var consumers : Array[BaseConsumer] = []
var routers : Array[BaseRouter] = []

func _enter_tree() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)

func _exit_tree():
	child_entered_tree.disconnect(_on_child_entered_tree)
	child_exiting_tree.disconnect(_on_child_exiting_tree)

func _on_child_entered_tree(node : Node) -> void:
	if node is BaseFluidNode:
		node.parent_graph = self
		if node is BaseProducer:
			producers.append(node)
		elif node is BaseConsumer:
			producers.append(node)
		elif node is BaseRouter:
			producers.append(node)


func _on_child_exiting_tree(node : Node) -> void:
	if node is BaseFluidNode:
		node.parent_graph = null
		if node is BaseProducer:
			producers.erase(node)
		elif node is BaseConsumer:
			producers.erase(node)
		elif node is BaseRouter:
			producers.erase(node)

func update() -> void:
	var nodes_to_update : Array[BaseFluidNode] = producers.duplicate()

	while nodes_to_update.size() != 0:
		var current : BaseFluidNode = nodes_to_update.pop_back()
		if is_zero_approx(current.current_flow_rate):
			continue

		var connections := current.connections
		var total_flow_rate := 0.0
		var is_current_producer := current is BaseProducer
		for connection in connections:
			var connected_node := connection.get_connecting_node(current)
			if connected_node is BaseProducer:
				if is_current_producer:
					connection.max_flow_rate = 0.0
				else:
					connection.max_flow_rate = -connected_node.production_rate
					connection.set_relative_flow_rate(-connected_node.production_rate)
			elif connected_node is BaseConsumer:
				connection.max_flow_rate = connected_node.consumption_rate

			total_flow_rate += max(0, -connection.get_relative_flow_rate(current))
		
