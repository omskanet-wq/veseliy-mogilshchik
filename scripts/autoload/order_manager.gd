extends Node
## OrderManager — generates client orders and tracks their lifecycle.
##
## Each order describes a deceased person who needs burial:
##   - desired_luxury (low/mid/high) — how fancy the relatives want it.
##   - budget — the max sum the relatives can afford.
##   - deadline_day — must be completed before TimeManager.current_day exceeds this.
##   - assigned_cell — set when the player accepts an order on a particular plot.
##
## An order is fulfilled when:
##   1. The plot is dug.
##   2. The decoration cost is between the "minimum decency" and the budget.
##   3. The deceased's name is engraved on the tombstone.
##   4. The current day is on or before the deadline.

signal order_offered(order: Dictionary)
signal order_completed(order: Dictionary, profit: int)
signal order_failed(order: Dictionary, reason: String)

enum LuxuryTier { LOW, MID, HIGH }

const LUXURY_BUDGETS := {
	LuxuryTier.LOW: Vector2i(120, 220),
	LuxuryTier.MID: Vector2i(260, 420),
	LuxuryTier.HIGH: Vector2i(480, 800),
}
const LUXURY_DEADLINE := {
	LuxuryTier.LOW: Vector2i(2, 4),
	LuxuryTier.MID: Vector2i(3, 5),
	LuxuryTier.HIGH: Vector2i(4, 7),
}
const LUXURY_LABEL := {
	LuxuryTier.LOW: "Скромно",
	LuxuryTier.MID: "Достойно",
	LuxuryTier.HIGH: "По-богатому",
}

var pending_orders: Array[Dictionary] = []
var active_orders: Array[Dictionary] = []
var completed_orders: Array[Dictionary] = []
var failed_orders: Array[Dictionary] = []

var _next_id: int = 1


func _ready() -> void:
	TimeManager.day_changed.connect(_on_day_changed)
	# Seed first orders on game start.
	call_deferred("_seed_initial_orders")


func _seed_initial_orders() -> void:
	for i in 2:
		offer_new_order()


func offer_new_order() -> Dictionary:
	var deceased: Dictionary = NameGenerator.random_full_name()
	var relative: Dictionary = NameGenerator.random_full_name()
	var tier_values: Array = LuxuryTier.values()
	var tier: int = tier_values[randi() % tier_values.size()]
	var budget_range: Vector2i = LUXURY_BUDGETS[tier]
	var deadline_range: Vector2i = LUXURY_DEADLINE[tier]
	var budget: int = randi_range(budget_range.x, budget_range.y)
	var deadline_offset: int = randi_range(deadline_range.x, deadline_range.y)
	var order: Dictionary = {
		"id": _next_id,
		"deceased_name": deceased["full"],
		"deceased_short": deceased["short"],
		"relative_name": relative["short"],
		"luxury": tier,
		"budget": budget,
		"min_decency": int(budget * 0.4),
		"deadline_day": TimeManager.current_day + deadline_offset,
		"assigned_cell": null,
		"state": "pending", # pending -> active -> done/failed
	}
	_next_id += 1
	pending_orders.append(order)
	order_offered.emit(order)
	return order


func accept_order(order_id: int, cell) -> bool:
	var order: Dictionary = _find(pending_orders, order_id)
	if order.is_empty():
		return false
	order["assigned_cell"] = cell
	order["state"] = "active"
	pending_orders.erase(order)
	active_orders.append(order)
	return true


func get_order_for_cell(cell) -> Dictionary:
	for order in active_orders:
		if order["assigned_cell"] == cell:
			return order
	return {}


func try_complete_order(order_id: int, decoration_cost: int) -> Dictionary:
	## Returns a result dict: {success: bool, profit: int, reason: String}
	var order: Dictionary = _find(active_orders, order_id)
	if order.is_empty():
		return {"success": false, "profit": 0, "reason": "Заказ не найден"}
	if TimeManager.current_day > order["deadline_day"]:
		return _fail(order, "Просрочено")
	if decoration_cost > order["budget"]:
		return _fail(order, "Слишком шикарно — родственники не смогут заплатить")
	if decoration_cost < order["min_decency"]:
		return _fail(order, "Слишком скромно — позор для семьи")
	var profit: int = order["budget"] - decoration_cost
	order["state"] = "done"
	order["profit"] = profit
	active_orders.erase(order)
	completed_orders.append(order)
	Economy.add_money(order["budget"], "Заказ %s" % order["deceased_short"])
	order_completed.emit(order, profit)
	return {"success": true, "profit": profit, "reason": "Заказ выполнен"}


func _fail(order: Dictionary, reason: String) -> Dictionary:
	order["state"] = "failed"
	order["fail_reason"] = reason
	active_orders.erase(order)
	failed_orders.append(order)
	order_failed.emit(order, reason)
	return {"success": false, "profit": 0, "reason": reason}


func _on_day_changed(_new_day: int) -> void:
	# Auto-fail overdue active orders.
	var to_fail: Array[Dictionary] = []
	for order in active_orders:
		if TimeManager.current_day > order["deadline_day"]:
			to_fail.append(order)
	for order in to_fail:
		_fail(order, "Просрочено — клиент ушёл к конкурентам")
	# Periodically offer new pending orders.
	if pending_orders.size() < 3 and randf() < 0.7:
		offer_new_order()


func _find(arr: Array[Dictionary], order_id: int) -> Dictionary:
	for o in arr:
		if o["id"] == order_id:
			return o
	return {}


func reset() -> void:
	pending_orders.clear()
	active_orders.clear()
	completed_orders.clear()
	failed_orders.clear()
	_next_id = 1
	_seed_initial_orders()
