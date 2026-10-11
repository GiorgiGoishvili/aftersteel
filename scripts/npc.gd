extends Node2D

## A villager who stands still, plays an idle, and talks when Kiren presses
## E beside them. Can hand over one gift per playthrough.
##
## This script never moves the NPC: place it wherever you like in the
## scene. Its look comes from the AnimatedSprite2D's SpriteFrames.

@export var speaker := ""
@export var idle_animation := &"FIdle"
## Multiplies the idle's playback speed (1.0 = the SpriteFrames' own speed).
@export var animation_speed := 1.0

## Said the first time - the conversation that comes with the gift.
@export var first_lines: Array[String] = []
## Said every time after the gift has been given.
@export var repeat_lines: Array[String] = []

## Item id from items.gd, handed over once with the first conversation.
@export var gift_item_id := ""
@export var gift_count := 1
## Unique per gift. GameState remembers it, so talking again or coming
## back to the map never gives it twice.
@export var gift_id := ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var talk: Interactable = $Talk


func _ready() -> void:
	sprite.speed_scale = animation_speed
	sprite.play(idle_animation)
	talk.interacted.connect(_on_talk)


func _on_talk() -> void:
	var lines := _greeting()

	if not lines.is_empty():
		Dialogue.start(lines)


## The usual conversation: first_lines with the gift the first time,
## repeat_lines after. Hands the gift over as it builds the lines.
func _greeting() -> Array:
	var giving := _gift_due()
	var source := first_lines if giving or repeat_lines.is_empty() else repeat_lines
	var lines := _spoken(source)

	if giving:
		var item := Items.by_id(gift_item_id)

		if item.is_empty():
			push_warning("%s: unknown gift item '%s'" % [name, gift_item_id])
		else:
			# Recorded before anything else, so nothing can hand it over twice.
			GameState.mark_gift_received(gift_id)
			GameState.add_item(item, gift_count)
			var count := " x%d" % gift_count if gift_count > 1 else ""
			lines.append({ "text": "Received: %s%s" % [item["name"], count] })

	return lines


func _gift_due() -> bool:
	return gift_item_id != "" and gift_id != "" and not GameState.has_received_gift(gift_id)


## Dialogue lines spoken by this NPC.
func _spoken(texts: Array) -> Array:
	var lines: Array = []

	for text in texts:
		lines.append({ "speaker": speaker, "text": text })

	return lines
