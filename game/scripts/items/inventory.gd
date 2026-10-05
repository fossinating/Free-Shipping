class_name Inventory
extends Node
## A few item slots on a robot. One slot can be equipped: its item shows in
## the robot's hand, so an equipped tool is contraband in plain sight and
## an equipped disguise is working. Holstering (no slot selected) hides
## everything. Attach as a child named "Inventory" of a RobotBody.

signal changed
## Something worth telling the player happened ("Inventory full").
signal message(text: String)

const SLOT_COUNT := 4
## Seconds between swings.
const SWING_COOLDOWN := 0.5

## Slot contents (ItemState or null).
var slots: Array[ItemState] = []
## Equipped slot, or -1 when holstered.
var selected := -1

var _swing_cooldown := 0.0
var _hand_mesh: MeshInstance3D

@onready var robot: RobotBody = get_parent()


static func of(body: RobotBody) -> Inventory:
	return body.get_node_or_null(^"Inventory") as Inventory if body else null


func _ready() -> void:
	slots.resize(SLOT_COUNT)
	robot.grabbed.connect(_on_grabbed)
	_hand_mesh = MeshInstance3D.new()
	_hand_mesh.name = "EquippedItem"
	robot.get_node(^"Visual/Core/RightArm/Hand").add_child(_hand_mesh)
	changed.connect(_update_hand)
	_update_hand()


func _physics_process(delta: float) -> void:
	_swing_cooldown = maxf(0.0, _swing_cooldown - delta)


## The equipped item, or null when holstered or the slot is empty.
func get_equipped() -> ItemState:
	return slots[selected] if selected >= 0 else null


func is_full() -> bool:
	return not slots.has(null)


func count(id: StringName) -> int:
	var total := 0
	for state in slots:
		if state and state.id == id:
			total += 1
	return total


func get_items() -> Array[ItemState]:
	var items: Array[ItemState] = []
	for state in slots:
		if state:
			items.append(state)
	return items


## Puts an item in the first free slot. Returns false if full.
func add(state: ItemState) -> bool:
	var slot := slots.find(null)
	if slot < 0:
		return false
	slots[slot] = state
	GameState.note_held(state.id)
	changed.emit()
	return true


func remove(state: ItemState) -> bool:
	var slot := slots.find(state)
	if slot < 0:
		return false
	slots[slot] = null
	changed.emit()
	return true


## Selects the next slot, wrapping through "holstered".
func cycle() -> void:
	selected += 1
	if selected >= SLOT_COUNT:
		selected = -1
	changed.emit()


func select(slot: int) -> void:
	selected = clampi(slot, -1, SLOT_COUNT - 1)
	changed.emit()


## Puts the item in the robot's hands into a slot. Returns whether it did.
func stow_held() -> bool:
	var item := robot.held as Item
	if item == null:
		if robot.held:
			message.emit("Packages don't fit in your inventory")
		return false
	if is_full():
		message.emit("Inventory full")
		return false
	robot.held = null
	robot.let_go.emit(item)
	add(item.state)
	item.queue_free()
	return true


## Takes the equipped item out into the robot's hands, where it can be set
## down or thrown. Returns whether it did.
func take_out() -> bool:
	var state := get_equipped()
	if state == null or robot.held:
		return false
	remove(state)
	var item := Item.spawn(state, robot.get_parent(), robot.get_hold_position())
	robot.grab(item)
	return true


## Uses the equipped item: swing a tool, trigger a disguise, install an
## upgrade. Returns a short message for the HUD, or "".
func use_equipped() -> String:
	var state := get_equipped()
	if state == null:
		return ""
	match state.get_kind():
		ItemCatalog.Kind.TOOL:
			return _swing(state)
		ItemCatalog.Kind.DISGUISE:
			return _use_disguise(state)
		ItemCatalog.Kind.UPGRADE:
			remove(state)
			GameState.install_upgrade(state.id)
			return "Installed %s" % state.get_name()
	return "%s is for crafting and repairs" % state.get_name()


func can_swing() -> bool:
	var state := get_equipped()
	return state != null and state.get_kind() == ItemCatalog.Kind.TOOL \
		and not state.is_broken() and _swing_cooldown <= 0.0 and robot.held == null


## Clearance a robot's equipped disguise adds (a fake ID tag).
static func clearance_bonus(body: RobotBody) -> int:
	var inventory := of(body)
	var state := inventory.get_equipped() if inventory else null
	return state.get_def().get("clearance_bonus", 0) if state else 0


## Whether the robot carries contraband at all, even stowed away. Scanners
## see through your casing; cameras don't.
static func carries_contraband(body: RobotBody) -> bool:
	if shows_contraband(body):
		return true
	var inventory := of(body)
	if inventory:
		for state in inventory.get_items():
			if state.is_contraband():
				return true
	return false


## Whether the robot is showing contraband: holding it, or equipped.
static func shows_contraband(body: RobotBody) -> bool:
	if body.held and body.held.contraband:
		return true
	var inventory := of(body)
	var state := inventory.get_equipped() if inventory else null
	return state != null and state.is_contraband()


func _swing(state: ItemState) -> String:
	if state.is_broken():
		return "%s is broken. Repair it at your dock" % state.get_name()
	if robot.held:
		return "Your hands are full"
	if _swing_cooldown > 0.0:
		return ""
	_swing_cooldown = SWING_COOLDOWN
	var victim := Combat.swing(robot, state)
	_animate_swing()
	changed.emit()
	if state.is_broken():
		return "%s broke" % state.get_name()
	return "Hit!" if victim else ""


func _use_disguise(state: ItemState) -> String:
	if state.uses < 0:
		return "%s works while equipped" % state.get_name()
	if state.uses == 0:
		return "%s is out of charge" % state.get_name()
	state.uses -= 1
	# A delivery that never happened: counts for the quota, and the quota
	# relieves suspicion like a real one.
	Quota.record_delivery(null)
	if state.uses == 0:
		remove(state)
		return "Delivery logged. %s used up" % state.get_name()
	changed.emit()
	return "Delivery logged (%d left)" % state.uses


func _on_grabbed(package: Package) -> void:
	var item := package as Item
	if item == null:
		return
	GameState.note_held(item.state.id)
	var level := ItemCatalog.clearance_of(item.state.id)
	if level > 0:
		# Keycards go straight into your badge.
		robot.held = null
		robot.let_go.emit(item)
		item.queue_free()
		if level > GameState.clearance:
			GameState.grant_clearance(level)
			message.emit("Badge updated: clearance %d" % level)
		else:
			message.emit("Your badge already has clearance %d" % GameState.clearance)


func _update_hand() -> void:
	var state := get_equipped()
	_hand_mesh.visible = state != null
	if state == null:
		return
	var def := state.get_def()
	var mesh := BoxMesh.new()
	mesh.size = def.get("size", Vector3(0.2, 0.2, 0.2)) * 0.8
	_hand_mesh.mesh = mesh
	_hand_mesh.position = Vector3(0, 0, -mesh.size.z / 2.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = def.get("color", Color.WHITE)
	_hand_mesh.material_override = material


func _animate_swing() -> void:
	var tween := create_tween()
	_hand_mesh.rotation = Vector3.ZERO
	tween.tween_property(_hand_mesh, "rotation:y", deg_to_rad(-80.0), 0.08)
	tween.tween_property(_hand_mesh, "rotation:y", 0.0, 0.2)
