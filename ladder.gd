extends Area2D

@export_file("*.tscn") var next_level_scene: String = "res://level2.tscn"

@export var lever: Area2D
@export var start_active: bool = false
@export var stay_active: bool = true
@export var fade_time: float = 0.5
@export var debug_prints: bool = true
@onready var victory_sound: AudioStreamPlayer2D = $VictorySound

@onready var ladder_shape: CollisionShape2D = $CollisionShape2D
@onready var exit_zone: Area2D = $ExitZone
@onready var exit_shape: CollisionShape2D = $ExitZone/CollisionShape2D

var is_active: bool = false
var _leaving: bool = false


func _ready() -> void:
	print("Hi")
	body_entered.connect(_on_ladder_entered)
	body_exited.connect(_on_ladder_exited)
	exit_zone.body_entered.connect(_on_exit_entered)

	_set_state(false, false)

	var source: Node = lever
	if source == null:
		var levers := get_tree().get_nodes_in_group("lever")
		if levers.size() == 1:
			source = levers[0]
		elif levers.size() > 1:
			push_warning("Ladder: several levers found - assign one in the Lever slot.")
		else:
			push_warning("Ladder: no lever found. Assign the Lever slot (and check lever.gd is attached).")

	if source:
		source.connect("toggled", set_active)
		_log("connected to lever: " + str(source.get_path()))
		if source.get("start_on"):
			_set_state(true, false)
			print("Connected to lever")
	elif start_active:
		_set_state(true, false)
		print("Not Connected to lever")


func set_active(active: bool) -> void:
	_log("set_active(" + str(active) + ")")
	if active == is_active:
		return
	if not active and stay_active:
		return
	_set_state(active, true)


func _set_state(active: bool, animate: bool) -> void:

	ladder_shape.set_deferred("disabled", not active)
	exit_shape.set_deferred("disabled", not active)
	is_active = active

	if active:
		visible = true
		if animate and fade_time > 0.0:
			modulate.a = 0.0
			create_tween().tween_property(self, "modulate:a", 1.0, fade_time)
		else:
			modulate.a = 1.0
	else:
		visible = false


func _log(text: String) -> void:
	if debug_prints:
		print("[Ladder ", name, "] ", text)


func _on_ladder_entered(body: Node2D) -> void:
	var player := body as Player
	if player:
		player.on_ladder = true


func _on_ladder_exited(body: Node2D) -> void:
	var player := body as Player
	if player:
		player.on_ladder = false

func _on_exit_entered(body: Node2D) -> void:
	if _leaving or not is_active or not (body is Player):
		return

	_leaving = true

	if not ResourceLoader.exists(next_level_scene):
		push_warning("Ladder: next_level_scene not found: " + next_level_scene)
		_leaving = false
		return


	get_tree().change_scene_to_file(next_level_scene)
