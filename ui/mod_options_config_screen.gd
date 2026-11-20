extends ScrollContainer

const FONT := preload("res://resources/fonts/actual/base/font_40_outline.tres")
const SECTION_FONT := preload("res://resources/fonts/actual/base/font_26_outline.tres")
const SLIDER_SCENE := preload("res://ui/menus/global/slider_option.tscn")
const COLOR_OPTION_SCENE := preload("res://ui/menus/global/color_option.tscn")
const MENU_BUTTON_SCRIPT := preload("res://ui/menus/global/my_menu_button.gd")

var manager = null
var mod_id := ""
var extra_config = null
var _fields_container: VBoxContainer


func _ready() -> void:
	_initialize_native_controls(_fields_container)


func build(schema_override: Dictionary = {}) -> void:
	name = "Settings_%s" % mod_id.replace("-", "_")
	if extra_config != null:
		name += "_%s" % extra_config.config_name
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	follow_focus = true
	scroll_horizontal_enabled = false
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.set("custom_constants/separation", 14)
	add_child(content)
	var schema = schema_override if not schema_override.empty() else (extra_config.get_schema() if extra_config != null else manager.get_schema(mod_id))
	var title = Label.new()
	title.text = schema.get("title", manager.get_mod_name(mod_id))
	title.align = Label.ALIGN_CENTER
	title.set("custom_fonts/font", FONT)
	content.add_child(title)
	if schema.has("description"):
		_add_help_text(content, schema.description)
	_fields_container = VBoxContainer.new()
	_fields_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fields_container.set("custom_constants/separation", 12)
	content.add_child(_fields_container)
	_add_properties(schema.get("properties", {}), "")


func parent_to(parent_window: Node) -> Control:
	if parent_window == null:
		return self
	if get_parent() != null:
		get_parent().remove_child(self)
	parent_window.add_child(self)
	if self is Control:
		anchor_right = 1.0
		anchor_bottom = 1.0
	return self


func attach_to(parent_window: Node) -> Control:
	return parent_to(parent_window)


func _add_properties(properties: Dictionary, prefix: String) -> void:
	for key in properties.keys():
		var property_schema = properties[key]
		if typeof(property_schema) != TYPE_DICTIONARY:
			continue
		var path = key if prefix.empty() else prefix + "." + key
		if property_schema.get("type", "") == "object":
			var section = PanelContainer.new()
			section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			section.add_stylebox_override("panel", _make_section_style())
			var section_content = VBoxContainer.new()
			section_content.set("custom_constants/separation", 10)
			section.add_child(section_content)
			var section_header = Label.new()
			section_header.text = property_schema.get("title", _prettify(key))
			section_header.set("custom_fonts/font", SECTION_FONT)
			section_content.add_child(section_header)
			if property_schema.has("description"):
				_add_help_text(section_content, property_schema.description)
			var inner_margin = MarginContainer.new()
			inner_margin.add_constant_override("margin_left", 18)
			inner_margin.add_constant_override("margin_right", 8)
			inner_margin.add_constant_override("margin_top", 4)
			inner_margin.add_constant_override("margin_bottom", 8)
			var nested_fields = VBoxContainer.new()
			nested_fields.set("custom_constants/separation", 10)
			inner_margin.add_child(nested_fields)
			section_content.add_child(inner_margin)
			_fields_container.add_child(section)
			var previous_fields_container = _fields_container
			_fields_container = nested_fields
			_add_properties(property_schema.get("properties", {}), path)
			_fields_container = previous_fields_container
		else:
			_add_field(path, property_schema)


func _add_field(config_path: String, property_schema: Dictionary) -> void:
	var label_text = property_schema.get("title", _prettify(config_path))
	var current_value = extra_config.get_value(config_path) if extra_config != null else manager.get_value(mod_id, config_path)
	if property_schema.has("enum"):
		_add_enum_field(config_path, property_schema, label_text, current_value)
		return

	var type_name = property_schema.get("type", "")
	if type_name is Array:
		type_name = type_name[0] if not type_name.empty() else ""
	match type_name:
		"boolean":
			_add_boolean_field(config_path, property_schema, label_text, current_value)
		"integer", "number":
			_add_slider_field(config_path, property_schema, label_text, current_value)
		"string":
			if property_schema.get("format", "") == "color":
				_add_color_field(config_path, property_schema, label_text, current_value)
			else:
				_add_text_field(config_path, property_schema, label_text, current_value)
		"array":
			_add_array_field(config_path, property_schema, label_text, current_value)


func _add_boolean_field(config_path: String, property_schema: Dictionary, label_text: String, current_value) -> void:
	var toggle = CheckButton.new()
	toggle.set_script(MENU_BUTTON_SCRIPT)
	toggle.text = label_text
	toggle.pressed = current_value == true
	_apply_tooltip(toggle, property_schema)
	toggle.connect("toggled", self, "_on_value_changed", [config_path])
	_fields_container.add_child(toggle)


