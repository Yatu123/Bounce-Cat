class_name Lever
extends Area2D

signal toggled(is_on: bool)

@export var start_on: bool = false
@export var one_shot: bool = false
@export var cooldown: float = 0.4
@export var flick_by_cat: bool = true
@export var flick_by_ball: bool = true
@export var ladder: Area2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var toggle_sound: AudioStreamPlayer2D = get_node_or_null("ToggleSound")

var is_on: bool = false
var _locked: bool = false


func _enter_tree() -> void:
	add_to_group("lever")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	is_on = start_on
	_update_visual()
	if is_on:
		toggled.emit(is_on)


func _on_body_entered(body: Node2D) -> void:
	if _locked:
		return
	if (flick_by_ball and body is Ball) or (flick_by_cat and body is Player):
		toggle()


func toggle() -> void:
	is_on = not is_on
	_update_visual()
	if toggle_sound:
		toggle_sound.play()
	toggled.emit(is_on)

	if ladder:
		ladder.set_active(sprite.flip_h) 

	_locked = true
	if one_shot:
		return
	await get_tree().create_timer(cooldown).timeout
	_locked = false

func _update_visual() -> void:
	sprite.flip_h = is_on
