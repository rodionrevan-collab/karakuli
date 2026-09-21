extends Node2D

const SAVE_PATH: String = "user://karakuli_farm.cfg"
const SLOT_COUNT: int = 20
const MAX_TIER: int = 23
const FIELD_SIZE: Vector2 = Vector2(900, 560)
const MERGE_DISTANCE: float = 78.0

var animal_names: Array[String] = [
	"Курица", "Утка", "Свинка", "Корова", "Овечка", "Лошадь", "Козочка", "Павлин",
	"Кролик", "Индюк", "Лама", "Лисичка", "Собака", "Кошка", "Лягушка", "Олень",
	"Волк", "Панда", "Пингвин", "Жираф", "Слон", "Бегемот", "Обезьяна", "Тигр"
]
var animal_files: Array[String] = [
	"chicken", "duck", "pig", "cow", "sheep", "horse", "goat", "peacock",
	"rabbit", "turkey", "llama", "fox", "dog", "cat", "frog", "deer",
	"wolf", "panda", "penguin", "giraffe", "elephant", "hippo", "monkey", "tiger"
]
var animal_rewards: Array[int] = [2, 3, 5, 8, 12, 18, 26, 38, 55, 75, 100, 135, 180, 240, 320, 450, 600, 800, 1050, 1400, 1850, 2400, 3200, 4200]

var slot_positions: Array[Vector2] = [
	Vector2(120, 110), Vector2(292, 104), Vector2(468, 114), Vector2(646, 108), Vector2(792, 120),
	Vector2(88, 230), Vector2(250, 235), Vector2(430, 226), Vector2(610, 236), Vector2(765, 236),
	Vector2(115, 352), Vector2(280, 340), Vector2(455, 356), Vector2(630, 345), Vector2(790, 360),
	Vector2(170, 460), Vector2(340, 452), Vector2(520, 465), Vector2(680, 450), Vector2(815, 460)
]

var animals: Array[int] = []
var positions: Array[Vector2] = []
var slots: Array[Button] = []
var slot_images: Array[TextureRect] = []
var slot_labels: Array[Label] = []

var selected_slot: int = -1
var dragging_index: int = -1
var drag_offset: Vector2 = Vector2.ZERO
var coins: int = 30
var income_level: int = 0
var discovered: Array[bool] = []

var coins_label: Label
var income_label: Label
var income_upgrade_button: Button
var status_label: Label
var collection_popup: PanelContainer
var collection_label: Label

