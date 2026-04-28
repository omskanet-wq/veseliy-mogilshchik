extends Control
## Top-level HUD. Builds and wires every UI sub-panel programmatically.

const ACCENT_COLOR := Color(1.0, 0.84, 0.30)
const ACCENT_DIM := Color(1.0, 0.84, 0.30, 0.55)
const PANEL_BG := Color(0.10, 0.10, 0.12, 0.88)
const TOP_BAR_HEIGHT := 60
const TOOL_PANEL_HEIGHT := 124
const ORDERS_PANEL_WIDTH := 290

var game: Game
var main: Node

var _money_label: Label
var _crystals_label: Label
var _day_label: Label
var _orders_button: Button
var _orders_panel: PanelContainer
var _orders_list: VBoxContainer
var _tool_buttons: Dictionary = {}
var _name_dialog: AcceptDialog
var _name_input: LineEdit
var _name_target_cell: Cell
var _world_input: Control
var _hint_label: Label
var _hint_panel: PanelContainer
var _hint_timer: Timer
var _log_label: Label
var _log_panel: PanelContainer
var _orders_visible: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_world_input_layer()
	_build_top_bar()
	_build_orders_panel()
	_build_tool_panel()
	_build_zoom_panel()
	_build_log_panel()
	_build_hint_toast()
	_build_name_dialog()
	# Connect signals.
	Economy.money_changed.connect(_on_money_changed)
	Economy.crystals_changed.connect(_on_crystals_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	OrderManager.order_offered.connect(_on_order_changed)
	OrderManager.order_accepted.connect(_on_order_changed)
	OrderManager.order_completed.connect(_on_order_changed)
	OrderManager.order_failed.connect(_on_order_changed)
	game.log_message.connect(_on_log)
	game.hint_message.connect(_on_hint)
	game.tool_changed.connect(_on_tool_changed)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	# Initial paint.
	_on_money_changed(Economy.money)
	_on_crystals_changed(Economy.crystals)
	_on_day_changed(TimeManager.current_day)
	_refresh_orders()
	_apply_responsive_layout()
	_show_hint("Принимай заказы справа, копай и оформляй могилы — успей до дедлайна.")


# ---------- World input layer ----------

func _build_world_input_layer() -> void:
	# Full-rect transparent control that catches taps outside UI panels.
	_world_input = Control.new()
	_world_input.name = "WorldInput"
	_world_input.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world_input.mouse_filter = Control.MOUSE_FILTER_STOP
	_world_input.gui_input.connect(_on_world_gui_input)
	_world_input.mouse_exited.connect(func() -> void: game.update_hover_from_screen(Vector2.ZERO, false))
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
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		game.update_hover_from_screen(mm.position, true)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		game.update_hover_from_screen(d.position, true)


# ---------- Top bar ----------

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 0
	bar.offset_left = 0
	bar.offset_right = 0
	bar.offset_bottom = TOP_BAR_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_theme_stylebox_override("panel", _panel_style(PANEL_BG))
	add_child(bar)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_child(hbox)
	# Margin
	hbox.add_child(_spacer(10))
	_day_label = _make_stat_label("День: 1", Color(0.85, 0.95, 1.0))
	_money_label = _make_stat_label("₽ 500", Color(1.0, 0.95, 0.45))
	_crystals_label = _make_stat_label("◆ 0", Color(0.7, 0.95, 1.0))
	hbox.add_child(_day_label)
	hbox.add_child(_money_label)
	hbox.add_child(_crystals_label)
	hbox.add_child(_spacer(0, true))
	# Orders toggle (visible on narrow screens)
	_orders_button = Button.new()
	_orders_button.text = "Заказы"
	_orders_button.toggle_mode = true
	_orders_button.button_pressed = true
	_orders_button.custom_minimum_size = Vector2(110, 40)
	_orders_button.toggled.connect(_on_orders_toggled)
	hbox.add_child(_orders_button)
	var next_btn := Button.new()
	next_btn.text = "▶ Следующий день"
	next_btn.custom_minimum_size = Vector2(150, 40)
	next_btn.add_theme_font_size_override("font_size", 16)
	next_btn.pressed.connect(func() -> void: game.advance_day())
	hbox.add_child(next_btn)
	hbox.add_child(_spacer(10))


func _make_stat_label(initial: String, color: Color) -> Label:
	var l := Label.new()
	l.text = initial
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _spacer(width: int, expand: bool = false) -> Control:
	var c := Control.new()
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.custom_minimum_size = Vector2(width, 0)
	return c


# ---------- Orders panel (right side) ----------

func _build_orders_panel() -> void:
	_orders_panel = PanelContainer.new()
	_orders_panel.name = "OrdersPanel"
	_orders_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_orders_panel.offset_left = -ORDERS_PANEL_WIDTH
	_orders_panel.offset_top = TOP_BAR_HEIGHT + 8
	_orders_panel.offset_right = -8
	_orders_panel.offset_bottom = -TOOL_PANEL_HEIGHT - 16
	_orders_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_orders_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG))
	add_child(_orders_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_orders_panel.add_child(v)
	var title := Label.new()
	title.text = "Заказы"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	v.add_child(title)
	var sep := HSeparator.new()
	v.add_child(sep)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_orders_list = VBoxContainer.new()
	_orders_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orders_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_orders_list)


