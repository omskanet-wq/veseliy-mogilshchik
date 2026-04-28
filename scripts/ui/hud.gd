extends Control
## Top-level HUD. Builds and wires every UI sub-panel programmatically.

var game: Game
var main: Node

var _money_label: Label
var _crystals_label: Label
var _day_label: Label
var _log_label: Label
var _orders_list: VBoxContainer
var _tool_buttons: Dictionary = {}
var _name_dialog: AcceptDialog
var _name_input: LineEdit
var _name_target_cell: Cell
var _world_input: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_world_input_layer()
	_build_top_bar()
	_build_orders_panel()
	_build_tool_panel()
	_build_zoom_panel()
	_build_log_panel()
	_build_name_dialog()
	# Connect signals.
	Economy.money_changed.connect(_on_money_changed)
	Economy.crystals_changed.connect(_on_crystals_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	OrderManager.order_offered.connect(_on_order_changed)
	OrderManager.order_completed.connect(_on_order_changed)
	OrderManager.order_failed.connect(_on_order_changed)
	game.log_message.connect(_on_log)
	# Initial paint.
	_on_money_changed(Economy.money)
	_on_crystals_changed(Economy.crystals)
	_on_day_changed(TimeManager.current_day)
	_refresh_orders()


# ---------- World input layer ----------

func _build_world_input_layer() -> void:
	# A full-rect transparent control that catches taps that aren't on UI.
	_world_input = Control.new()
	_world_input.name = "WorldInput"
	_world_input.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world_input.mouse_filter = Control.MOUSE_FILTER_STOP
	_world_input.gui_input.connect(_on_world_gui_input)
	add_child(_world_input)


func _on_world_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			game.handle_world_click(mb.position)
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and t.index == 0:
			game.handle_world_click(t.position)


# ---------- Top bar ----------

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 0
	bar.offset_left = 0
	bar.offset_right = 0
	bar.offset_bottom = 60
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	bar.add_child(hbox)
	_day_label = _make_stat_label("День: 1")
	_money_label = _make_stat_label("₽ 500")
	_crystals_label = _make_stat_label("◆ 0")
	hbox.add_child(_day_label)
	hbox.add_child(_money_label)
	hbox.add_child(_crystals_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	var next_btn := Button.new()
	next_btn.text = "Следующий день ▶"
	next_btn.pressed.connect(func() -> void: game.advance_day())
	hbox.add_child(next_btn)


func _make_stat_label(initial: String) -> Label:
	var l := Label.new()
	l.text = initial
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	return l


# ---------- Orders panel (right side) ----------

func _build_orders_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "OrdersPanel"
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -300
	panel.offset_top = 70
	panel.offset_right = -10
	panel.offset_bottom = -240
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = "Заказы"
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)
	var sep := HSeparator.new()
	v.add_child(sep)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_orders_list = VBoxContainer.new()
	_orders_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_orders_list)


func _refresh_orders() -> void:
	for child in _orders_list.get_children():
		child.queue_free()
	_add_orders_section("Доступны", OrderManager.pending_orders, true)
	_add_orders_section("В работе", OrderManager.active_orders, false)
	if OrderManager.pending_orders.is_empty() and OrderManager.active_orders.is_empty():
		var lbl := Label.new()
		lbl.text = "Нет заказов. Нажми «Следующий день»."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_orders_list.add_child(lbl)


func _add_orders_section(title: String, list: Array, with_accept: bool) -> void:
	if list.is_empty():
		return
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_orders_list.add_child(header)
	for o in list:
		var card := _build_order_card(o, with_accept)
		_orders_list.add_child(card)


func _build_order_card(order: Dictionary, with_accept: bool) -> Control:
	var card := PanelContainer.new()
	var v := VBoxContainer.new()
	card.add_child(v)
	var name_l := Label.new()
	name_l.text = order["deceased_short"]
	name_l.add_theme_font_size_override("font_size", 18)
	v.add_child(name_l)
	var info := Label.new()
	info.text = "%s | %d ₽ | до дня %d" % [
		OrderManager.LUXURY_LABEL[order["luxury"]],
		order["budget"],
		order["deadline_day"],
	]
	info.add_theme_font_size_override("font_size", 14)
	v.add_child(info)
	var rel := Label.new()
	rel.text = "Родственник: %s" % order["relative_name"]
	rel.add_theme_font_size_override("font_size", 12)
	rel.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	v.add_child(rel)
	if with_accept:
		var btn := Button.new()
		btn.text = "Принять"
		btn.pressed.connect(func() -> void: _on_order_accept(order["id"]))
		v.add_child(btn)
	return card