func _ready() -> void:
	animals.resize(SLOT_COUNT)
	positions.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		animals[i] = -1
		positions[i] = slot_positions[i]

	discovered.resize(MAX_TIER + 1)
	for i in range(discovered.size()):
		discovered[i] = false

	_build_ui()
	_load_game()
	_refresh_ui()

	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_income_tick)
	add_child(timer)

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#f5ead2")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root: VBoxContainer = VBoxContainer.new()
	root.position = Vector2(18, 14)
	root.size = Vector2(1116, 620)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header: PanelContainer = PanelContainer.new()
	header.custom_minimum_size = Vector2(0, 82)
	header.add_theme_stylebox_override("panel", _paper_panel(Color("#fffaf0"), "#342e29", 3, 18))
	root.add_child(header)

	var header_box: HBoxContainer = HBoxContainer.new()
	header_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_box.add_theme_constant_override("separation", 14)
	header_box.add_theme_constant_override("margin_left", 14)
	header_box.add_theme_constant_override("margin_right", 14)
	header_box.add_theme_constant_override("margin_top", 8)
	header_box.add_theme_constant_override("margin_bottom", 8)
	header.add_child(header_box)

	var title: Label = _title_label("КАРАКУЛИ", 37)
	header_box.add_child(title)
	var subtitle: Label = _title_label("ФЕРМА ЖИВОТНЫХ", 19)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	header_box.add_child(subtitle)
	header_box.add_spacer(false)

	var coin_box: VBoxContainer = VBoxContainer.new()
	coin_box.custom_minimum_size = Vector2(160, 0)
	header_box.add_child(coin_box)
	coins_label = _title_label("Монеты: %d" % coins, 23)
	coin_box.add_child(coins_label)
	income_label = _title_label("Доход: +0 / сек", 15)
	income_label.add_theme_color_override("font_color", Color("#6c5a4d"))
	coin_box.add_child(income_label)

	income_upgrade_button = Button.new()
	income_upgrade_button.text = "ПРОКАЧАТЬ ДОХОД"
	income_upgrade_button.custom_minimum_size = Vector2(170, 45)
	income_upgrade_button.focus_mode = Control.FOCUS_NONE
	income_upgrade_button.add_theme_font_size_override("font_size", 13)
	income_upgrade_button.pressed.connect(_on_income_upgrade_pressed)
	header_box.add_child(income_upgrade_button)

	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	root.add_child(content)

	var field_panel: PanelContainer = PanelContainer.new()
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_panel.add_theme_stylebox_override("panel", _paper_panel(Color("#f2efbf"), "#342e29", 3, 24))
	content.add_child(field_panel)

	var field_root: Control = Control.new()
	field_root.custom_minimum_size = FIELD_SIZE
	field_root.clip_contents = true
	field_panel.add_child(field_root)

	var art: TextureRect = TextureRect.new()
	art.texture = load("res://assets/ui/farm_scene.svg") as Texture2D
	art.position = Vector2.ZERO
	art.size = FIELD_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_root.add_child(art)

	var sign: PanelContainer = PanelContainer.new()
	sign.position = Vector2(18, 450)
	sign.size = Vector2(270, 92)
	sign.add_theme_stylebox_override("panel", _paper_panel(Color("#fff2cf"), "#473b31", 2, 18))
	field_root.add_child(sign)

	var sign_text: Label = _title_label("Больше животных —\nбольше возможностей!", 16)
	sign_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sign_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sign_text.add_theme_color_override("font_color", Color("#493d33"))
	sign.add_child(sign_text)

	for i in range(SLOT_COUNT):
		var slot: Button = Button.new()
		slot.position = positions[i]
		slot.size = Vector2(128, 104)
		slot.focus_mode = Control.FOCUS_NONE
		slot.flat = true
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.add_theme_stylebox_override("normal", _transparent_style())
		slot.add_theme_stylebox_override("hover", _hover_style())
		slot.add_theme_stylebox_override("pressed", _selected_style())
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		field_root.add_child(slot)

		var image: TextureRect = TextureRect.new()
		image.position = Vector2(18, 0)
		image.size = Vector2(92, 74)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(image)

		var label: Label = Label.new()
		label.position = Vector2(0, 72)
		label.size = Vector2(128, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("#3f352e"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)

		slots.append(slot)
		slot_images.append(image)
		slot_labels.append(label)

	var menu: VBoxContainer = VBoxContainer.new()
	menu.custom_minimum_size = Vector2(196, FIELD_SIZE.y)
	content.add_child(menu)

	menu.add_child(_menu_button("⌂  ФЕРМА", _on_farm_menu))
	menu.add_child(_menu_button("▣  МАГАЗИН", _on_shop_menu))
	menu.add_child(_menu_button("☷  КОЛЛЕКЦИЯ", _on_collection_menu))
	menu.add_child(_menu_button("⚙  НАСТРОЙКИ", _on_settings_menu))

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(spacer)

	var note: PanelContainer = PanelContainer.new()
	note.custom_minimum_size = Vector2(0, 112)
	note.add_theme_stylebox_override("panel", _paper_panel(Color("#fff7df"), "#473b31", 2, 18))
	menu.add_child(note)

	var note_text: Label = Label.new()
	note_text.text = "Перетаскивай животных\nдруг к другу.\nОдинаковые —\nскрещиваются!"
	note_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	note_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note_text.add_theme_font_size_override("font_size", 15)
	note_text.add_theme_color_override("font_color", Color("#463a31"))
	note.add_child(note_text)

	collection_popup = PanelContainer.new()
	collection_popup.visible = false
	collection_popup.position = Vector2(720, 104)
	collection_popup.size = Vector2(360, 270)
	collection_popup.add_theme_stylebox_override("panel", _paper_panel(Color("#fffaf0"), "#342e29", 3, 20))
	add_child(collection_popup)

	collection_label = Label.new()
	collection_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	collection_label.add_theme_constant_override("margin_left", 18)
	collection_label.add_theme_constant_override("margin_right", 18)
	collection_label.add_theme_constant_override("margin_top", 14)
	collection_label.add_theme_constant_override("margin_bottom", 14)
	collection_label.add_theme_font_size_override("font_size", 16)
	collection_label.add_theme_color_override("font_color", Color("#3f352e"))
	collection_popup.add_child(collection_label)

	status_label = _title_label("", 14)
	status_label.position = Vector2(720, 583)
	status_label.size = Vector2(360, 40)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#6a5a4d"))
	add_child(status_label)

func _menu_button(text_value: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 78)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _paper_panel(Color("#fffaf0"), "#342e29", 3, 18))
	button.add_theme_stylebox_override("hover", _paper_panel(Color("#fff0c9"), "#8b653d", 3, 18))
	button.add_theme_stylebox_override("pressed", _paper_panel(Color("#ffe7a6"), "#6f4d2d", 4, 18))
	button.pressed.connect(callback)
	return button

