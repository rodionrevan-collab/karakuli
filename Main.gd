extends Node2D

const SAVE_PATH: String = "user://karakuli_farm.cfg"
const SLOT_COUNT: int = 20
const MAX_TIER: int = 15
const FIELD_SIZE: Vector2 = Vector2(842, 532)

var animal_names: Array[String] = [
	"Курица",
	"Утка",
	"Свинка",
	"Корова",
	"Овечка",
	"Лошадь",
	"Козочка",
	"Павлин",
	"Кролик",
	"Индюк",
	"Лама",
	"Лисичка",
	"Собака",
	"Кошка",
	"Лягушка",
	"Олень",
]

var animal_files: Array[String] = [
	"chicken",
	"duck",
	"pig",
	"cow",
	"sheep",
	"horse",
	"goat",
	"peacock",
	"rabbit",
	"turkey",
	"llama",
	"fox",
	"dog",
	"cat",
	"frog",
	"deer",
]

var animal_rewards: Array[int] = [2, 3, 5, 8, 12, 18, 26, 38, 55, 75, 100, 135, 180, 240, 320, 450]
var slot_positions: Array[Vector2] = [
	Vector2(92, 88), Vector2(246, 84), Vector2(405, 88), Vector2(566, 84), Vector2(713, 90),
	Vector2(160, 185), Vector2(318, 180), Vector2(481, 190), Vector2(644, 182), Vector2(770, 188),
	Vector2(84, 291), Vector2(244, 286), Vector2(407, 296), Vector2(566, 288), Vector2(720, 298),
	Vector2(145, 397), Vector2(305, 401), Vector2(462, 396), Vector2(625, 402), Vector2(757, 402)
]

var animals: Array[int] = []
var slots: Array[Button] = []
var selected_slot: int = -1
var coins: int = 30
var discovered: Array[bool] = []

var coins_label: Label
var collection_label: Label
var status_label: Label
var field_root: Control
var buy_button: Button

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
	bg.color = Color("#f5eddc")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root: VBoxContainer = VBoxContainer.new()
	root.position = Vector2(24, 18)
	root.size = Vector2(1104, 612)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var header: PanelContainer = PanelContainer.new()
	header.custom_minimum_size = Vector2(0, 72)
	header.add_theme_stylebox_override("panel", _panel_style(Color("#fffaf0"), Color("#342e29"), 3, 18))
	root.add_child(header)

	var header_box: HBoxContainer = HBoxContainer.new()
	header_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_box.add_theme_constant_override("separation", 16)
	header_box.add_theme_constant_override("margin_left", 18)
	header_box.add_theme_constant_override("margin_right", 18)
	header_box.add_theme_constant_override("margin_top", 8)
	header_box.add_theme_constant_override("margin_bottom", 8)
	header.add_child(header_box)

	var title: Label = _title_label("КАРАКУЛИ", 30)
	header_box.add_child(title)

	var subtitle: Label = _title_label("ФЕРМА ЖИВОТНЫХ", 18)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	header_box.add_child(subtitle)
	header_box.add_spacer(false)

	coins_label = _title_label("Монетки: %d" % coins, 21)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_box.add_child(coins_label)

	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	root.add_child(content)

	var field_panel: PanelContainer = PanelContainer.new()
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_panel.custom_minimum_size = Vector2(0, FIELD_SIZE.y)
	field_panel.add_theme_stylebox_override("panel", _panel_style(Color("#eef3c9"), Color("#342e29"), 3, 24))
	content.add_child(field_panel)

	field_root = Control.new()
	field_root.custom_minimum_size = FIELD_SIZE
	field_root.clip_contents = true
	field_panel.add_child(field_root)

	var field_art: TextureRect = TextureRect.new()
	field_art.texture = load("res://assets/ui/farm_field.svg") as Texture2D
	field_art.position = Vector2.ZERO
	field_art.size = FIELD_SIZE
	field_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	field_art.stretch_mode = TextureRect.STRETCH_SCALE
	field_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_root.add_child(field_art)

	var sign_label: Label = _title_label("Собирай  •  Скрещивай  •  Развивай", 19)
	sign_label.position = Vector2(290, 14)
	sign_label.size = Vector2(430, 34)
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_label.add_theme_color_override("font_color", Color("#4c4036"))
	field_root.add_child(sign_label)

	for i in range(SLOT_COUNT):
		var slot: Button = Button.new()
		slot.custom_minimum_size = Vector2(122, 92)
		slot.position = slot_positions[i]
		slot.focus_mode = Control.FOCUS_NONE
		slot.flat = true
		slot.alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		slot.add_theme_font_size_override("font_size", 15)
		slot.add_theme_color_override("font_color", Color("#342e29"))
		slot.add_theme_color_override("font_hover_color", Color("#342e29"))
		slot.add_theme_color_override("font_pressed_color", Color("#342e29"))
		slot.add_theme_stylebox_override("normal", _transparent_style())
		slot.add_theme_stylebox_override("hover", _hover_style())
		slot.add_theme_stylebox_override("pressed", _selected_style())
		slot.pressed.connect(_on_slot_pressed.bind(i))
		slots.append(slot)
		field_root.add_child(slot)

	var side_panel: PanelContainer = PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(246, FIELD_SIZE.y)
	side_panel.add_theme_stylebox_override("panel", _panel_style(Color("#fffaf0"), Color("#342e29"), 3, 20))
	content.add_child(side_panel)

	var side_box: VBoxContainer = VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side_panel.add_child(side_box)

	var side_title: Label = _title_label("ФЕРМЕРСКИЙ СТОЛ", 19)
	side_box.add_child(side_title)

	buy_button = Button.new()
	buy_button.text = "＋ Новое животное  •  6"
	buy_button.custom_minimum_size = Vector2(0, 50)
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.add_theme_font_size_override("font_size", 16)
	buy_button.pressed.connect(_on_buy_pressed)
	side_box.add_child(buy_button)

	var sell_button: Button = Button.new()
	sell_button.text = "Продать выбранное"
	sell_button.custom_minimum_size = Vector2(0, 45)
	sell_button.focus_mode = Control.FOCUS_NONE
	sell_button.add_theme_font_size_override("font_size", 16)
	sell_button.pressed.connect(_on_sell_pressed)
	side_box.add_child(sell_button)

	var divider: HSeparator = HSeparator.new()
	side_box.add_child(divider)

	var collection_title: Label = _title_label("КОЛЛЕКЦИЯ", 18)
	side_box.add_child(collection_title)

	collection_label = Label.new()
	collection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	collection_label.custom_minimum_size = Vector2(0, 0)
	collection_label.add_theme_font_size_override("font_size", 15)
	collection_label.add_theme_color_override("font_color", Color("#4a4038"))
	side_box.add_child(collection_label)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_child(spacer)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("#6a5d52"))
	side_box.add_child(status_label)

	var save_button: Button = Button.new()
	save_button.text = "Сохранить"
	save_button.custom_minimum_size = Vector2(0, 40)
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
	style.shadow_color = Color(0.12, 0.10, 0.08, 0.10)
	style.shadow_size = 4
	return style

