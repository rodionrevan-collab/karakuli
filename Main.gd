extends Node2D

const SAVE_PATH: String = "user://karakuli_farm.cfg"
const SLOT_COUNT: int = 12
const MAX_TIER: int = 7

var animal_names: Array[String] = [
	"Курица",
	"Утка",
	"Свинка",
	"Корова",
	"Овечка",
	"Лошадь",
	"Козочка",
	"Павлин",
]

var animal_rewards: Array[int] = [2, 3, 5, 8, 12, 18, 26, 40]

var animals: Array[int] = []
var slots: Array[Button] = []
var selected_slot: int = -1
var coins: int = 30
var discovered: Array[bool] = []

var coins_label: Label
var status_label: Label
var discovery_label: Label
var grid: GridContainer

func _ready() -> void:
	animals.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		animals[i] = -1
	discovered.resize(MAX_TIER + 1)
	for i in range(discovered.size()):
		discovered[i] = false

	_build_ui()
	_load_game()
	_refresh_ui()

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#f8f1df")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root: VBoxContainer = VBoxContainer.new()
	root.position = Vector2(28, 22)
	root.size = Vector2(1096, 604)
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var header: PanelContainer = PanelContainer.new()
	header.custom_minimum_size = Vector2(0, 76)
	header.add_theme_stylebox_override("panel", _panel_style(Color("#fffaf0"), Color("#2f2b28"), 3, 18))
	root.add_child(header)

	var header_box: HBoxContainer = HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 14)
	header.add_theme_constant_override("margin_left", 18)
	header.add_theme_constant_override("margin_right", 18)
	header.add_theme_constant_override("margin_top", 10)
	header.add_theme_constant_override("margin_bottom", 10)
	header.add_child(_title_label("КАРАКУЛИ ФЕРМА", 30))
	header_box.add_spacer(false)

	coins_label = _title_label("Монетки: 30", 22)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_box.add_child(coins_label)

	header.add_child(header_box)

	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	root.add_child(content)

	var farm_panel: PanelContainer = PanelContainer.new()
	farm_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	farm_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f1e6c9"), Color("#2f2b28"), 3, 18))
	content.add_child(farm_panel)

	var farm_box: VBoxContainer = VBoxContainer.new()
	farm_box.add_theme_constant_override("separation", 10)
	farm_panel.add_child(farm_box)

	var farm_header: Label = _title_label("ЗАГОН", 20)
	farm_header.add_theme_color_override("font_color", Color("#2f2b28"))
	farm_box.add_child(farm_header)

	var help: Label = Label.new()
	help.text = "Нажми на двух одинаковых животных, чтобы скрестить их и получить новое."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color("#5f554c"))
	farm_box.add_child(help)

	grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	farm_box.add_child(grid)

	for i in range(SLOT_COUNT):
		var slot: Button = Button.new()
		slot.custom_minimum_size = Vector2(182, 128)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.focus_mode = Control.FOCUS_NONE
		slot.add_theme_font_size_override("font_size", 18)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		slots.append(slot)
		grid.add_child(slot)

	var side_panel: PanelContainer = PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(270, 0)
	side_panel.add_theme_stylebox_override("panel", _panel_style(Color("#fffaf0"), Color("#2f2b28"), 3, 18))
	content.add_child(side_panel)

	var side_box: VBoxContainer = VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side_panel.add_child(side_box)

	side_box.add_child(_title_label("ФЕРМЕРСКИЙ СТОЛ", 20))

	var buy_button: Button = Button.new()
	buy_button.text = "Получить животное  •  6"
	buy_button.custom_minimum_size = Vector2(0, 52)
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.add_theme_font_size_override("font_size", 17)
	buy_button.pressed.connect(_on_buy_pressed)
	side_box.add_child(buy_button)

	var clear_button: Button = Button.new()
	clear_button.text = "Продать выбранное"
	clear_button.custom_minimum_size = Vector2(0, 48)
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.pressed.connect(_on_sell_pressed)
	side_box.add_child(clear_button)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_child(spacer)

	var collection_header: Label = _title_label("КОЛЛЕКЦИЯ", 18)
	side_box.add_child(collection_header)

	discovery_label = Label.new()
	discovery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	discovery_label.add_theme_font_size_override("font_size", 16)
	discovery_label.add_theme_color_override("font_color", Color("#3d3732"))
	side_box.add_child(discovery_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("#7a6d60"))
	side_box.add_child(status_label)

	var save_button: Button = Button.new()
	save_button.text = "Сохранить"
	save_button.custom_minimum_size = Vector2(0, 44)
	save_button.focus_mode = Control.FOCUS_NONE
	save_button.pressed.connect(_save_game)
	side_box.add_child(save_button)