func _title_label(text_value: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#292521"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _paper_panel(fill: Color, border_hex: String, width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(border_hex)
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.10, 0.08, 0.06, 0.10)
	style.shadow_size = 4
	return style

func _transparent_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.set_border_width_all(0)
	return style

func _hover_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _transparent_style()
	style.bg_color = Color(1.0, 0.90, 0.50, 0.28)
	style.set_corner_radius_all(26)
	return style

func _selected_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _transparent_style()
	style.bg_color = Color(1.0, 0.77, 0.27, 0.42)
	style.border_color = Color("#74532e")
	style.set_border_width_all(3)
	style.set_corner_radius_all(26)
	return style

func _animal_file(tier: int) -> String:
	return animal_files[clamp(tier, 0, animal_files.size() - 1)]

func _default_animals() -> void:
	for i in range(SLOT_COUNT):
		animals[i] = -1
		positions[i] = slot_positions[i]
	animals[0] = 0
	animals[1] = 0
	animals[2] = 0
	animals[3] = 1
	animals[4] = 1
	animals[5] = 1
	animals[6] = 2
	animals[7] = 2
	discovered[0] = true
	discovered[1] = true
	discovered[2] = true

func _refresh_ui() -> void:
	coins_label.text = "Монеты: %d" % coins
	var income: int = _income_per_second()
	income_label.text = "Пассивно: +%d / сек" % income
	var upgrade_cost: int = _income_upgrade_cost()
	income_upgrade_button.text = "ПРОКАЧАТЬ  •  %d" % upgrade_cost

	for i in range(SLOT_COUNT):
		var slot: Button = slots[i]
		if animals[i] < 0:
			slot.visible = false
			continue

		slot.visible = true
		slot.position = positions[i]
		slot_images[i].texture = load("res://assets/animals/%s.svg" % _animal_file(animals[i])) as Texture2D
		slot_labels[i].text = "%s\nур.%d" % [animal_names[animals[i]], animals[i] + 1]
		slot.add_theme_stylebox_override("normal", _selected_style() if i == selected_slot else _transparent_style())

	var found: int = 0
	var known_names: Array[String] = []
	for i in range(MAX_TIER + 1):
		if discovered[i]:
			found += 1
			known_names.append(animal_names[i])

	collection_label.text = "КОЛЛЕКЦИЯ\n\nОткрыто: %d / %d\n\n%s\n\nПеретащи двух одинаковых животных рядом — они скрестятся." % [
		found, MAX_TIER + 1, ", ".join(known_names)
	]

func _income_per_second() -> int:
	var base: float = 0.0
	for tier in animals:
		if tier >= 0:
			base += 1.0 + float(tier) * 1.5
	var multiplier: float = 1.0 + float(income_level) * 0.25
	return max(0, int(floor(base * multiplier)))

func _income_upgrade_cost() -> int:
	return 25 + income_level * 35

func _on_income_tick() -> void:
	var income: int = _income_per_second()
	if income > 0:
		coins += income
		_refresh_ui()

func _on_income_upgrade_pressed() -> void:
	var cost: int = _income_upgrade_cost()
	if coins < cost:
		status_label.text = "Не хватает монет для прокачки дохода."
		return
	coins -= cost
	income_level += 1
	status_label.text = "Пассивный доход увеличен! Теперь +%d монет/сек." % _income_per_second()
	_save_game()
	_refresh_ui()

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if animals[index] < 0:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			dragging_index = index
			drag_offset = mouse_event.position
			selected_slot = index
			_refresh_ui()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed and dragging_index == index:
			_drop_animal(index)
	elif event is InputEventMouseMotion and dragging_index == index:
		var mouse_pos: Vector2 = get_local_mouse_position_for_field(slots[index].get_parent())
		var desired: Vector2 = mouse_pos - drag_offset
		desired.x = clamp(desired.x, 8.0, FIELD_SIZE.x - slots[index].size.x - 8.0)
		desired.y = clamp(desired.y, 70.0, FIELD_SIZE.y - slots[index].size.y - 10.0)
		positions[index] = desired
		slots[index].position = desired

func get_local_mouse_position_for_field(field: Node) -> Vector2:
	var local: Vector2 = field.get_global_mouse_position()
	return field.to_local(local)

