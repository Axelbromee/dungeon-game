class_name Inventory
extends Node
## Slot-based item storage. Pure data: UI listens to `slot_changed`.
## The first `hotbar_size` slots are the hotbar; the rest is the bag.

signal slot_changed(index: int)

@export_range(1, 200) var slot_count: int = 24
## Set by the Player. Slots [0, hotbar_size) are the hotbar.
@export var hotbar_size: int = 9

var _items: Array[InventoryItem] = []
var _counts: Array[int] = []


func _ready() -> void:
	_items.resize(slot_count)
	_counts.resize(slot_count)


func get_item(index: int) -> InventoryItem:
	return _items[index] if _valid(index) else null


func get_count(index: int) -> int:
	return _counts[index] if _valid(index) else 0


func is_hotbar(index: int) -> bool:
	return index >= 0 and index < hotbar_size


## Adds `amount` of `item`: tops up matching stacks anywhere first, then fills
## empty bag slots, and only uses empty hotbar slots once the bag is full.
## Returns how many did NOT fit (0 = everything was added).
func add_item(item: InventoryItem, amount: int = 1) -> int:
	if item == null or amount <= 0:
		return amount
	var bag_start := mini(hotbar_size, slot_count)
	var remaining := _fill_existing(item, amount, 0, slot_count)
	remaining = _fill_empty(item, remaining, bag_start, slot_count)
	return _fill_empty(item, remaining, 0, bag_start)


## Removes up to `amount` from one slot. Returns how many were removed.
func remove_from_slot(index: int, amount: int = 1) -> int:
	if not _valid(index) or _items[index] == null or amount <= 0:
		return 0
	var removed := mini(amount, _counts[index])
	_counts[index] -= removed
	if _counts[index] <= 0:
		_clear(index)
	slot_changed.emit(index)
	return removed


## Whether move_slot(from, to, amount) would do anything.
func can_move(from: int, to: int, amount: int = -1) -> bool:
	if from == to or not _valid(from) or not _valid(to) or _items[from] == null:
		return false
	var moving := _moving_amount(from, amount)
	var target := _items[to]
	if target == null:
		return true
	if _items[from].stackable and _items[from].is_same_item(target):
		return _counts[to] < target.get_stack_limit() or moving == _counts[from]
	return moving == _counts[from]  # Different item: only a whole stack can swap.


## Drag/drop rule. Same stackable item -> merge as much as fits; empty target
## -> place; different item -> swap (whole stacks only). `amount` < stack
## size moves part of the stack (e.g. Ctrl+drag half).
func move_slot(from: int, to: int, amount: int = -1) -> void:
	if not can_move(from, to, amount):
		return
	var a := _items[from]
	var b := _items[to]
	var moving := _moving_amount(from, amount)

	if b == null:
		_items[to] = a
		_counts[to] = moving
		_take(from, moving)
		_emit(from, to)
		return

	if a.stackable and a.is_same_item(b):
		var moved := mini(a.get_stack_limit() - _counts[to], moving)
		if moved > 0:
			_counts[to] += moved
			_take(from, moved)
			_emit(from, to)
			return
		# Target full: fall through and swap (a no-op for identical items).

	_items[from] = b
	_items[to] = a
	var count_from := _counts[from]
	_counts[from] = _counts[to]
	_counts[to] = count_from
	_emit(from, to)


## Moves half of a stack into an empty slot, preferring the same section
## (hotbar or bag). Returns the new slot, or -1 if it couldn't split.
func split_slot(index: int) -> int:
	if not _valid(index) or _items[index] == null or _counts[index] < 2:
		return -1
	var section := _section(index)
	var target := _find_empty(section.x, section.y)
	if target < 0:
		target = _find_empty(0, slot_count)
	if target < 0:
		return -1
	move_slot(index, target, _counts[index] / 2)
	return target


## Shift+click: send a stack from the hotbar to the bag or back, merging into
## matching stacks first. Whatever doesn't fit stays where it was.
func quick_move(index: int) -> void:
	if not _valid(index) or _items[index] == null:
		return
	var item := _items[index]
	var start := hotbar_size if is_hotbar(index) else 0
	var end := slot_count if is_hotbar(index) else mini(hotbar_size, slot_count)
	var amount := _counts[index]
	var remaining := _fill_existing(item, amount, start, end)
	remaining = _fill_empty(item, remaining, start, end)
	_counts[index] = remaining
	if remaining <= 0:
		_clear(index)
	slot_changed.emit(index)


## Double-click: pull every matching item into this slot, up to its limit.
func gather(index: int) -> void:
	if not _valid(index) or _items[index] == null or not _items[index].stackable:
		return
	var item := _items[index]
	var limit := item.get_stack_limit()
	for i in slot_count:
		if _counts[index] >= limit:
			break
		if i == index or not item.is_same_item(_items[i]):
			continue
		var moved := mini(limit - _counts[index], _counts[i])
		_counts[index] += moved
		_take(i, moved)
		slot_changed.emit(i)
	slot_changed.emit(index)