func _refresh_orders() -> void:
	for child in _orders_list.get_children():
		child.queue_free()
	_add_orders_section("Доступны", OrderManager.pending_orders, true)
	_add_orders_section("В работе", OrderManager.active_orders, false)
	if OrderManager.pending_orders.is_empty() and OrderManager.active_orders.is_empty():
		var lbl := Label.new()
		lbl.text = "Нет заказов. Жми «Следующий день» — родственники подъедут."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		_orders_list.add_child(lbl)
	if _orders_button:
		_orders_button.text = "Заказы (%d)" % OrderManager.pending_orders.size()


func _add_orders_section(title: String, list: Array, with_accept: bool) -> void:
	if list.is_empty():
		return
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_orders_list.add_child(header)
	for o in list:
		var card := _build_order_card(o, with_accept)
		_orders_list.add_child(card)


func _build_order_card(order: Dictionary, with_accept: bool) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.18)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var name_l := Label.new()
	name_l.text = order["deceased_short"]
	name_l.add_theme_font_size_override("font_size", 18)
	v.add_child(name_l)
	var info := Label.new()
	var days_left: int = order["deadline_day"] - TimeManager.current_day
	info.text = "%s · %s · до дня %d (%d дн.)" % [
		OrderManager.LUXURY_LABEL[order["luxury"]],
		Game.format_money(order["budget"]),
		order["deadline_day"],
		days_left,
	]
	info.add_theme_font_size_override("font_size", 13)
	if days_left <= 1:
		info.add_theme_color_override("font_color", Color(1, 0.6, 0.55))
	v.add_child(info)
	var rel := Label.new()
	rel.text = "Родственник: %s" % order["relative_name"]
	rel.add_theme_font_size_override("font_size", 12)
	rel.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	v.add_child(rel)
	if with_accept:
		var btn := Button.new()
		btn.text = "Принять"
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(func() -> void: _on_order_accept(order["id"]))
		v.add_child(btn)
	return card


func _on_order_accept(order_id: int) -> void:
	game.start_assign_for_order(order_id)
	_show_hint("Кликни по свободной клетке — там будет могила.")


func _on_orders_toggled(pressed: bool) -> void:
	_orders_visible = pressed
	_orders_panel.visible = pressed


# ---------- Tool panel (bottom) ----------

func _build_tool_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "ToolPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -TOOL_PANEL_HEIGHT
	panel.offset_left = 8
	panel.offset_right = -8
	panel.offset_bottom = -8
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG))
	add_child(panel)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	panel.add_child(flow)
	_make_tool_button(flow, Game.TOOL_DIG, "⛏ Копать", "Вырыть отведённую могилу")
	_make_tool_button(flow, Game.TOOL_TOMBSTONE_0, "▯ Камень\n%s" % Game.format_money(Game.TOMBSTONE_COSTS[0]), "Простой надгробный камень")
	_make_tool_button(flow, Game.TOOL_TOMBSTONE_1, "✝ Крест\n%s" % Game.format_money(Game.TOMBSTONE_COSTS[1]), "Деревянный крест")
	_make_tool_button(flow, Game.TOOL_TOMBSTONE_2, "▲ Обелиск\n%s" % Game.format_money(Game.TOMBSTONE_COSTS[2]), "Богатый обелиск")
	_make_tool_button(flow, Game.TOOL_FLOWERS, "❀ Цветы\n%s" % Game.format_money(Game.FLOWER_COST), "Украсить цветами")
	_make_tool_button(flow, Game.TOOL_NAME, "✎ Имя", "Выбить имя на надгробии")
	_make_tool_button(flow, Game.TOOL_PATH, "▦ Дорожка\n%s" % Game.format_money(Game.PATH_COST), "Положить дорожку")
	_make_tool_button(flow, Game.TOOL_DEMOLISH, "✖ Снести", "Очистить клетку")