func _on_order_accept(order_id: int) -> void:
	game.start_assign_for_order(order_id)


# ---------- Tool panel (bottom) ----------

func _build_tool_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "ToolPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -110
	panel.offset_left = 10
	panel.offset_right = -320
	panel.offset_bottom = -10
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)
	_make_tool_button(hbox, Game.TOOL_DIG, "⛏ Копать", "Вырыть отведённую могилу")
	_make_tool_button(hbox, Game.TOOL_TOMBSTONE_0, "▯ Камень\n%d ₽" % Game.TOMBSTONE_COSTS[0], "Простой надгробный камень")
	_make_tool_button(hbox, Game.TOOL_TOMBSTONE_1, "✝ Крест\n%d ₽" % Game.TOMBSTONE_COSTS[1], "Деревянный крест")
	_make_tool_button(hbox, Game.TOOL_TOMBSTONE_2, "▲ Обелиск\n%d ₽" % Game.TOMBSTONE_COSTS[2], "Богатый обелиск")
	_make_tool_button(hbox, Game.TOOL_FLOWERS, "❀ Цветы\n%d ₽" % Game.FLOWER_COST, "Украсить цветами")
	_make_tool_button(hbox, Game.TOOL_NAME, "✎ Имя", "Выбить имя на надгробии")
	_make_tool_button(hbox, Game.TOOL_PATH, "▦ Дорожка\n%d ₽" % Game.PATH_COST, "Положить дорожку")
	_make_tool_button(hbox, Game.TOOL_DEMOLISH, "✖ Снести", "Очистить клетку")


func _make_tool_button(parent: Control, tool_id: String, label: String, tooltip: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.tooltip_text = tooltip
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(96, 84)
	btn.pressed.connect(func() -> void: _on_tool_pressed(tool_id))
	parent.add_child(btn)
	_tool_buttons[tool_id] = btn


func _on_tool_pressed(tool_id: String) -> void:
	game.set_tool(tool_id)
	for id in _tool_buttons:
		(_tool_buttons[id] as Button).button_pressed = (id == tool_id)


# ---------- Zoom buttons ----------

func _build_zoom_panel() -> void:
	var panel := VBoxContainer.new()
	panel.name = "ZoomPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -90
	panel.offset_top = -200
	panel.offset_right = -10
	panel.offset_bottom = -120
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(60, 60)
	plus.add_theme_font_size_override("font_size", 28)
	plus.pressed.connect(func() -> void: game.camera_rig.zoom_by(-2.5))
	panel.add_child(plus)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(60, 60)
	minus.add_theme_font_size_override("font_size", 28)
	minus.pressed.connect(func() -> void: game.camera_rig.zoom_by(2.5))
	panel.add_child(minus)


# ---------- Log panel ----------

func _build_log_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "LogPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 10
	panel.offset_top = -210
	panel.offset_right = 380
	panel.offset_bottom = -120
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_log_label.text = "Добро пожаловать на кладбище мистера Юпитера!"
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	panel.add_child(_log_label)


# ---------- Name dialog ----------

func _build_name_dialog() -> void:
	_name_dialog = AcceptDialog.new()
	_name_dialog.title = "Имя усопшего"
	_name_dialog.dialog_hide_on_ok = true
	_name_dialog.size = Vector2i(420, 180)
	var v := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Введите имя для надгробной таблички:"
	v.add_child(lbl)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Имя Фамилия"
	v.add_child(_name_input)
	_name_dialog.add_child(v)
	_name_dialog.confirmed.connect(_on_name_confirmed)
	add_child(_name_dialog)


func open_name_dialog(cell: Cell) -> void:
	_name_target_cell = cell
	# Pre-fill suggested name from order if any.
	var order: Dictionary = OrderManager.get_order_for_cell(cell)
	if not order.is_empty():
		_name_input.text = order["deceased_short"]
	else:
		_name_input.text = cell.engraved_name
	_name_dialog.popup_centered()


func _on_name_confirmed() -> void:
	var text := _name_input.text.strip_edges()
	if text.is_empty():
		return
	if _name_target_cell:
		game.confirm_name(_name_target_cell, text)
	_name_target_cell = null


# ---------- Signal handlers ----------

func _on_money_changed(value: int) -> void:
	_money_label.text = "₽ %d" % value


func _on_crystals_changed(value: int) -> void:
	_crystals_label.text = "◆ %d" % value


func _on_day_changed(value: int) -> void:
	_day_label.text = "День: %d" % value
	_refresh_orders()


func _on_order_changed(_a = null, _b = null) -> void:
	_refresh_orders()


func _on_log(text: String) -> void:
	_log_label.text = text