## Sorts the bag (never the hotbar): merges partial stacks, then orders by
## grade (best first), category, then name.
func sort_bag() -> void:
	var start := mini(hotbar_size, slot_count)
	var entries: Array = []  # [item, total]
	for i in range(start, slot_count):
		var item := _items[i]
		if item == null:
			continue
		var merged := false
		if item.stackable:
			for entry in entries:
				if (entry[0] as InventoryItem).is_same_item(item):
					entry[1] += _counts[i]
					merged = true
					break
		if not merged:
			entries.append([item, _counts[i]])

	entries.sort_custom(func(x: Array, y: Array) -> bool:
		var a: InventoryItem = x[0]
		var b: InventoryItem = y[0]
		if a.grade != b.grade:
			return a.grade < b.grade  # S (0) first.
		if a.category != b.category:
			return a.category < b.category
		return a.item_name.naturalnocasecmp_to(b.item_name) < 0
	)

	for i in range(start, slot_count):
		_clear(i)
	var slot := start
	for entry in entries:
		var item: InventoryItem = entry[0]
		var total: int = entry[1]
		while total > 0 and slot < slot_count:
			var stack := mini(total, item.get_stack_limit())
			_items[slot] = item
			_counts[slot] = stack
			total -= stack
			slot += 1
	for i in range(start, slot_count):
		slot_changed.emit(i)


## Directly sets a slot (null item or count <= 0 clears it).
func set_slot(index: int, item: InventoryItem, count: int) -> void:
	if not _valid(index):
		return
	if item == null or count <= 0:
		_clear(index)
	else:
		_items[index] = item
		_counts[index] = mini(count, item.get_stack_limit())
	slot_changed.emit(index)


# --- Moving between two inventories (chest <-> bag) -------------------------

## Same rules as can_move, but `src` and `dst` may be different inventories.
static func can_transfer(src: Inventory, from: int, dst: Inventory, to: int, amount: int = -1) -> bool:
	if src == dst:
		return src.can_move(from, to, amount)
	var item := src.get_item(from)
	if item == null or not dst._valid(to):
		return false
	var moving := src._moving_amount(from, amount)
	var target := dst.get_item(to)
	if target == null:
		return true
	if item.stackable and item.is_same_item(target):
		return dst.get_count(to) < target.get_stack_limit() or moving == src.get_count(from)
	return moving == src.get_count(from)


static func transfer(src: Inventory, from: int, dst: Inventory, to: int, amount: int = -1) -> void:
	if src == dst:
		src.move_slot(from, to, amount)
		return
	if not can_transfer(src, from, dst, to, amount):
		return
	var item := src.get_item(from)
	var moving := src._moving_amount(from, amount)
	var target := dst.get_item(to)
	if target == null:
		dst.set_slot(to, item, moving)
		src.set_slot(from, item, src.get_count(from) - moving)
		return
	if item.stackable and item.is_same_item(target):
		var moved := mini(target.get_stack_limit() - dst.get_count(to), moving)
		if moved > 0:
			dst.set_slot(to, target, dst.get_count(to) + moved)
			src.set_slot(from, item, src.get_count(from) - moved)
			return
	# Whole-stack swap.
	var target_count := dst.get_count(to)
	var item_count := src.get_count(from)
	dst.set_slot(to, item, item_count)
	src.set_slot(from, target, target_count)


## Moves a whole stack into `dst` using its normal add rules. What doesn't
## fit stays in the source slot.
static func send_stack(src: Inventory, from: int, dst: Inventory) -> void:
	var item := src.get_item(from)
	if item == null:
		return
	var leftover := dst.add_item(item, src.get_count(from))
	src.set_slot(from, item, leftover)


# --- Saving -----------------------------------------------------------------

## One entry per slot: [item_path, count] or null for empty.
func to_data() -> Array:
	var data: Array = []
	for i in _items.size():
		var item := _items[i]
		data.append([item.resource_path, _counts[i]] if item and item.resource_path != "" else null)
	return data


func from_data(data: Array) -> void:
	for i in _items.size():
		var entry: Variant = data[i] if i < data.size() else null
		var item: InventoryItem = null
		var count := 0
		if entry is Array and (entry as Array).size() >= 2 and ResourceLoader.exists(str(entry[0])):
			item = load(str(entry[0])) as InventoryItem
			count = int(entry[1])
		if item == null or count <= 0:
			_clear(i)
		else:
			_items[i] = item
			_counts[i] = count
		slot_changed.emit(i)


# --- Helpers ----------------------------------------------------------------

func _fill_existing(item: InventoryItem, amount: int, start: int, end: int) -> int:
	var remaining := amount
	if not item.stackable:
		return remaining
	var limit := item.get_stack_limit()
	for i in range(start, end):
		if remaining <= 0:
			break
		if item.is_same_item(_items[i]) and _counts[i] < limit:
			var added := mini(limit - _counts[i], remaining)
			_counts[i] += added
			remaining -= added
			slot_changed.emit(i)
	return remaining


func _fill_empty(item: InventoryItem, amount: int, start: int, end: int) -> int:
	var remaining := amount
	var limit := item.get_stack_limit()
	for i in range(start, end):
		if remaining <= 0:
			break
		if _items[i] == null:
			var added := mini(limit, remaining)
			_items[i] = item
			_counts[i] = added
			remaining -= added
			slot_changed.emit(i)
	return remaining


func _find_empty(start: int, end: int) -> int:
	for i in range(start, end):
		if _items[i] == null:
			return i
	return -1


## (start, end) of the section containing `index`.
func _section(index: int) -> Vector2i:
	return Vector2i(0, mini(hotbar_size, slot_count)) if is_hotbar(index) else Vector2i(hotbar_size, slot_count)


func _moving_amount(from: int, amount: int) -> int:
	return _counts[from] if amount <= 0 else mini(amount, _counts[from])


func _take(index: int, amount: int) -> void:
	_counts[index] -= amount
	if _counts[index] <= 0:
		_clear(index)


func _clear(index: int) -> void:
	_items[index] = null
	_counts[index] = 0


func _emit(a: int, b: int) -> void:
	slot_changed.emit(a)
	slot_changed.emit(b)


func _valid(index: int) -> bool:
	return index >= 0 and index < _items.size()
