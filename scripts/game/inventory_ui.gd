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

var hotbar_slots: Array = []
var inventory_slots: Array = []
var selected_slot: int = 0

func _ready() -> void:
	# Build hotbar slots
	for i in range(HOTBAR_SIZE):
		var slot = ItemSlot.instantiate()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		hotbar.add_child(slot)
		hotbar_slots.append(slot)
	hotbar_slots[0].set_selected(true)

	# Build inventory grid slots
	for i in range(INVENTORY_SIZE):
		var slot = ItemSlot.instantiate()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		grid.add_child(slot)
		inventory_slots.append(slot)

	inventory_panel.hide()

func _input(event: InputEvent) -> void:
	# Toggle inventory
	if event.is_action_pressed("toggle_inventory"):
		inventory_panel.visible = !inventory_panel.visible

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
		if i < inventory.size():
			hotbar_slots[i].set_slot(inventory[i].item_id, inventory[i].count)
		else:
			hotbar_slots[i].clear_slot()
	for i in range(INVENTORY_SIZE):
		if i < inventory.size():
			inventory_slots[i].set_slot(inventory[i].item_id, inventory[i].count)
		else:
			inventory_slots[i].clear_slot()
