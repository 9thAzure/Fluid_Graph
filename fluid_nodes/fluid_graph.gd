extends Node2D
class_name FluidGraph

var producers : Array[BaseProducer] = []
var consumers : Array[BaseConsumer] = []
var routers : Array[BaseRouter] = []

# Debug testing tools
signal fluid_update()

@export
var is_disabled := false

@export
var controlled_update := false

var progress_update := false:
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
	if is_disabled:
		process_mode = Node.PROCESS_MODE_DISABLED
		modulate = Color(1,1,1, 0.5)
		return

	update()

func update() -> void:
	for producer in producers:
		producer.queue_update()
