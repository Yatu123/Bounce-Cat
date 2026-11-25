extends Node2D 

@export var level1_scene: String = "res://level1.tscn"
@export var level2_scene: String = "res://level2.tscn"
@export var level3_scene: String = "res://level3.tscn"

@export var hover_scale: float = 1.08
@export var normal_scale: float = 1.0

@export var hover_color: Color = Color(1.0, 0.85, 0.35)
@export var normal_color: Color = Color.WHITE

var hover_tweens = {}

func _ready(): #set up

	$ButtonManager/Start.pressed.connect(_on_start_pressed)
	$ButtonManager/Quit.pressed.connect(_on_quit_pressed)
	$ButtonManager/Story.pressed.connect(_on_story_pressed)
	$ButtonManager/Controls.pressed.connect(_on_controls_pressed)

	setup_hover($ButtonManager/Start)
	setup_hover($ButtonManager/Quit)
	setup_hover($ButtonManager/Controls)
	setup_hover($ButtonManager/Story)

func _on_start_pressed():
	get_tree().change_scene_to_file(level1_scene)

func _on_quit_pressed():
	get_tree().quit()

func _on_story_pressed():
	var dialog = AcceptDialog.new()
	dialog.title = "Story"
	dialog.dialog_text = "You are a cat in an abandoned, underground place and you need to escape and bounce back to the surface from your hardship. \nYour aim is to throw your ball to hit the heavy lever for a ladder to appear to the next level."
	add_child(dialog)
	dialog.popup_centered()
	
func _on_controls_pressed():
	var dialog = AcceptDialog.new()
	dialog.title = "Controls"
	dialog.dialog_text = "ASWD or arrow keys for movement. \nE to launch and mouse to direct the ball. \nR to restart the level.\nYou cannot move when holding the heavy ball."
	add_child(dialog)
	dialog.popup_centered()
	
func go_to_level1():
	get_tree().change_scene_to_file(level1_scene)

func go_to_level2():
	get_tree().change_scene_to_file(level2_scene)

func go_to_level3():
	get_tree().change_scene_to_file(level3_scene)


func setup_hover(button: Button):

	button.pivot_offset = button.size / 2

	button.mouse_entered.connect(
		func(): animate_hover(button, true)
	)

	button.mouse_exited.connect(
		func(): animate_hover(button, false)
	)


func animate_hover(button: Button, hovering: bool):

	# Stop any previous animation
	if hover_tweens.has(button):
		hover_tweens[button].kill()

	var tween = create_tween()
	hover_tweens[button] = tween

	tween.set_parallel(true)

	if hovering:

		tween.tween_property(
			button,
			"scale",
			Vector2(hover_scale, hover_scale),
			0.15
		)

		tween.tween_property(
			button,
			"modulate",
			hover_color,
			0.15
		)

	else:

		tween.tween_property(
			button,
			"scale",
			Vector2(normal_scale, normal_scale),
			0.15
		)

		tween.tween_property(
			button,
			"modulate",
			normal_color,
			0.15
		)