func _make_tool_button(parent: Control, tool_id: String, label: String, tooltip: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.tooltip_text = tooltip
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(96, 100)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	btn.pressed.connect(func() -> void: _on_tool_pressed(tool_id))
	parent.add_child(btn)
	_tool_buttons[tool_id] = btn


func _on_tool_pressed(tool_id: String) -> void:
	game.set_tool(tool_id)


func _on_tool_changed(tool_id: String) -> void:
	for id in _tool_buttons:
		var b := _tool_buttons[id] as Button
		var active: bool = id == tool_id
		b.button_pressed = active
		# Distinct visual for the active tool.
		if active:
			b.add_theme_color_override("font_color", Color(0.10, 0.10, 0.10))
			b.add_theme_color_override("font_outline_color", Color(1, 1, 1))
			b.add_theme_constant_override("outline_size", 0)
		else:
			b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))


# ---------- Zoom buttons ----------

func _build_zoom_panel() -> void:
	var panel := VBoxContainer.new()
	panel.name = "ZoomPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -88
	panel.offset_top = -240
	panel.offset_right = -8
	panel.offset_bottom = -TOOL_PANEL_HEIGHT - 16
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_constant_override("separation", 8)
	add_child(panel)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(72, 56)
	plus.add_theme_font_size_override("font_size", 32)
	plus.pressed.connect(func() -> void: game.camera_rig.zoom_by(-2.5))
	panel.add_child(plus)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(72, 56)
	minus.add_theme_font_size_override("font_size", 32)
	minus.pressed.connect(func() -> void: game.camera_rig.zoom_by(2.5))
	panel.add_child(minus)


# ---------- Log panel ----------

func _build_log_panel() -> void:
	_log_panel = PanelContainer.new()
	_log_panel.name = "LogPanel"
	_log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log_panel.offset_left = 8
	_log_panel.offset_top = -TOOL_PANEL_HEIGHT - 80
	_log_panel.offset_right = 380
	_log_panel.offset_bottom = -TOOL_PANEL_HEIGHT - 16
	_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.55)))
	add_child(_log_panel)
	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_log_label.text = "Добро пожаловать на кладбище мистера Юпитера!"
	_log_label.add_theme_font_size_override("font_size", 15)
	_log_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_log_panel.add_child(_log_label)


# ---------- Hint toast ----------

func _build_hint_toast() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.name = "HintToast"
	_hint_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_panel.offset_left = 0
	_hint_panel.offset_top = TOP_BAR_HEIGHT + 8
	_hint_panel.offset_right = 0
	_hint_panel.offset_bottom = TOP_BAR_HEIGHT + 50
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.95, 0.65, 0.20, 0.85), Color(1, 0.85, 0.30, 0.95)))
	_hint_panel.modulate.a = 0.0
	add_child(_hint_panel)
	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	_hint_panel.add_child(_hint_label)
	_hint_timer = Timer.new()
	_hint_timer.one_shot = true
	_hint_timer.wait_time = 4.5
	_hint_timer.timeout.connect(_fade_out_hint)
	add_child(_hint_timer)


func _show_hint(text: String) -> void:
	_hint_label.text = text
	var tw := create_tween()
	tw.tween_property(_hint_panel, "modulate:a", 1.0, 0.18)
	_hint_timer.start()


func _fade_out_hint() -> void:
	var tw := create_tween()
	tw.tween_property(_hint_panel, "modulate:a", 0.0, 0.4)


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


# ---------- Responsive layout ----------

func _apply_responsive_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var narrow := vp.x < 880
	# On narrow screens, orders panel starts hidden behind a toggle button.
	if narrow and _orders_button.button_pressed and _orders_visible:
		# leave default
		pass
	if narrow:
		_orders_panel.offset_left = -240
		_orders_panel.offset_top = TOP_BAR_HEIGHT + 8
		_orders_panel.offset_bottom = -TOOL_PANEL_HEIGHT - 8
	else:
		_orders_panel.offset_left = -ORDERS_PANEL_WIDTH
		_orders_panel.offset_top = TOP_BAR_HEIGHT + 8
		_orders_panel.offset_bottom = -TOOL_PANEL_HEIGHT - 16


# ---------- Style helpers ----------

func _panel_style(bg: Color, border: Color = Color(1, 1, 1, 0.10)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


# ---------- Signal handlers ----------

func _on_money_changed(value: int) -> void:
	_money_label.text = Game.format_money(value)


func _on_crystals_changed(value: int) -> void:
	_crystals_label.text = "◆ %d" % value


func _on_day_changed(value: int) -> void:
	_day_label.text = "День: %d" % value
	_refresh_orders()


func _on_order_changed(_a = null, _b = null) -> void:
	_refresh_orders()


func _on_log(text: String) -> void:
	_log_label.text = text


func _on_hint(text: String) -> void:
	_show_hint(text)
