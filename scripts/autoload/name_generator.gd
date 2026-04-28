extends Node
## NameGenerator — random Russian-style first + last names with patronymics.

const FIRST_NAMES_M: Array[String] = [
	"Иван", "Пётр", "Алексей", "Николай", "Михаил",
	"Сергей", "Андрей", "Дмитрий", "Владимир", "Юрий",
	"Анатолий", "Виктор", "Григорий", "Леонид", "Фёдор",
	"Афанасий", "Прохор", "Игнат", "Захар", "Кузьма",
]
const FIRST_NAMES_F: Array[String] = [
	"Анна", "Мария", "Татьяна", "Ольга", "Елена",
	"Ирина", "Наталья", "Светлана", "Людмила", "Галина",
	"Зинаида", "Прасковья", "Аграфена", "Ефросинья", "Степанида",
]
const LAST_NAMES: Array[String] = [
	"Иванов", "Петров", "Сидоров", "Кузнецов", "Смирнов",
	"Попов", "Соколов", "Лебедев", "Козлов", "Новиков",
	"Морозов", "Волков", "Зайцев", "Павлов", "Семёнов",
	"Гробовщиков", "Могильный", "Тёмный", "Печальный", "Скорбный",
]
const PATRONYMICS_M: Array[String] = [
	"Иванович", "Петрович", "Алексеевич", "Николаевич",
	"Михайлович", "Сергеевич", "Андреевич", "Дмитриевич",
]
const PATRONYMICS_F: Array[String] = [
	"Ивановна", "Петровна", "Алексеевна", "Николаевна",
	"Михайловна", "Сергеевна", "Андреевна", "Дмитриевна",
]


func random_full_name() -> Dictionary:
	var is_male: bool = randi() % 2 == 0
	var first: String = (FIRST_NAMES_M if is_male else FIRST_NAMES_F).pick_random()
	var patron: String = (PATRONYMICS_M if is_male else PATRONYMICS_F).pick_random()
	var last: String = LAST_NAMES.pick_random()
	if not is_male:
		# Adjust common -ов/-ев to -ова/-ева.
		if last.ends_with("ов") or last.ends_with("ев") or last.ends_with("ин"):
			last += "а"
		elif last.ends_with("ый"):
			last = last.left(last.length() - 2) + "ая"
		elif last.ends_with("ой"):
			last = last.left(last.length() - 2) + "ая"
	return {
		"first": first,
		"patronymic": patron,
		"last": last,
		"full": "%s %s %s" % [first, patron, last],
		"short": "%s %s" % [first, last],
		"is_male": is_male,
	}
