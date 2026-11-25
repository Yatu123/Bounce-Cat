class_name Player
extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var walk_sound: AudioStreamPlayer2D = $WalkSound

@onready var hold_point: Marker2D = $HoldPoint
@onready var hold_offset_x: float = absf(hold_point.position.x)

const SPEED = 300.0
const JUMP_VELOCITY = -550.0
const CLIMB_SPEED = 150.0
const REGRAB_DELAY = 0.25
const AIM_DEADZONE = 12.0

var on_ladder: bool = false
var is_climbing: bool = false
var grab_cooldown: float = 0.0

var held_ball: Ball = null


func _physics_process(delta: float) -> void:
	grab_cooldown = max(grab_cooldown - delta, 0.0)

	_ladder_detect()
	_update_hold_point()

	if held_ball != null:
		holding_movement(delta)
	elif is_climbing:
		ladder_movement(delta)
	else:
		movement(delta)

	move_and_slide()
	_update_animation()


func can_pick_up_ball() -> bool:
	return held_ball == null and not is_climbing and is_on_floor()


func pick_up_ball(ball: Ball) -> void:
	held_ball = ball
	is_climbing = false
	velocity.x = 0.0


func release_ball() -> void:
	held_ball = null


func _update_hold_point() -> void:
	hold_point.position.x = -hold_offset_x if animated_sprite_2d.flip_h else hold_offset_x


func holding_movement(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	velocity.x = 0.0

	var mouse_dx := get_global_mouse_position().x - global_position.x

	if mouse_dx > AIM_DEADZONE:
		animated_sprite_2d.flip_h = false
	elif mouse_dx < -AIM_DEADZONE:
		animated_sprite_2d.flip_h = true
	walk_sound.stop()

func _ladder_detect() -> void:
	if held_ball != null:
		is_climbing = false
		return

	if not on_ladder:
		is_climbing = false
		return

	if is_climbing or grab_cooldown > 0.0:
		return

	var wants_up := Input.is_action_pressed("up")
	var wants_down := Input.is_action_pressed("down") and not is_on_floor()

	if wants_up or wants_down:
		is_climbing = true

func movement(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_sound.play()

	var direction := Input.get_axis("left", "right")

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if direction > 0:
		animated_sprite_2d.flip_h = false
	elif direction < 0:
		animated_sprite_2d.flip_h = true

func ladder_movement(_delta: float) -> void:
	var climb_dir := Input.get_axis("up", "down")

	velocity.y = climb_dir * CLIMB_SPEED
	velocity.x = 0.0

	if climb_dir > 0 and is_on_floor():
		is_climbing = false
		return

	if Input.is_action_just_pressed("jump"):
		is_climbing = false
		grab_cooldown = REGRAB_DELAY
		velocity.y = JUMP_VELOCITY
		velocity.x = Input.get_axis("left", "right") * SPEED
		jump_sound.play()

func _update_animation() -> void:
	if is_climbing:
		walk_sound.stop()
		animated_sprite_2d.animation = "Climb"

		if velocity.y != 0:
			animated_sprite_2d.play()
		else:
			animated_sprite_2d.pause()

		return

	if not is_on_floor():
		animated_sprite_2d.animation = "Jump"
		walk_sound.stop()

	elif velocity.x != 0:
		animated_sprite_2d.animation = "Walk"

		if not walk_sound.playing:
			walk_sound.play()

	else:
		animated_sprite_2d.animation = "Idle"
		walk_sound.stop()

	if not animated_sprite_2d.is_playing():
		animated_sprite_2d.play()
