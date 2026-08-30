extends Area2D

## One thrown thing. Flies straight, damages whatever it touches once,
## then removes itself. Nothing more - there is no spell system here.

var velocity := Vector2.ZERO
var damage := 9
var life := 3.0
var _spent := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	life -= delta

	if life <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _spent:
		return

	var who := area.get_parent()

	if not who.has_method("take_damage"):
		return

	_spent = true
	who.take_damage(damage, global_position)
	queue_free()
