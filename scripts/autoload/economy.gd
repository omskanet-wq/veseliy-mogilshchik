extends Node
## Economy — tracks money (рубли) and crystals (бонусная валюта).
## Emits signals on any change so the HUD can refresh.

signal money_changed(new_money: int)
signal crystals_changed(new_crystals: int)
signal transaction(amount: int, reason: String)

const STARTING_MONEY: int = 500

var money: int = STARTING_MONEY
var crystals: int = 0


func add_money(amount: int, reason: String = "") -> void:
	money += amount
	money_changed.emit(money)
	transaction.emit(amount, reason)


func can_afford(amount: int) -> bool:
	return money >= amount


func spend(amount: int, reason: String = "") -> bool:
	if not can_afford(amount):
		return false
	money -= amount
	money_changed.emit(money)
	transaction.emit(-amount, reason)
	return true


func add_crystals(amount: int) -> void:
	crystals += amount
	crystals_changed.emit(crystals)


func spend_crystals(amount: int) -> bool:
	if crystals < amount:
		return false
	crystals -= amount
	crystals_changed.emit(crystals)
	return true


func reset() -> void:
	money = STARTING_MONEY
	crystals = 0
	money_changed.emit(money)
	crystals_changed.emit(crystals)