func _title_label(text_value: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#292521"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.12, 0.10, 0.08, 0.12)
	style.shadow_size = 4
	return style

func _slot_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(16)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _refresh_ui() -> void:
	coins_label.text = "Монетки: %d" % coins

	for i in range(SLOT_COUNT):
		var slot: Button = slots[i]
		slot.remove_theme_stylebox_override("normal")
		slot.remove_theme_stylebox_override("hover")
		slot.remove_theme_stylebox_override("pressed")

		if animals[i] < 0:
			slot.text = "ПУСТОЕ МЕСТО\n\n＋"
			slot.add_theme_stylebox_override("normal", _slot_style(Color("#e9ddbd"), Color("#7a6c5b"), 2))
			slot.add_theme_stylebox_override("hover", _slot_style(Color("#f2e8cf"), Color("#3f3934"), 3))
		else:
			var tier: int = animals[i]
			slot.text = "%s\n\nуровень %d" % [animal_names[tier], tier + 1]
			var discovered_color: Color = Color("#fffdf5")
			if tier >= 3:
				discovered_color = Color("#f8ecd5")
			slot.add_theme_stylebox_override("normal", _slot_style(discovered_color, Color("#342f2b"), 3))
			slot.add_theme_stylebox_override("hover", _slot_style(Color("#fff4cf"), Color("#8a5f2b"), 4))

		if i == selected_slot:
			slot.add_theme_stylebox_override("pressed", _slot_style(Color("#ffe6a5"), Color("#b66b17"), 5))
			slot.text += "\n★ ВЫБРАНО"

	var found: int = 0
	var collection_lines: String = ""
	for i in range(MAX_TIER + 1):
		if discovered[i]:
			found += 1
			collection_lines += "✓ %s\n" % animal_names[i]
		else:
			collection_lines += "□ Неизвестный вид\n"
	discovery_label.text = "Открыто: %d / %d\n\n%s" % [found, MAX_TIER + 1, collection_lines]

	if selected_slot >= 0 and animals[selected_slot] >= 0:
		status_label.text = "Выбрано: %s. Нажми ещё раз на такое же животное." % animal_names[animals[selected_slot]]
	else:
		status_label.text = "Подсказка: два одинаковых животных превращаются в следующее поколение."

func _on_slot_pressed(index: int) -> void:
	if animals[index] < 0:
		status_label.text = "Это пустой загон. Нажми «Получить животное»."
		return

	if selected_slot == -1:
		selected_slot = index
		_refresh_ui()
		return

	if selected_slot == index:
		selected_slot = -1
		_refresh_ui()
		return

	if animals[selected_slot] == animals[index]:
		var tier: int = animals[index]
		if tier >= MAX_TIER:
			coins += animal_rewards[tier]
			animals[selected_slot] = -1
			status_label.text = "Павлин уже максимального уровня — за него получена награда."
		else:
			animals[index] = tier + 1
			animals[selected_slot] = -1
			discovered[tier + 1] = true
			coins += animal_rewards[tier]
			status_label.text = "Скрещивание удалось! Получена: %s." % animal_names[tier + 1]
			selected_slot = index
		_save_game()
	else:
		selected_slot = index
		status_label.text = "Животные разные. Выбери второе такое же."
	_refresh_ui()

func _on_buy_pressed() -> void:
	var empty_index: int = -1
	for i in range(SLOT_COUNT):
		if animals[i] < 0:
			empty_index = i
			break

	if empty_index == -1:
		status_label.text = "Все места заняты. Скрести животных, чтобы освободить место."
		return

	if coins < 6:
		status_label.text = "Нужно 6 монет."
		return

	coins -= 6
	var roll: int = randi_range(0, 1)
	animals[empty_index] = roll
	discovered[roll] = true
	status_label.text = "На ферму пришло новое животное: %s." % animal_names[roll]
	selected_slot = -1
	_save_game()
	_refresh_ui()

func _on_sell_pressed() -> void:
	if selected_slot < 0 or animals[selected_slot] < 0:
		status_label.text = "Сначала выбери животное."
		return

	var tier: int = animals[selected_slot]
	coins += animal_rewards[tier]
	animals[selected_slot] = -1
	status_label.text = "Животное продано за %d монет." % animal_rewards[tier]
	selected_slot = -1
	_save_game()
	_refresh_ui()

func _save_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("farm", "coins", coins)
	config.set_value("farm", "animals", animals)
	config.set_value("farm", "discovered", discovered)
	config.save(SAVE_PATH)

func _load_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		animals[0] = 0
		animals[1] = 0
		animals[2] = 0
		animals[3] = 0
		discovered[0] = true
		return

	coins = int(config.get_value("farm", "coins", 30))
	var saved_animals: Variant = config.get_value("farm", "animals", [])
	var saved_discovered: Variant = config.get_value("farm", "discovered", [])

	if saved_animals is Array and saved_animals.size() == SLOT_COUNT:
		for i in range(SLOT_COUNT):
			animals[i] = int(saved_animals[i])

	if saved_discovered is Array and saved_discovered.size() == MAX_TIER + 1:
		for i in range(MAX_TIER + 1):
			discovered[i] = bool(saved_discovered[i])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
		get_tree().quit()
