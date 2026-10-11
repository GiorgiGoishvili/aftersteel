class_name QuestTargets
extends RefCounted

## Where each objective is, for the quest pointer. GameState.objective_target
## holds one of the keys below; set_objective() callers choose it, so nothing
## is read from the objective text.
##
## A target lives in one map. From any other map the pointer heads for the
## exit toward it (routed through the maps in between), never through walls.

## key: [map root name, node path in that map]
const TARGETS := {
	"bedroom_chest": ["KirenEiraBedroom", "Chest"],
	"eira": ["KirenEiraHouseInterior", "EiraTalk"],
	"woodpile": ["Village", "Props/Woodpile"],
	"fireplace": ["KirenEiraHouseInterior", "Fireplace"],
	"welf": ["Village", "NPCs/Welf"],
	"slime_clearing": ["WesternOutskirts", "Encounters/Map1Slime01"],
}

## map: {neighbouring map: the exit (trigger) node that leads there}
const EXITS := {
	"KirenEiraBedroom": {
		"KirenEiraHouseInterior": "GoToLivingRoom",
	},
	"KirenEiraHouseInterior": {
		"KirenEiraBedroom": "GoToBedroom",
		"Village": "ExitToVillage",
	},
	"Village": {
		"KirenEiraHouseInterior": "KirenEiraHouse/EnterHouse",
		"WesternOutskirts": "Triggers2/ToWesternOutskirts",
	},
	"WesternOutskirts": {
		"Village": "Triggers/ToVillage",
		"WesternRiver": "Triggers/ToWesternRiver",
	},
	"WesternRiver": {
		"WesternOutskirts": "Triggers/ToWesternOutskirts",
	},
}


## Where the pointer should lead in this map: the target, or the exit toward
## it. null when the key is unknown or there is no way there.
static func locate(map: Node, target: String) -> Variant:
	if map == null or not TARGETS.has(target):
		return null

	var spec: Array = TARGETS[target]
	var here := str(map.name)
	var path: String = spec[1]

	if spec[0] != here:
		var hop := next_map(here, spec[0])
		if hop == "":
			return null
		path = EXITS[here][hop]

	var node := map.get_node_or_null(path) as Node2D

	if node == null:
		return null

	# Triggers and talk areas keep their position on the collision shape.
	for child in node.get_children():
		if child is CollisionShape2D:
			return child.global_position

	return node.global_position


## The neighbouring map to walk into next on the way from one map to another.
static func next_map(from: String, to: String) -> String:
	if from == to or not EXITS.has(from):
		return ""

	var came_from := { from: "" }
	var queue: Array[String] = [from]

	while not queue.is_empty():
		var map: String = queue.pop_front()
		for next: String in EXITS.get(map, {}):
			if came_from.has(next):
				continue
			came_from[next] = map
			if next == to:
				var step := next
				while came_from[step] != from:
					step = came_from[step]
				return step
			queue.append(next)

	return ""
