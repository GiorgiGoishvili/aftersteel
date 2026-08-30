class_name LootContainer
extends Interactable

## A searchable container - barrel, crate, sack, chest.
##
## Contents are chosen by hand in the editor, never rolled at runtime:
## fill "item_ids" with ids from items.gd. The first search hands them all
## over, and after that the container stays empty for the rest of the run.
##
## Story containers that need their own dialogue (like the bedroom chest)
## should keep using plain Interactable plus a room script instead.

## Must be unique in the whole game - it is how GameState remembers that
## this particular container was already searched.
@export var container_id := ""

## Item ids from items.gd, handed over in order.
@export var item_ids: Array[String] = []


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)


func _on_interacted() -> void:
	if container_id == "":
		push_warning("LootContainer with no container_id: %s" % get_path())
		return

	if GameState.is_container_opened(container_id):
		Dialogue.start([
			{ "text": "Nothing else inside." }
		])
		return

	GameState.mark_container_opened(container_id)

	var lines: Array = []

	for id in item_ids:
		var item := Items.by_id(id)

		if item.is_empty():
			push_warning("LootContainer '%s': unknown item id '%s'" % [container_id, id])
			continue

		GameState.add_item(item)
		lines.append({ "text": "Found: %s" % item["name"] })

	if lines.is_empty():
		lines.append({ "text": "Nothing inside." })

	Dialogue.start(lines)
