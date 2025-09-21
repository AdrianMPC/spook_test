extends Node
class_name CHeadBobEffect
@export var HeadPivot: Node3D;
@export var Camera: Camera3D;

signal movement_step(snd_pack: MatSoundPack);

const HEADBOB_MOVE_AMOUNT = 0.06
const HEADBOB_FREQUENCY = 2.4
var headbob_time := 0.0
var can_play : bool = false;

func headbobProcess(delta: float, speed: float, snd_pack: MatSoundPack) -> void:
	headbob_time += delta * speed
	var pos := sin(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT
	var pos_threshold : float = -HEADBOB_MOVE_AMOUNT * 0.5 
	"""
	Camera.transform.origin = Vector3(
		#cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT,
		0,
		pos,
		0
	)	
	"""
	if pos < pos_threshold and can_play:
		can_play = false  
		emit_signal(&'movement_step', snd_pack)
  
	if pos > 0:
		can_play = true
	