func _transparent_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	return style

func _hover_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _transparent_style()
	style.bg_color = Color(1.0, 0.94, 0.68, 0.34)
	style.set_corner_radius_all(22)
	return style

func _selected_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _transparent_style()
	style.bg_color = Color(1.0, 0.82, 0.34, 0.42)
	style.border_color = Color("#7b5c2a")
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	return style

func _animal_file(tier: int) -> String:
	return animal_files[clamp(tier, 0, animal_files.size() - 1)]

func _default_animals() -> void:
	for i in range(SLOT_COUNT):
		animals[i] = -1
	animals[0] = 0
	animals[1] = 0
	animals[2] = 1
	animals[3] = 1
	animals[4] = 2
	animals[5] = 2
	animals[6] = 0
	animals[7] = 0
	for i in range(discovered.size()):
		discovered[i] = i <= 2

func _refresh_ui() -> void:
	coins_label.text = "Монетки: %d" % coins

	for i in range(SLOT_COUNT):
		var slot: Button = slots[i]
		if animals[i] < 0:
			slot.visible = false
			slot.icon = null
			slot.text = ""
			continue

		slot.visible = true
		var tier: int = animals[i]
		slot.icon = load("res://assets/animals/%s.svg" % _animal_file(tier)) as Texture2D
		slot.text = "%s\nур.%d" % [animal_names[tier], tier + 1]
		if i == selected_slot:
			slot.add_theme_stylebox_override("normal", _selected_style())
		else:
			slot.add_theme_stylebox_override("normal", _transparent_style())

	var found: int = 0
	var known_names: Array[String] = []
	for i in range(MAX_TIER + 1):
		if discovered[i]:
			found += 1
			known_names.append(animal_names[i])

	collection_label.text = "Открыто: %d / %d\n\n%s" % [
		found,
		MAX_TIER + 1,
		", ".join(known_names)
	]

	if selected_slot >= 0 and selected_slot < animals.size() and animals[selected_slot] >= 0:
		status_label.text = "Выбрано: %s. Нажми ещё на такое же животное, чтобы получить новое." % animal_names[animals[selected_slot]]
	else:
		status_label.text = "На поле можно разместить до %d животных." % SLOT_COUNT

func _on_slot_pressed(index: int) -> void:
	if animals[index] < 0:
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
			status_label.text = "Максимальный уровень! Получена награда."
			selected_slot = -1
		else:
			animals[index] = tier + 1
			animals[selected_slot] = -1
			discovered[tier + 1] = true
			coins += animal_rewards[tier]
			status_label.text = "Скрещивание удалось! Новый вид: %s." % animal_names[tier + 1]
			selected_slot = index
		_save_game()
	else:
		selected_slot = index
		status_label.text = "Это разные животные. Выбери такое же."
	_refresh_ui()

func _on_buy_pressed() -> void:
	var empty_index: int = -1
	for i in range(SLOT_COUNT):
		if animals[i] < 0:
			empty_index = i
			break

	if empty_index == -1:
		status_label.text = "Все 20 мест заняты. Скрещивай животных."
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
	selected_slot = -1
	status_label.text = "На ферму пришло: %s." % animal_names[roll]
	_save_game()
	_refresh_ui()

func _on_sell_pressed() -> void:
	if selected_slot < 0 or animals[selected_slot] < 0:
		status_label.text = "Сначала выбери животное."
		return

	var tier: int = animals[selected_slot]
	coins += animal_rewards[tier]
	animals[selected_slot] = -1
	status_label.text = "%s продано за %d монет." % [animal_names[tier], animal_rewards[tier]]
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
		_default_animals()
		coins = 30
		return

	coins = int(config.get_value("farm", "coins", 30))
	var saved_animals: Variant = config.get_value("farm", "animals", [])
	var saved_discovered: Variant = config.get_value("farm", "discovered", [])

	if saved_animals is Array and saved_animals.size() == SLOT_COUNT:
		for i in range(SLOT_COUNT):
			animals[i] = int(saved_animals[i])
	else:
		_default_animals()

	if saved_discovered is Array:
		for i in range(min(discovered.size(), saved_discovered.size())):
			discovered[i] = bool(saved_discovered[i])

	if not discovered[0]:
		discovered[0] = true
