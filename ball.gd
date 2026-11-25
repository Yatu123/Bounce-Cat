class_name Ball
extends CharacterBody2D

enum State { RESTING, HELD, FLYING }

@export_group("Throwing")
## If true, the farther the mouse is from the ball, the harder the throw.
@export var distance_controls_power: bool = true
## Slowest throw (mouse right next to the cat), pixels/second.
@export var min_throw_speed: float = 450.0
## Fastest throw. Raise this to make the ball go further.
@export var max_throw_speed: float = 1500.0
## Mouse distance (pixels from the ball) at which the throw reaches max speed.
@export var full_power_distance: float = 450.0
## Seconds after shooting before the cat is allowed to grab the ball again.
@export var pickup_delay: float = 0.4

@export_group("Bounce")
## Fraction of speed kept after each bounce. MAIN "less resistance" value (1.0 = never loses energy).
@export_range(0.0, 1.0) var bounce_energy: float = 0.85
## Horizontal speed kept each time the ball lands on the floor (1.0 = no loss).
@export_range(0.0, 1.0) var floor_friction: float = 0.98
## 1.0 = project gravity. Lower = floatier ball.
@export var gravity_scale: float = 1.0

@export_group("Stopping")
## Floor impacts slower than this stop bouncing and the ball starts rolling. Keep above ~30.
@export var bounce_threshold: float = 40.0
## How quickly the rolling ball slows down (pixels/second squared). Lower = rolls farther.
@export var roll_friction: float = 100.0
## When the rolling ball is slower than this it stops completely.
@export var rest_speed: float = 10.0

@export_group("Aim Arrow")
@export var show_arrow: bool = true
@export var arrow_color: Color = Color(1, 1, 1, 0.85)
## How many physics steps of the flight are predicted (60 steps = 1 second).
@export var preview_steps: int = 120
## How many bounces the arrow shows before it stops.
@export var preview_bounces: int = 3
@export var dot_spacing: float = 14.0
@export var dot_radius: float = 2.5
@export var arrow_head_distance: float = 36.0

const FLOOR_DOT := 0.7

@onready var bounce_sound: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var pickup_area: Area2D = $PickupArea

var state: State = State.RESTING
var holder: Player = null
var aim_direction: Vector2 = Vector2.RIGHT
var current_throw_speed: float = 700.0
var pickup_timer: float = 0.0

var _default_layer: int
var preview_points: PackedVector2Array = PackedVector2Array()
var preview_bounce_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	process_physics_priority = 1
	_default_layer = collision_layer

func _physics_process(delta: float) -> void:
	pickup_timer = maxf(pickup_timer - delta, 0.0)

	match state:
		State.HELD:
			_process_held()
		State.FLYING:
			_process_flying(delta)
		State.RESTING:
			_process_resting()

func _process_held() -> void:
	if holder == null:
		state = State.FLYING
		collision_layer = _default_layer
		return

	global_position = holder.hold_point.global_position

	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		aim_direction = to_mouse.normalized()
	current_throw_speed = _compute_throw_speed(to_mouse.length())

	if Input.is_action_just_pressed("shoot"):
		shoot()
		return

	if show_arrow:
		_update_preview()
	queue_redraw()

func pick_up(new_holder: Player) -> void:
	holder = new_holder
	state = State.HELD
	velocity = Vector2.ZERO

	collision_layer = 0
	add_collision_exception_with(new_holder)
	new_holder.pick_up_ball(self)


func shoot() -> void:
	collision_layer = _default_layer
	velocity = aim_direction * current_throw_speed
	state = State.FLYING
	pickup_timer = pickup_delay

	preview_points.clear()
	preview_bounce_points.clear()
	queue_redraw()

	var old_holder := holder
	holder = null
	old_holder.release_ball()


func _compute_throw_speed(mouse_distance: float) -> float:
	if not distance_controls_power:
		return max_throw_speed
	return lerpf(min_throw_speed, max_throw_speed, clampf(mouse_distance / full_power_distance, 0.0, 1.0))

func _process_flying(delta: float) -> void:
	velocity += get_gravity() * gravity_scale * delta

	var collision := move_and_collide(velocity * delta)
	if collision:
		_handle_collision(collision, delta)


