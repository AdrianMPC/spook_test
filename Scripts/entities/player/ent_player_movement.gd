extends Node3D
class_name CPlayerMovement

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity");
"""
@export_category("MOVEMENT OPTIONS")
@export var SURF: bool = false;
@export var NOCLIP: bool = false;
@export var AUTO_BHOP: bool = false;
"""

@export_category("Controller instances")
@export var Controller_Instance: CharacterBody3D;
@export var PlayerCollision: CollisionShape3D;
@export var PlayerMesh: MeshInstance3D;

@export_category("Speed related")
#@export var jump_velocity: float = 4.0;
@export var walk_speed: float = 7.0;
@export var sprint_speed: float = 8.5;
#@export var CROUCH_SPEED_REDUCER: float = 0.7;
@export var ground_accel: float = 14.0
@export var ground_decel: float = 10.0;
@export var ground_friction: float = 6.0;
#@export var water_swim_up: float = 6.0;

@export_category("Air")
@export var air_cap: float = 1;
@export var air_accel = 800.0;
@export var air_move_speed = 500.0;
@export var noclip_move_speed_mult = 3.0;

@export_category("Stairs Control")
@export var StairsBelowRayCast3D: RayCast3D;
@export var StairsAheadRayCast3D: RayCast3D;
@export var MAX_STEP_HEIGHT: float = 0.5;

@export_category("Camera related")
@export var HeadBobEffectNode: CHeadBobEffect;
@export var CameraSmoothingModule: CPlayerCameraSmoothing;
@export var MoveableHeadModule: Node3D;
@export var ShapeCast: ShapeCast3D;
"""
@export_category("Ladder")
@export var climb_speed: float = 5.0;
"""
#const CROUCH_TRANSLATE: float = 0.7;
#const CROUCH_JUMP_ADD: float = CROUCH_TRANSLATE * 0.9;

#var is_crouch: bool = false;
var is_sprinting: bool = false;
@onready var _original_capsule_height = PlayerCollision.shape.height;

var _snapped_to_stairs_last_frame: bool = false;
var _last_frame_was_onfloor: float = -INF;
var wish_dir: Vector3 = Vector3.ZERO;
var cam_aligned_wish_dir = Vector3.ZERO;

##var headbob_time: float = 0.0;

var _cur_ladder_climbing: Area3D = null;

func _main_movement_process(delta: float) -> void:
	if Controller_Instance.is_on_floor(): 
		_last_frame_was_onfloor = Engine.get_physics_frames()
	var input_dir = Input.get_vector("left", "right", "forward", "backwards").normalized();
	wish_dir = Controller_Instance.global_transform.basis * Vector3(input_dir.x ,0, input_dir.y);
	
	if Controller_Instance.is_on_floor() or _snapped_to_stairs_last_frame:
		_handle_ground_physics(delta);
	else:
		_handle_air_physics(delta);
			
	if not _snap_up_to_stairs_check(delta):
		_push_away_rigid_bodies();
		Controller_Instance.move_and_slide()
		_snap_down_to_stairs_check()
	CameraSmoothingModule._slide_camera_smooth_back_to_origin(delta, walk_speed);
	
	
func _handle_air_physics(delta) -> void:
	Controller_Instance.velocity.y -= gravity * delta
	var cur_speed_in_wish_dir = Controller_Instance.velocity.dot(wish_dir)
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta 
		accel_speed = min(accel_speed, add_speed_till_cap) 
		Controller_Instance.velocity += accel_speed * wish_dir

	if Controller_Instance.is_on_wall():
		if _is_surface_too_steep(Controller_Instance.get_wall_normal()):
			Controller_Instance.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			Controller_Instance.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
			
		_clip_velocity(Controller_Instance.get_wall_normal(), 1, delta) 

