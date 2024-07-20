extends Node2D

var fluid_node : BaseFluidNode = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if fluid_node == null:
		set_process(false)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	%Meter.scale.y = fluid_node.stored_amount / fluid_node.capacity