func _handle_collision(collision: KinematicCollision2D, delta: float) -> void:
	var normal := collision.get_normal()
	var impact := absf(velocity.dot(normal)) # how hard we hit the surface

	# Optional hook: solid objects can define on_ball_hit(ball).
	var collider := collision.get_collider()
	if collider and collider.has_method("on_ball_hit"):
		collider.call("on_ball_hit", self)

	if _is_rolling_hit(velocity, normal):
		velocity = velocity.slide(normal)
		velocity = velocity.move_toward(Vector2.ZERO, roll_friction * delta)
		if velocity.length() < rest_speed:
			_come_to_rest()
		return

	velocity = _bounce_velocity(velocity, normal)
	_play_bounce_sound(impact)

func _is_rolling_hit(vel: Vector2, normal: Vector2) -> bool:
	return normal.dot(Vector2.UP) > FLOOR_DOT and absf(vel.dot(normal)) < bounce_threshold


func _bounce_velocity(vel: Vector2, normal: Vector2) -> Vector2:
	var result := vel.bounce(normal) * bounce_energy
	if normal.dot(Vector2.UP) > FLOOR_DOT:
		result.x *= floor_friction
	return result


func _come_to_rest() -> void:
	velocity = Vector2.ZERO
	state = State.RESTING


func _play_bounce_sound(impact: float) -> void:
	if bounce_sound.stream == null or impact < 40.0:
		return
	bounce_sound.volume_db = linear_to_db(clampf(impact / max_throw_speed, 0.1, 1.0))
	bounce_sound.play()

func _process_resting() -> void:
	if not test_move(global_transform, Vector2.DOWN * 4.0):
		state = State.FLYING
		return

	if pickup_timer > 0.0:
		return

	for body in pickup_area.get_overlapping_bodies():
		if body is Player and body.can_pick_up_ball():
			pick_up(body)
			return

func _update_preview() -> void:
	preview_points.clear()
	preview_bounce_points.clear()

	var excluded: Array[RID] = [holder.get_rid()]
	var params := PhysicsTestMotionParameters2D.new()
	params.exclude_bodies = excluded
	var result := PhysicsTestMotionResult2D.new()

	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var pos := global_position
	var vel := aim_direction * current_throw_speed
	var bounces := 0
	preview_points.append(pos)

	for i in preview_steps:
		vel += get_gravity() * gravity_scale * dt
		params.from = Transform2D(0.0, pos)
		params.motion = vel * dt

		if PhysicsServer2D.body_test_motion(get_rid(), params, result):
			pos += result.get_travel()
			var normal := result.get_collision_normal()
			preview_points.append(pos)
			if _is_rolling_hit(vel, normal):
				break
			preview_bounce_points.append(pos)
			vel = _bounce_velocity(vel, normal)
			bounces += 1
			if bounces >= preview_bounces:
				break
		else:
			pos += params.motion
			preview_points.append(pos)


func _draw() -> void:
	if state != State.HELD or not show_arrow or preview_points.size() < 2:
		return
		
	var base := aim_direction * arrow_head_distance
	var tip := aim_direction * (arrow_head_distance + 10.0)
	var side := aim_direction.orthogonal() * 7.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), arrow_color)

	var total := 0.0
	for i in range(preview_points.size() - 1):
		total += preview_points[i].distance_to(preview_points[i + 1])
	if total <= 0.0:
		return

	var travelled := 0.0
	var next_dot := arrow_head_distance + 20.0
	for i in range(preview_points.size() - 1):
		var a := preview_points[i]
		var b := preview_points[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.001:
			continue
		while next_dot <= travelled + seg:
			var t := (next_dot - travelled) / seg
			var c := arrow_color
			c.a *= clampf(1.0 - next_dot / total, 0.15, 1.0)
			draw_circle(to_local(a.lerp(b, t)), dot_radius, c)
			next_dot += dot_spacing
		travelled += seg

	for p in preview_bounce_points:
		draw_arc(to_local(p), 6.0, 0.0, TAU, 16, arrow_color, 1.5)