func _handle_ground_physics(delta) -> void:
	var cur_speed_in_wish_dir = Controller_Instance.velocity.dot(wish_dir);
	var add_speed_till_cap = _get_move_speed() - cur_speed_in_wish_dir;
	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * delta * _get_move_speed();
		accel_speed = min(accel_speed, add_speed_till_cap);
		Controller_Instance.velocity += accel_speed * wish_dir;
	# friction
	var curr_length = Controller_Instance.velocity.length();
	var control = max(curr_length, ground_decel);
	var drop = control * ground_friction * delta;
	var new_speed = max(curr_length - drop, 0.0);
	
	if curr_length > 0.0:
		new_speed /= curr_length
	Controller_Instance.velocity *= new_speed;
	#var snd_pack : MatSoundPack = _get_3d_texture();
	HeadBobEffectNode.headbobProcess(delta, Controller_Instance.velocity.length(), null);
	
	
# Allow sliding
func _clip_velocity(normal: Vector3, overbounce: float, _delta: float):
	var backoff := Controller_Instance.velocity.dot(normal) * overbounce;
	if backoff >= 0:
		return
	
	var change := normal * backoff;
	Controller_Instance.velocity -= change;
	
	var adjust := Controller_Instance.velocity.dot(normal);
	if adjust >= 0.0:
		Controller_Instance.velocity -= normal * adjust;
"""
# TODO refactor this (maybe use signals) so it works by not checking every frame if the playerinstance is overlapping water or something
func _handle_water_physics(delta) -> bool:
	if get_tree().get_nodes_in_group("water_area").all(func(area): return !area.overlaps_body(Controller_Instance)):
		return false
	
	if not Controller_Instance.is_on_floor() and not Input.is_action_pressed("jump"):
		var fall_velocity_reductor = 0.6;
		Controller_Instance.velocity.y -= gravity * fall_velocity_reductor * delta;	
	Controller_Instance.velocity += cam_aligned_wish_dir * _get_move_speed() * delta;
	
	if Input.is_action_pressed("jump"):
		Controller_Instance.velocity.y += water_swim_up * delta;
		
	if Input.is_action_pressed("crouch"):
		Controller_Instance.velocity.y -= water_swim_up * delta;
		
	Controller_Instance.velocity = Controller_Instance.velocity.lerp(Vector3.ZERO, 1.8 * delta);
	return true
"""
func _snap_down_to_stairs_check() -> void:
	var did_snap: bool = false;
	StairsBelowRayCast3D.force_raycast_update();
	var floor_below : bool = StairsBelowRayCast3D.is_colliding() and not _is_surface_too_steep(StairsBelowRayCast3D.get_collision_normal());
	var was_on_floor_last_frame = Engine.get_physics_frames() == _last_frame_was_onfloor;
	if not Controller_Instance.is_on_floor() and Controller_Instance.velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result = KinematicCollision3D.new();
		if Controller_Instance.test_move(Controller_Instance.global_transform, Vector3(0,-MAX_STEP_HEIGHT,0), body_test_result):
			CameraSmoothingModule._save_camera_pos_for_smoothing();
			var translate_y = body_test_result.get_travel().y;
			Controller_Instance.position.y += translate_y;
			Controller_Instance.apply_floor_snap();
			did_snap = true;
	_snapped_to_stairs_last_frame = did_snap;