func _add_slider_field(config_path: String, property_schema: Dictionary, label_text: String, current_value) -> void:
	var slider_option = SLIDER_SCENE.instance()
	slider_option.set_meta("modoptions_slider_path", config_path)
	slider_option.set_meta("modoptions_slider_schema", property_schema.duplicate(true))
	slider_option.set_meta("modoptions_slider_label", label_text)
	slider_option.set_meta("modoptions_slider_initial", current_value)
	_apply_tooltip(slider_option, property_schema)
	_fields_container.add_child(slider_option)


func _initialize_slider_option(slider_option: SliderOption) -> void:
	var property_schema: Dictionary = slider_option.get_meta("modoptions_slider_schema")
	var current_value = slider_option.get_meta("modoptions_slider_initial")
	var minimum = float(property_schema.get("minimum", min(float(current_value), 0.0)))
	var maximum = float(property_schema.get("maximum", max(float(current_value), 100.0)))
	if maximum <= minimum:
		maximum = minimum + 1.0
	var step = float(property_schema.get("multipleOf", 1.0 if property_schema.get("type", "") == "integer" else 0.1))
	var slider: HSlider = slider_option._slider
	slider_option._label.text = slider_option.get_meta("modoptions_slider_label")
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = max(step, 0.001)
	slider_option.set_value(float(current_value))
	slider_option._value.text = _format_number(current_value, property_schema)
	slider_option.connect("value_changed", self, "_on_slider_changed", [slider_option.get_meta("modoptions_slider_path"), property_schema, slider_option._value])


func _add_enum_field(config_path: String, property_schema: Dictionary, label_text: String, current_value) -> void:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dropdown = OptionButton.new()
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dropdown.size_flags_stretch_ratio = 1.0
	label.size_flags_stretch_ratio = 1.0
	_style_option_button(dropdown)
	var choices = property_schema.get("enum", [])
	var names = property_schema.get("enumNames", choices)
	var selected = 0
	for index in range(choices.size()):
		dropdown.add_item(str(names[index]) if index < names.size() else str(choices[index]), index)
		if choices[index] == current_value:
			selected = index
	dropdown.select(selected)
	_apply_tooltip(row, property_schema)
	row.add_child(label)
	row.add_child(dropdown)
	dropdown.connect("item_selected", self, "_on_enum_selected", [config_path, choices])
	_fields_container.add_child(row)


func _add_text_field(config_path: String, property_schema: Dictionary, label_text: String, current_value) -> void:
	var container = VBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	container.add_child(label)
	if property_schema.get("multiline", false):
		var text_edit = TextEdit.new()
		text_edit.text = str(current_value)
		text_edit.rect_min_size.y = float(property_schema.get("min_height", 100.0))
		text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_edit.wrap_enabled = true
		_style_text_input(text_edit)
		text_edit.connect("text_changed", self, "_on_text_edit_changed", [config_path, text_edit])
		container.add_child(text_edit)
	else:
		var line_edit = LineEdit.new()
		line_edit.text = str(current_value)
		line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_text_input(line_edit)
		line_edit.connect("text_changed", self, "_on_value_changed", [config_path])
		container.add_child(line_edit)
	_apply_tooltip(container, property_schema)
	_fields_container.add_child(container)


func _add_array_field(config_path: String, property_schema: Dictionary, label_text: String, current_value) -> void:
	var container = VBoxContainer.new()
	var label = Label.new()
	label.text = label_text + " (JSON)"
	container.add_child(label)
	var input = TextEdit.new()
	input.text = JSON.print(current_value)
	input.rect_min_size.y = float(property_schema.get("min_height", 90.0))
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_text_input(input)
	input.connect("focus_exited", self, "_on_array_submitted", [config_path, input])
	container.add_child(input)
	_apply_tooltip(container, property_schema)
	_fields_container.add_child(container)


func _add_color_field(config_path: String, property_schema: Dictionary, label_text: String, current_value) -> void:
	var color_option = COLOR_OPTION_SCENE.instance() as ColorOption
	color_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_option.set_meta("modoptions_color_path", config_path)
	color_option.set_meta("modoptions_color_initial", _color_from_value(current_value))
	color_option.set_meta("modoptions_color_default", _color_from_value(property_schema.get("default", "ffffff")))
	color_option.set_meta("modoptions_color_label", label_text)
	_apply_tooltip(color_option, property_schema)
	_fields_container.add_child(color_option)