func _drop_animal(index: int) -> void:
	dragging_index = -1
	var nearest: int = -1
	var nearest_distance: float = MERGE_DISTANCE

	var center_a: Vector2 = positions[index] + slots[index].size / 2.0
	for j in range(SLOT_COUNT):
		if j == index or animals[j] < 0:
			continue
		var center_b: Vector2 = positions[j] + slots[j].size / 2.0
		var d: float = center_a.distance_to(center_b)
		if d < nearest_distance:
			nearest_distance = d
			nearest = j

	if nearest >= 0:
		if animals[nearest] == animals[index]:
			_merge_animals(index, nearest)
			return
		var target: Vector2 = positions[nearest] + Vector2(70, 0)
		target.x = clamp(target.x, 8.0, FIELD_SIZE.x - slots[index].size.x - 8.0)
		positions[index] = target
		status_label.text = "Теперь они рядом. Одинаковых можно скрестить."
	else:
		status_label.text = "Животное перемещено."
	_save_game()
	_refresh_ui()

func _merge_animals(a: int, b: int) -> void:
	var tier: int = animals[a]
	if tier >= MAX_TIER:
		coins += animal_rewards[tier]
		animals[a] = -1
		selected_slot = -1
		status_label.text = "Максимальный вид! За объединение получена награда."
	else:
		animals[b] = tier + 1
		discovered[tier + 1] = true
		animals[a] = -1
		positions[b] = (positions[a] + positions[b]) / 2.0
		selected_slot = b
		status_label.text = "Скрещивание! Получено новое животное: %s." % animal_names[tier + 1]
	coins += animal_rewards[tier]
	_save_game()
	_refresh_ui()

func _on_shop_menu() -> void:
	_buy_animal()

func _buy_animal() -> void:
	var empty_index: int = -1
	for i in range(SLOT_COUNT):
		if animals[i] < 0:
			empty_index = i
			break
	if empty_index == -1:
		status_label.text = "Все 20 мест заняты."
		return
	if coins < 6:
		status_label.text = "Нужно 6 монет."
		return

	coins -= 6
	var unlocked_max: int = 2
	for i in range(MAX_TIER, -1, -1):
		if discovered[i]:
			unlocked_max = max(2, i)
			break
	var roll: int = randi_range(0, unlocked_max)
	animals[empty_index] = roll
	discovered[roll] = true
	positions[empty_index] = _find_free_position()
	selected_slot = -1
	status_label.text = "На ферму пришло: %s." % animal_names[roll]
	_save_game()
	_refresh_ui()

func _find_free_position() -> Vector2:
	for candidate in slot_positions:
		var free: bool = true
		for i in range(SLOT_COUNT):
			if animals[i] >= 0 and positions[i].distance_to(candidate) < 80.0:
				free = false
				break
		if free:
			return candidate
	return Vector2(420, 300)

func _on_collection_menu() -> void:
	collection_popup.visible = not collection_popup.visible
	if collection_popup.visible:
		status_label.text = "Коллекция открыта."

func _on_farm_menu() -> void:
	collection_popup.visible = false
	status_label.text = "Ферма открыта. Перетаскивай животных."

func _on_settings_menu() -> void:
	_save_game()
	status_label.text = "Игра сохранена."

func _save_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("farm", "coins", coins)
	config.set_value("farm", "income_level", income_level)
	config.set_value("farm", "animals", animals)
	config.set_value("farm", "positions", positions)
	config.set_value("farm", "discovered", discovered)
	config.save(SAVE_PATH)

func _load_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		coins = 30
		income_level = 0
		_default_animals()
		return

	coins = int(config.get_value("farm", "coins", 30))
	income_level = int(config.get_value("farm", "income_level", 0))

	var saved_animals: Variant = config.get_value("farm", "animals", [])
	if saved_animals is Array and saved_animals.size() == SLOT_COUNT:
		for i in range(SLOT_COUNT):
			animals[i] = int(saved_animals[i])
	else:
		_default_animals()

	var saved_positions: Variant = config.get_value("farm", "positions", [])
	if saved_positions is Array and saved_positions.size() == SLOT_COUNT:
		for i in range(SLOT_COUNT):
			if saved_positions[i] is Vector2:
				positions[i] = saved_positions[i]
			else:
				positions[i] = slot_positions[i]

	var saved_discovered: Variant = config.get_value("farm", "discovered", [])
	if saved_discovered is Array:
		for i in range(min(discovered.size(), saved_discovered.size())):
			discovered[i] = bool(saved_discovered[i])

	if not discovered[0]:
		discovered[0] = true
