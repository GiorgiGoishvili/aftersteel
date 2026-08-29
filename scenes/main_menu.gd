extends Node2D

@onready var rain: AnimatedSprite2D = $Rain
@onready var menu_intro: AnimatedSprite2D = $MenuIntro

@onready var credits_panel: Control = $CreditsPanel
@onready var credits_text: Label = $CreditsPanel/CreditsText

var credits_typing := false
var credits_speed := 0.10


func _ready():
	# Start menu animations
	menu_intro.play("menu_intro")
	rain.play("rain_start")

	# Credits hidden when menu first loads
	credits_panel.hide()

	# Prevent words from jumping while typewriter effect runs
	credits_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING


func _on_rain_animation_finished():
	if rain.animation == "rain_start":
		rain.play("rain_loop")


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/intro_black.tscn")


func _on_credits_button_pressed() -> void:
	credits_panel.show()
	start_credits_text()


func start_credits_text():
	credits_typing = true
	credits_text.visible_characters = 0

	for i in range(credits_text.text.length()):
		if not credits_typing:
			break

		credits_text.visible_characters += 1
		await get_tree().create_timer(credits_speed).timeout

	if credits_typing:
		credits_text.visible_characters = -1

	credits_typing = false


func _unhandled_input(event):
	# SPACE / ENTER while credits type = reveal everything instantly
	if credits_panel.visible and event.is_action_pressed("ui_accept"):
		if credits_typing:
			credits_typing = false
			credits_text.visible_characters = -1

	# ESC = close credits
	if credits_panel.visible and event.is_action_pressed("ui_cancel"):
		credits_typing = false
		credits_text.visible_characters = -1
		credits_panel.hide()
