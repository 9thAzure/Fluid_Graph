extends Node2D
class_name FluidGraph

var producers : Array[BaseProducer] = []
var consumers : Array[BaseConsumer] = []
var routers : Array[BaseRouter] = []

signal fluid_update()

var continue_update := false:
	get:
		return false
	set(_value):
		fluid_update.emit()

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
			consumers.append(node)
		elif node is BaseRouter:
			routers.append(node)


func _on_child_exiting_tree(node : Node) -> void:
	if node is BaseFluidNode:
		node.parent_graph = null
		if node is BaseProducer:
			producers.erase(node)
		elif node is BaseConsumer:
			consumers.erase(node)
		elif node is BaseRouter:
			routers.erase(node)

func _ready() -> void:
	update()

func update() -> void:
	for producer in producers:
		producer.queue_update()
