extends CharacterBody3D

@export var MovementManager: CPlayerMovement;

func _ready() -> void:
	pass
func _physics_process(delta: float) -> void:
	MovementManager._main_movement_process(delta);

func _process(_delta: float) -> void:
	pass