func _initialize_native_controls(node: Node) -> void:
	if node is SliderOption and node.has_meta("modoptions_slider_path"):
		_initialize_slider_option(node)
	elif node is ColorOption and node.has_meta("modoptions_color_path"):
		node.button_expand.text = node.get_meta("modoptions_color_label")
		node._init_color(node.get_meta("modoptions_color_initial"))
		node.connect("color_changed", self, "_on_brotato_color_changed", [node.get_meta("modoptions_color_path")])
		node.connect("color_reset", self, "_on_brotato_color_reset", [node.get_meta("modoptions_color_path"), node])
	for child in node.get_children():
		_initialize_native_controls(child)


func _color_from_value(value) -> Color:
	var color_text = str(value)
	if color_text.empty() or color_text == "Null":
		color_text = "ffffff"
	if not color_text.begins_with("#"):
		color_text = "#" + color_text
	return Color(color_text)


func _on_value_changed(value, config_path: String) -> void:
	_set_config_value(config_path, value)


func _on_slider_changed(value: float, config_path: String, property_schema: Dictionary, value_label: Label) -> void:
	value_label.text = _format_number(value, property_schema)
	_set_config_value(config_path, value)


func _on_enum_selected(index: int, config_path: String, choices: Array) -> void:
	if index >= 0 and index < choices.size():
		_set_config_value(config_path, choices[index])


func _on_text_edit_changed(config_path: String, text_edit: TextEdit) -> void:
	_set_config_value(config_path, text_edit.text)


func _on_brotato_color_changed(color: Color, config_path: String) -> void:
	_set_config_value(config_path, color.to_html(false))


func _on_brotato_color_reset(config_path: String, color_option: ColorOption) -> void:
	var schema = extra_config.get_schema() if extra_config != null else manager.get_schema(mod_id)
	var property_schema = manager._get_property_schema(schema.get("properties", {}), config_path)
	var default_color = _color_from_value(property_schema.get("default", "ffffff"))
	color_option._init_color(default_color)
	_set_config_value(config_path, default_color.to_html(false))


func _on_array_submitted(config_path: String, input: TextEdit) -> void:
	var parsed = JSON.parse(input.text)
	if parsed.error == OK and typeof(parsed.result) == TYPE_ARRAY:
		_set_config_value(config_path, parsed.result)


func _set_config_value(config_path: String, value) -> void:
	if extra_config != null:
		extra_config.set_value(config_path, value)
	else:
		manager.set_value(mod_id, config_path, value)


func _format_number(value, property_schema: Dictionary) -> String:
	var type_name = property_schema.get("type", "")
	if type_name is Array:
		type_name = type_name[0] if not type_name.empty() else ""
	if type_name == "integer":
		return str(int(round(float(value))))
	var decimal = int(property_schema.get("decimals", 2))
	return ("%." + str(decimal) + "f") % float(value)


func _apply_tooltip(control: Control, property_schema: Dictionary) -> void:
	control.hint_tooltip = property_schema.get("description", property_schema.get("tooltip", ""))


func _make_section_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.04, 0.62)
	style.border_color = Color(0.24, 0.32, 0.29, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _make_input_style(focused: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.045, 0.92)
	style.border_color = Color(0.38, 0.48, 0.43, 1.0) if focused else Color(0.17, 0.23, 0.22, 1.0)
	style.set_border_width_all(2 if focused else 1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _style_text_input(control: Control) -> void:
	control.add_stylebox_override("normal", _make_input_style(false))
	control.add_stylebox_override("focus", _make_input_style(true))
	if control is LineEdit:
		control.add_stylebox_override("hover", _make_input_style(false))
		control.add_color_override("font_color", Color(0.96, 0.96, 0.93))
		control.add_color_override("font_color_selected", Color(1, 1, 1))
		control.add_color_override("selection_color", Color(0.22, 0.48, 0.31, 0.9))
	elif control is TextEdit:
		control.add_stylebox_override("read_only", _make_input_style(false))
		control.add_color_override("font_color", Color(0.96, 0.96, 0.93))
		control.add_color_override("selection_color", Color(0.22, 0.48, 0.31, 0.9))


func _style_option_button(control: OptionButton) -> void:
	control.add_stylebox_override("normal", _make_input_style(false))
	control.add_stylebox_override("hover", _make_input_style(true))
	control.add_stylebox_override("focus", _make_input_style(true))
	control.add_stylebox_override("pressed", _make_input_style(true))
	control.add_color_override("font_color", Color(0.96, 0.96, 0.93))


func _add_help_text(parent: Node, text: String) -> void:
	var help = Label.new()
	help.text = text
	help.autowrap = true
	help.modulate = Color(0.75, 0.75, 0.75)
	var help_font = preload("res://resources/fonts/actual/base/font_26_outline.tres").duplicate()
	if help_font is DynamicFont:
		help_font.size = 20
	help.set("custom_fonts/font", help_font)
	parent.add_child(help)


func _prettify(value: String) -> String:
	var name_parts = value.get_file().replace("_", " ").split(" ")
	for index in range(name_parts.size()):
		name_parts[index] = name_parts[index].capitalize()
	return " ".join(name_parts)