func _snap_up_to_stairs_check(delta: float) -> bool:
	if not Controller_Instance.is_on_floor() and not _snapped_to_stairs_last_frame: 
		return false;
		
	if Controller_Instance.velocity.y > 0 or (Controller_Instance.velocity * Vector3(1,0,1)).length() == 0: 
		return false;
		
	var expected_move_motion = Controller_Instance.velocity * Vector3(1,0,1) * delta;
	var step_pos_with_clearance = Controller_Instance.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0));
	
	var down_check_result = KinematicCollision3D.new();
	if (Controller_Instance.test_move(step_pos_with_clearance, Vector3(0,-MAX_STEP_HEIGHT*2,0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y;
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_position() - self.global_position).y > MAX_STEP_HEIGHT: 
			return false;
			
		StairsAheadRayCast3D.global_position = down_check_result.get_position() + Vector3(0,MAX_STEP_HEIGHT,0) + expected_move_motion.normalized() * 0.1;
		StairsAheadRayCast3D.force_raycast_update();
		if StairsAheadRayCast3D.is_colliding() and not _is_surface_too_steep(StairsAheadRayCast3D.get_collision_normal()):
			CameraSmoothingModule._save_camera_pos_for_smoothing();
			Controller_Instance.global_position = step_pos_with_clearance.origin + down_check_result.get_travel();
			Controller_Instance.apply_floor_snap();
			_snapped_to_stairs_last_frame = true;
			return true;
	return false;
"""
func _handle_crouch(delta: float) -> void:
	var was_crouched_last_frame = is_crouch;
	if Input.is_action_pressed("crouch"):
		is_crouch = true;	
	elif is_crouch and not Controller_Instance.test_move(Controller_Instance.global_transform, Vector3(0,CROUCH_TRANSLATE,0)):
		is_crouch = false;
#
	var translate_y_if_possible := 0.0;
	if was_crouched_last_frame != is_crouch and not Controller_Instance.is_on_floor() and not _snapped_to_stairs_last_frame:
		translate_y_if_possible = CROUCH_JUMP_ADD if is_crouch else -CROUCH_JUMP_ADD;
	
	if translate_y_if_possible != 0.0:
		var result = KinematicCollision3D.new();
		Controller_Instance.test_move(Controller_Instance.global_transform, Vector3(0,translate_y_if_possible,0), result)
		Controller_Instance.position.y += result.get_travel().y;
		MoveableHeadModule.position.y -= result.get_travel().y;
		MoveableHeadModule.position.y = clampf(MoveableHeadModule.position.y, -CROUCH_TRANSLATE, 0);
	
	MoveableHeadModule.position.y = move_toward(MoveableHeadModule.position.y, -CROUCH_TRANSLATE if is_crouch else 0.0, 7.0 * delta);
	PlayerCollision.shape.height = _original_capsule_height - CROUCH_TRANSLATE if is_crouch else _original_capsule_height;
	PlayerCollision.position.y = PlayerCollision.shape.height / 2;
	
	#For playermodel
	PlayerMesh.mesh.height = PlayerCollision.shape.height;
	PlayerMesh.position.y = PlayerCollision.position.y;
	PlayerMesh.position.y = PlayerCollision.shape.height - 0.302;
	PlayerMesh.position.y = PlayerCollision.shape.height - 0.9;
"""
"""
func _handle_ladder() -> bool:
	var was_climbing_ladder := _cur_ladder_climbing and _cur_ladder_climbing.overlaps_body(Controller_Instance)
	if not was_climbing_ladder:
		_cur_ladder_climbing = null
		for ladder in get_tree().get_nodes_in_group("ladder_area3d"):
			if ladder.overlaps_body(Controller_Instance):
				_cur_ladder_climbing = ladder
				break
	if _cur_ladder_climbing == null:
		return false

	var ladder_gtransform : Transform3D = _cur_ladder_climbing.global_transform
	var pos_rel_to_ladder := ladder_gtransform.affine_inverse() * Controller_Instance.global_position
	
	var forward_move := Input.get_action_strength("forward") - Input.get_action_strength("backwards")
	var side_move := Input.get_action_strength("right") - Input.get_action_strength("left")
	var ladder_forward_move = ladder_gtransform.affine_inverse().basis * PlayerCamera.global_transform.basis * Vector3(0, 0, -forward_move)
	var ladder_side_move = ladder_gtransform.affine_inverse().basis * PlayerCamera.global_transform.basis * Vector3(side_move, 0, 0)
	
	var ladder_strafe_vel : float = climb_speed * (ladder_side_move.x + ladder_forward_move.x)
	var ladder_climb_vel : float = climb_speed * -ladder_side_move.z
	var up_wish := Vector3.UP.rotated(Vector3(1,0,0), deg_to_rad(-45)).dot(ladder_forward_move)
	ladder_climb_vel += climb_speed * up_wish

	var should_dismount = false
	if not was_climbing_ladder:
		var mounting_from_top = pos_rel_to_ladder.y > _cur_ladder_climbing.get_node("TopOfLadder").position.y
		if mounting_from_top:
			if ladder_climb_vel > 0: should_dismount = true
		else:
			if (ladder_gtransform.affine_inverse().basis * wish_dir).z >= 0: should_dismount = true
		if abs(pos_rel_to_ladder.z) > 0.1: should_dismount = true
	
	if Controller_Instance.is_on_floor() and ladder_climb_vel <= 0: should_dismount = true
	
	if should_dismount:
		_cur_ladder_climbing = null
		return false
	
	if was_climbing_ladder and Input.is_action_just_pressed("jump"):
		Controller_Instance.velocity = _cur_ladder_climbing.global_transform.basis.z * jump_velocity * 1.5
		_cur_ladder_climbing = null
		return false
	
	Controller_Instance.velocity = ladder_gtransform.basis * Vector3(ladder_strafe_vel, ladder_climb_vel, 0)
	# Should we allow ladder boosting? - uncomment if no
	#Controller_Instance.velocity = Controller_Instance.velocity.limit_length(climb_speed) 

	pos_rel_to_ladder.z = 0
	Controller_Instance.global_position = ladder_gtransform * pos_rel_to_ladder
	
	Controller_Instance.move_and_slide()
	return true
# REHACER
"""
"""
func _get_3d_texture() -> MatSoundPack:
	if !StairsBelowRayCast3D.is_colliding():
		return null 
	
	var collider = StairsBelowRayCast3D.get_collider()
	var sound_pack = null

	if collider.get_class() == "Terrain3D":
		var terrain: Terrain3D = collider
		var texture_id = terrain.data.get_texture_id(Controller_Instance.global_position)

		if texture_id.x == NAN:
			return null
			
		var base_texture: Terrain3DTextureAsset = terrain.assets.get_texture(texture_id.x)
		var overlay_texture: Terrain3DTextureAsset = terrain.assets.get_texture(texture_id.y) if texture_id.y != NAN else null
		var blend_value = texture_id.z
		
		if blend_value < 0.3 and base_texture.has_meta("step_snd"):
			sound_pack = base_texture.get_meta("step_snd")
		elif blend_value >= 0.3 and blend_value <= 0.7 and overlay_texture and overlay_texture.has_meta("step_snd"):
			sound_pack = overlay_texture.get_meta("step_snd")
		else:
			sound_pack = base_texture.get_meta("step_snd") if base_texture.has_meta("step_snd") else null

	else:
		var body: CollisionObject3D = collider
		var shape_idx: int = StairsBelowRayCast3D.get_collider_shape()
		var shape: CollisionShape3D = body.shape_owner_get_owner(shape_idx)
		
		if shape.has_meta("step_snd"):
			sound_pack = shape.get_meta("step_snd")
			
	if sound_pack == null:
		print("No se encontró un sonido válido para este terreno u objeto.")
		
	return sound_pack if sound_pack is MatSoundPack else null
"""	
func _push_away_rigid_bodies():
	for i in Controller_Instance.get_slide_collision_count():
		var collision := Controller_Instance.get_slide_collision(i)
		if collision.get_collider() is RigidBody3D:
			var push_dir = -collision.get_normal()
			var velocity_diff_in_push_dir = Controller_Instance.velocity.dot(push_dir) - collision.get_collider().linear_velocity.dot(push_dir)
			# negativo si quieres atraer los objetos hacía ti
			velocity_diff_in_push_dir = max(0., velocity_diff_in_push_dir)
			const MY_APPROX_MASS_KG = 80.0 # peso del player
			# controla la fuerza  de empuje
			var mass_ratio = min(1., MY_APPROX_MASS_KG / collision.get_collider().mass)
			if mass_ratio < 0.25:
				continue
			push_dir.y = 0
			var push_force = mass_ratio * 5.0
			collision.get_collider().apply_impulse(push_dir * velocity_diff_in_push_dir * push_force, collision.get_position() - collision.get_collider().global_position)

func get_usable_component_at_shapecast() -> CUsableComponent:
	for i in ShapeCast.get_collision_count():
		if i > 0 and ShapeCast.get_collider(0) != Controller_Instance:
			return null
		if ShapeCast.get_collider(i).get_node_or_null("CUsableComponent") is CUsableComponent:
			return ShapeCast.get_collider(i).get_node_or_null("CUsableComponent");
	return null;

	

func _get_move_speed() -> float:	
	if Input.is_action_pressed("sprint"):
		return sprint_speed
		
	return walk_speed 
	
func _is_surface_too_steep(normal: Vector3):
		return normal.angle_to(Vector3.UP) > Controller_Instance.floor_max_angle;
