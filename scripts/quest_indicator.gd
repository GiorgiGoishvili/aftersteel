extends AnimatedSprite2D

## The golden question mark (QuestionMark.png) over an NPC with something for
## Kiren to find: a first talk, a job to take or to hand in. The NPC decides
## when (its wants_attention()); this only follows it, sits a little above
## the NPC's head and plays the art's own loop - the wings, halo and bob are
## all in the frames. No collision and no input, so it never gets in the way,
## and it steps aside (hides) while Kiren stands over it.

## Space between the top of the NPC's head and the bottom of the mark.
const HEAD_GAP := 2.0
## Kiren's sprite around his centre, as quest_marker.gd measures it; edges
## that only touch don't count.
const KIREN := Vector2(16, 31)
const SLACK := 2.0

@onready var npc: Node2D = get_parent()


func _ready() -> void:
	visible = false
	play(&"Float")
	_place()


func _process(_delta: float) -> void:
	# Hidden while that NPC is mid-conversation; the talk usually settles it.
	var talking: bool = Dialogue.is_active() and npc.talk.is_player_in_range()
	visible = npc.wants_attention() and not talking and not _on_kiren()


func _on_kiren() -> bool:
	var kiren := get_tree().get_first_node_in_group("player") as Node2D

	if kiren == null:
		return false

	var size := sprite_frames.get_frame_texture(&"Float", 0).get_size() * scale
	var mark := Rect2(global_position - size / 2.0, size).grow(-SLACK)
	return mark.intersects(Rect2(kiren.global_position - KIREN / 2.0, KIREN).grow(-SLACK))


## Over the visible top of the NPC's sprite, centred on it, on whole pixels.
func _place() -> void:
	var body: AnimatedSprite2D = npc.get_node("AnimatedSprite2D")
	var head := Rect2(body.position, Vector2.ZERO)

	if body.sprite_frames != null and body.sprite_frames.has_animation(body.animation):
		var tex := body.sprite_frames.get_frame_texture(body.animation, 0)
		var top_left: Vector2 = body.position + body.offset - (tex.get_size() / 2.0 if body.centered else Vector2.ZERO)
		var used := _opaque(tex)
		head = Rect2(top_left + used.position, used.size)

	# The mark's own lowest visible pixel, below its centre.
	var mark := sprite_frames.get_frame_texture(&"Float", 0)
	var below := (_opaque(mark).end.y - mark.get_size().y / 2.0) * scale.y

	position = Vector2(head.get_center().x, head.position.y - HEAD_GAP - below).round()


static func _opaque(tex: Texture2D) -> Rect2:
	var img := tex.get_image()
	return Rect2(img.get_used_rect()) if img != null else Rect2(Vector2.ZERO, tex.get_size())
