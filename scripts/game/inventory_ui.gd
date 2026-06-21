# inventory_ui.gd
extends Control

const HOTBAR_SIZE := 8
const INVENTORY_SIZE := 24
const CAMERA_ZOOM := 4
const SLOT_SIZE := 16 * CAMERA_ZOOM 

const ItemSlot := preload("res://scenes/ui/item_slot.tscn")

@onready var hotbar: HBoxContainer = %HotbarContainer
@onready var inventory_panel: Panel = %InventoryPanel
@onready var grid: GridContainer = %InventorySlots
@onready var world_drop_zone: Control = $WorldDropZone

var hotbar_slots: Array = []
var inventory_slots: Array = []
var selected_slot: int = 0

func _ready() -> void:
	for i in range(HOTBAR_SIZE):
		var slot = ItemSlot.instantiate()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.slot_index = i
		hotbar.add_child(slot)
		hotbar_slots.append(slot)
	hotbar_slots[0].set_selected(true)

	for i in range(INVENTORY_SIZE):
		var slot = ItemSlot.instantiate()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.slot_index = i
		grid.add_child(slot)
		inventory_slots.append(slot)
	
	world_drop_zone.hide()
	inventory_panel.hide()

func _input(event: InputEvent) -> void:
	# Toggle inventory
	if event.is_action_pressed("toggle_inventory"):
		inventory_panel.visible = !inventory_panel.visible
		world_drop_zone.visible = inventory_panel.visible
		
	# Hotbar selection via number keys
	for i in range(HOTBAR_SIZE):
		if event.is_action_pressed("hotbar_" + str(i + 1)):
			set_selected_slot(i)

	# Scroll wheel cycles hotbar
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_selected_slot((selected_slot - 1 + HOTBAR_SIZE) % HOTBAR_SIZE)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_selected_slot((selected_slot + 1) % HOTBAR_SIZE)

func set_selected_slot(index: int) -> void:
	hotbar_slots[selected_slot].set_selected(false)
	selected_slot = index
	hotbar_slots[selected_slot].set_selected(true)

func refresh(inventory: Array) -> void:
	for i in range(HOTBAR_SIZE):
		if i < inventory.size() and inventory[i]["item_id"] != "":
			hotbar_slots[i].set_slot(inventory[i]["item_id"], inventory[i]["count"])
		else:
			hotbar_slots[i].clear_slot()
	for i in range(INVENTORY_SIZE):
		if i < inventory.size() and inventory[i]["item_id"] != "":
			inventory_slots[i].set_slot(inventory[i]["item_id"], inventory[i]["count"])
		else:
			inventory_slots[i].clear_slot()

func move_slot(from_index: int, to_index: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var inv = player.inventory
	if from_index >= inv.size() or to_index >= inv.size():
		return
	var temp = inv[from_index].duplicate()
	inv[from_index] = inv[to_index].duplicate()
	inv[to_index] = temp
	player.inventory_changed.emit(player.inventory)

func drop_to_world(slot_index: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or slot_index >= player.inventory.size():
		return
	var slot = player.inventory[slot_index]
	if slot["item_id"] == "":
		return
	var world_gen = get_tree().get_first_node_in_group("world_gen")
	if world_gen:
		world_gen.drop_item_at(player.get_tile_pos(), slot["item_id"], slot["count"])
	player.inventory[slot_index] = { "item_id": "", "count": 0 }
	player.inventory_changed.emit(player.inventory)

func add_slots(count: int) -> void:
	for i in range(count):
		var slot = ItemSlot.instantiate()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.slot_index = inventory_slots.size()
		grid.add_child(slot)
		inventory_slots.append(slot)
		
func remove_slots(count: int) -> void:
	for i in range(count):
		if inventory_slots.is_empty():
			break
		var slot = inventory_slots.pop_back()
		slot.queue_free()
