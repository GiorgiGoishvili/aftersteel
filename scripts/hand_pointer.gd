extends AnimatedSprite2D

## The animated hand pointer (Fingerpointingdirectionsanimation.png). Drop
## hand_pointer.tscn into a scene, set `direction`, and it loops that
## animation at its authored 100 ms a frame. Show / hide it like any node.
##
## The animations keep their Aseprite tag names. Mind the F/B tags: in the
## art, FPoint's finger points up and BPoint's points down.

const ANIMATIONS := {
	"up": &"FPoint",
	"down": &"BPoint",
	"left": &"LPoint",
	"right": &"RPoint",
}

## Which way the finger points.
@export_enum("up", "down", "left", "right") var direction := "down":
	set(value):
		direction = value
		if is_node_ready():
			play(ANIMATIONS[direction])


func _ready() -> void:
	play(ANIMATIONS[direction])
