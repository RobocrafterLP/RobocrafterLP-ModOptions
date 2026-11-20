extends Node

signal config_changed(mod_id, config_path, value)
signal extra_config_changed(mod_id, config_name, config_path, value)
signal mod_registered(mod_id)

const Registration = preload("res://mods-unpacked/RobocrafterLP-ModOptions/api/mod_options_registration.gd")
const ExtraConfig = preload("res://mods-unpacked/RobocrafterLP-ModOptions/api/mod_options_extra_config.gd")
const ConfigScreen = preload("res://mods-unpacked/RobocrafterLP-ModOptions/ui/mod_options_config_screen.gd")
const OptionsTab = preload("res://mods-unpacked/RobocrafterLP-ModOptions/ui/mod_options_tab.gd")

const MOD_ID := "RobocrafterLP-ModOptions"
const SAVE_ROOT := "user://modsettings"
const SAVE_DELAY := 0.35

var _schemas := {}
var _names := {}
var _values := {}
var _loaded_values := {}
var _registrations := {}
var _pending_saves := {}
var _extra_configs := {}
var _pending_extra_saves := {}
var _save_timer: Timer


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.pause_mode = Node.PAUSE_MODE_PROCESS
	_save_timer.connect("timeout", self, "_flush_pending_saves")
	add_child(_save_timer)
	_register_manifest_schemas()


func _exit_tree() -> void:
	_flush_pending_saves()


func _register_manifest_schemas() -> void:
	var all_mods = ModLoaderMod.get_mod_data_all()
	for mod_id in all_mods.keys():
		var mod_data = all_mods[mod_id]
		if mod_data == null or mod_data.manifest == null or not mod_data.is_loadable:
			continue
		var schema = mod_data.manifest.config_schema
		if typeof(schema) != TYPE_DICTIONARY or schema.empty():
			continue
		register_mod_options(mod_id, schema, mod_data.manifest.name)


func register_mod_options(mod_id: String, config_schema: Dictionary, display_name: String = ""):
	if mod_id.empty() or mod_id == "." or mod_id == ".." or mod_id.find("/") != -1 or mod_id.find("\\") != -1:
		ModLoaderLog.warning("Rejected invalid mod id for settings storage", MOD_ID)
		return null
	if not _is_schema_valid(config_schema):
		ModLoaderLog.warning("Skipped invalid or empty config schema for %s" % mod_id, MOD_ID)
		return null
	if _registrations.has(mod_id):
		_merge_schema_properties(_schemas[mod_id], config_schema)
		_merge_missing_values(_values[mod_id], _default_values(config_schema.get("properties", {})))
		_load_values(mod_id)
		return _registrations[mod_id]

	_schemas[mod_id] = config_schema.duplicate(true)
	_names[mod_id] = display_name if not display_name.empty() else _display_name_from_id(mod_id)
	_values[mod_id] = _default_values(_schemas[mod_id].get("properties", {}))
	# One-time migration source for mods that already used ModLoader's config
	# files. The dedicated modsettings file takes precedence when it exists.
	var existing_config = null
	var user_profile = ModLoaderStore.current_user_profile
	if user_profile != null and user_profile.mod_list.has(mod_id) and user_profile.mod_list[mod_id].has("current_config"):
		existing_config = ModLoaderConfig.get_current_config(mod_id)
	if existing_config != null and typeof(existing_config.data) == TYPE_DICTIONARY:
		_merge_saved_values(mod_id, existing_config.data, _schemas[mod_id].get("properties", {}), _values[mod_id])
	_load_values(mod_id)

	var registration = Registration.new()
	registration.manager = self
	registration.mod_id = mod_id
	# Forward manager changes to this registration instance.
	connect("config_changed", registration, "_on_manager_value_changed")
	_registrations[mod_id] = registration
	emit_signal("mod_registered", mod_id)
	return registration


func add_extra_config(mod_id: String, config_name: String, config_schema: Dictionary):
	if not _registrations.has(mod_id):
		ModLoaderLog.warning("Register the mod before adding extra config files", MOD_ID)
		return null
	if config_name.empty() or config_name == "." or config_name == ".." or config_name.find("/") != -1 or config_name.find("\\") != -1 or config_name.find(".") != -1 or config_name.find(":") != -1:
		ModLoaderLog.warning("Rejected invalid extra config name", MOD_ID)
		return null
	if not _is_schema_valid(config_schema):
		ModLoaderLog.warning("Skipped invalid or empty extra config schema '%s' for %s" % [config_name, mod_id], MOD_ID)
		return null
	if not _extra_configs.has(mod_id):
		_extra_configs[mod_id] = {}
	if _extra_configs[mod_id].has(config_name):
		var existing = _extra_configs[mod_id][config_name]
		_merge_schema_properties(existing.schema, config_schema)
		_merge_missing_values(existing.values, _default_values(config_schema.get("properties", {})))
		_merge_saved_values(mod_id, existing.loaded_values, existing.schema.get("properties", {}), existing.values)
		return existing.handle
	var entry = {
		"schema": config_schema.duplicate(true),
		"values": _default_values(config_schema.get("properties", {})),
		"loaded_values": {},
	}
	_extra_configs[mod_id][config_name] = entry
	_load_extra_config(mod_id, config_name)
	var handle = ExtraConfig.new()
	handle.manager = self
	handle.mod_id = mod_id
	handle.config_name = config_name
	entry.handle = handle
	connect("extra_config_changed", handle, "_on_manager_extra_value_changed")
	return handle


func get_extra_values(mod_id: String, config_name: String) -> Dictionary:
	var entry = _get_extra_entry(mod_id, config_name)
	return entry.values.duplicate(true) if entry != null else {}


func get_extra_schema(mod_id: String, config_name: String) -> Dictionary:
	var entry = _get_extra_entry(mod_id, config_name)
	return entry.schema.duplicate(true) if entry != null else {}


func has_saved_extra_value(mod_id: String, config_name: String, config_path: String) -> bool:
	var entry = _get_extra_entry(mod_id, config_name)
	return entry != null and _get_path_value(entry.loaded_values, config_path) != null


func get_extra_value(mod_id: String, config_name: String, config_path: String):
	var entry = _get_extra_entry(mod_id, config_name)
	return _get_path_value(entry.values, config_path) if entry != null else null


func set_extra_value(mod_id: String, config_name: String, config_path: String, value) -> void:
	var entry = _get_extra_entry(mod_id, config_name)
	if entry == null:
		return
	var property_schema = _get_property_schema(entry.schema.get("properties", {}), config_path)
	if property_schema.empty():
		ModLoaderLog.warning("Unknown extra config value '%s' for %s/%s" % [config_path, mod_id, config_name], MOD_ID)
		return
	var normalized = _normalize_value(value, property_schema)
	if normalized == null and property_schema.get("type", "") != "null":
		return
	_set_path_value(entry.values, config_path, normalized)
	_set_path_value(entry.loaded_values, config_path, normalized)
	var save_key = mod_id + "::" + config_name
	_pending_extra_saves[save_key] = true
	_save_timer.start()
	emit_signal("extra_config_changed", mod_id, config_name, config_path, normalized)


func create_extra_config_screen(mod_id: String, config_name: String, parent_window: Node = null, schema_override: Dictionary = {}) -> Control:
	var entry = _get_extra_entry(mod_id, config_name)
	if entry == null:
		return null
	var screen = ConfigScreen.new()
	screen.manager = self
	screen.mod_id = mod_id
	screen.extra_config = entry.handle
	screen.build(schema_override)
	if parent_window != null:
		screen.parent_to(parent_window)
	return screen


func _get_extra_entry(mod_id: String, config_name: String):
	if not _extra_configs.has(mod_id):
		return null
	return _extra_configs[mod_id].get(config_name)


func _load_extra_config(mod_id: String, config_name: String) -> void:
	var entry = _get_extra_entry(mod_id, config_name)
	if entry == null:
		return
	entry.loaded_values = {}
	var file = File.new()
	var save_path = SAVE_ROOT.plus_file(mod_id).plus_file(config_name + ".json")
	if not file.file_exists(save_path):
		return
	if file.open(save_path, File.READ) != OK:
		ModLoaderLog.warning("Could not read extra settings '%s' for %s" % [config_name, mod_id], MOD_ID)
		return
	var parsed = JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK or typeof(parsed.result) != TYPE_DICTIONARY:
		ModLoaderLog.warning("Invalid extra settings JSON '%s' for %s" % [config_name, mod_id], MOD_ID)
		return
	entry.loaded_values = parsed.result.duplicate(true)
	_merge_saved_values(mod_id, parsed.result, entry.schema.get("properties", {}), entry.values)


func _save_extra_config(mod_id: String, config_name: String) -> void:
	var entry = _get_extra_entry(mod_id, config_name)
	if entry == null:
		return
	var folder_path = SAVE_ROOT.plus_file(mod_id)
	var directory = Directory.new()
	if not directory.dir_exists(folder_path) and directory.make_dir_recursive(folder_path) != OK:
		ModLoaderLog.error("Could not create settings folder for %s" % mod_id, MOD_ID)
		return
	var file = File.new()
	if file.open(folder_path.plus_file(config_name + ".json"), File.WRITE) != OK:
		ModLoaderLog.error("Could not save extra settings '%s' for %s" % [config_name, mod_id], MOD_ID)
		return
	file.store_string(JSON.print(entry.values, "\t", true))
	file.close()


func get_registration(mod_id: String):
	return _registrations.get(mod_id)


func get_registered_mods() -> Array:
	var result = _registrations.keys()
	result.sort()
	return result


func get_mod_name(mod_id: String) -> String:
	return _names.get(mod_id, mod_id)


func get_schema(mod_id: String) -> Dictionary:
	return _schemas.get(mod_id, {}).duplicate(true)


func get_values(mod_id: String) -> Dictionary:
	return _values.get(mod_id, {}).duplicate(true)


func has_saved_settings(mod_id: String) -> bool:
	return File.new().file_exists(_get_save_path(mod_id))


func has_saved_value(mod_id: String, config_path: String) -> bool:
	return _loaded_values.has(mod_id) and _get_path_value(_loaded_values[mod_id], config_path) != null


func get_saved_value(mod_id: String, config_path: String):
	if not _loaded_values.has(mod_id):
		return null
	return _get_path_value(_loaded_values[mod_id], config_path)


func get_value(mod_id: String, config_path: String):
	if not _values.has(mod_id):
		return null
	return _get_path_value(_values[mod_id], config_path)


func set_value(mod_id: String, config_path: String, value) -> void:
	if not _values.has(mod_id):
		return
	var property_schema = _get_property_schema(_schemas[mod_id].get("properties", {}), config_path)
	if property_schema.empty():
		ModLoaderLog.warning("Unknown config value '%s' for %s" % [config_path, mod_id], MOD_ID)
		return
	var normalized = _normalize_value(value, property_schema)
	if normalized == null and property_schema.get("type", "") != "null":
		return
	_set_path_value(_values[mod_id], config_path, normalized)
	_pending_saves[mod_id] = true
	_save_timer.start()
	emit_signal("config_changed", mod_id, config_path, normalized)


func create_config_screen(mod_id: String, parent_window: Node = null, schema_override: Dictionary = {}) -> Control:
	if not _schemas.has(mod_id):
		return null
	var screen = ConfigScreen.new()
	screen.manager = self
	screen.mod_id = mod_id
	screen.build(schema_override)
	if parent_window != null:
		screen.parent_to(parent_window)
	return screen


func create_options_tab() -> Control:
	var tab = OptionsTab.new()
	tab.manager = self
	tab.build()
	return tab


func _load_values(mod_id: String) -> void:
	_loaded_values[mod_id] = {}
	var save_path = _get_save_path(mod_id)
	var file = File.new()
	if not file.file_exists(save_path):
		return
	if file.open(save_path, File.READ) != OK:
		ModLoaderLog.warning("Could not read settings for %s" % mod_id, MOD_ID)
		return
	var parsed = JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK or typeof(parsed.result) != TYPE_DICTIONARY:
		ModLoaderLog.warning("Invalid settings JSON for %s; using manifest defaults" % mod_id, MOD_ID)
		return
	_loaded_values[mod_id] = parsed.result.duplicate(true)
	_merge_saved_values(mod_id, parsed.result, _schemas[mod_id].get("properties", {}), _values[mod_id])


func _merge_saved_values(mod_id: String, saved: Dictionary, properties: Dictionary, destination: Dictionary) -> void:
	for key in properties.keys():
		if not saved.has(key):
			continue
		var property_schema = properties[key]
		if property_schema.get("type", "") == "object":
			if typeof(saved[key]) == TYPE_DICTIONARY and destination.get(key) is Dictionary:
				_merge_saved_values(mod_id, saved[key], property_schema.get("properties", {}), destination[key])
		else:
			var normalized = _normalize_value(saved[key], property_schema)
			if normalized != null or property_schema.get("type", "") == "null":
				destination[key] = normalized


func _default_values(properties: Dictionary) -> Dictionary:
	var result = {}
	for key in properties.keys():
		var property_schema = properties[key]
		if property_schema.get("type", "") == "object":
			result[key] = _default_values(property_schema.get("properties", {}))
		else:
			result[key] = property_schema.get("default", _type_default(property_schema))
	return result


func _merge_schema_properties(target_schema: Dictionary, source_schema: Dictionary) -> void:
	var target_properties = target_schema.get("properties", {})
	for key in source_schema.get("properties", {}).keys():
		var source_property = source_schema.properties[key]
		if target_properties.has(key) and target_properties[key].get("type", "") == "object" and source_property.get("type", "") == "object":
			_merge_schema_properties(target_properties[key], source_property)
		elif not target_properties.has(key):
			target_properties[key] = source_property.duplicate(true)


func _merge_missing_values(target: Dictionary, defaults: Dictionary) -> void:
	for key in defaults.keys():
		if not target.has(key):
			target[key] = defaults[key].duplicate(true) if typeof(defaults[key]) == TYPE_DICTIONARY or typeof(defaults[key]) == TYPE_ARRAY else defaults[key]
		elif typeof(defaults[key]) == TYPE_DICTIONARY and typeof(target[key]) == TYPE_DICTIONARY:
			_merge_missing_values(target[key], defaults[key])


func _type_default(property_schema: Dictionary):
	var type_name = property_schema.get("type", "")
	if type_name is Array:
		type_name = type_name[0] if not type_name.empty() else ""
	match type_name:
		"boolean":
			return false
		"integer", "number":
			return 0
		"string":
			var values = property_schema.get("enum", [])
			return values[0] if values is Array and not values.empty() else ""
		"array":
			return []
		"object":
			return _default_values(property_schema.get("properties", {}))
	return null


func _normalize_value(value, property_schema):
	if property_schema.has("enum"):
		return value if property_schema.enum.has(value) else null
	var type_name = property_schema.get("type", "")
	if type_name is Array:
		type_name = type_name[0] if not type_name.empty() else ""
	match type_name:
		"boolean":
			return value if typeof(value) == TYPE_BOOL else null
		"integer":
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_REAL:
				return null
			var int_value = int(round(float(value)))
			return int(clamp(int_value, int(property_schema.get("minimum", int_value)), int(property_schema.get("maximum", int_value))))
		"number":
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_REAL:
				return null
			return clamp(float(value), float(property_schema.get("minimum", -INF)), float(property_schema.get("maximum", INF)))
		"string":
			if typeof(value) != TYPE_STRING:
				return null
			if property_schema.get("format", "") == "color":
				return _normalize_color_string(value)
			return value
		"array":
			return value if typeof(value) == TYPE_ARRAY else null
		"object":
			return value if typeof(value) == TYPE_DICTIONARY else null
	return value


func _normalize_color_string(value: String) -> String:
	var color_text = value.strip_edges()
	if color_text.begins_with("#"):
		color_text = color_text.substr(1)
	if color_text.length() != 6 and color_text.length() != 8:
		return "ffffff"
	for character in color_text:
		if "0123456789abcdefABCDEF".find(character) == -1:
			return "ffffff"
	return color_text.to_lower()


func _get_property_schema(properties: Dictionary, config_path: String) -> Dictionary:
	var path = config_path.split(".")
	var current = properties
	for index in range(path.size()):
		var key = path[index]
		if not current.has(key) or typeof(current[key]) != TYPE_DICTIONARY:
			return {}
		var property_schema = current[key]
		if index == path.size() - 1:
			return property_schema
		if property_schema.get("type", "") != "object":
			return {}
		current = property_schema.get("properties", {})
	return {}


func _get_path_value(source: Dictionary, config_path: String):
	var current = source
	for key in config_path.split("."):
		if typeof(current) != TYPE_DICTIONARY or not current.has(key):
			return null
		current = current[key]
	return current


func _set_path_value(destination: Dictionary, config_path: String, value) -> void:
	var path = config_path.split(".")
	var current = destination
	for index in range(path.size() - 1):
		if not current.has(path[index]) or typeof(current[path[index]]) != TYPE_DICTIONARY:
			current[path[index]] = {}
		current = current[path[index]]
	current[path[path.size() - 1]] = value


func _validate_schema(properties: Dictionary) -> bool:
	for key in properties.keys():
		var property_schema = properties[key]
		if typeof(property_schema) != TYPE_DICTIONARY:
			return false
		var type_name = property_schema.get("type", "")
		if type_name is Array:
			type_name = type_name[0] if not type_name.empty() else ""
		if type_name == "object":
			if not _validate_schema(property_schema.get("properties", {})):
				return false
		elif not ["boolean", "integer", "number", "string", "array"].has(type_name):
			return false
		if property_schema.has("enum") and (typeof(property_schema.enum) != TYPE_ARRAY or property_schema.enum.empty()):
			return false
	return true


func _is_schema_valid(schema: Dictionary) -> bool:
	var properties = schema.get("properties", {})
	return typeof(properties) == TYPE_DICTIONARY and not properties.empty() and _validate_schema(properties)


func _get_save_path(mod_id: String) -> String:
	return SAVE_ROOT.plus_file(mod_id).plus_file("_main.json")


func _save_config(mod_id: String) -> void:
	if not _values.has(mod_id):
		return
	var directory = Directory.new()
	var folder_path = SAVE_ROOT.plus_file(mod_id)
	if not directory.dir_exists(folder_path) and directory.make_dir_recursive(folder_path) != OK:
		ModLoaderLog.error("Could not create settings folder for %s" % mod_id, MOD_ID)
		return
	var file = File.new()
	var save_path = _get_save_path(mod_id)
	if file.open(save_path, File.WRITE) != OK:
		ModLoaderLog.error("Could not save settings for %s" % mod_id, MOD_ID)
		return
	file.store_string(JSON.print(_values[mod_id], "\t", true))
	file.close()


func _flush_pending_saves() -> void:
	for mod_id in _pending_saves.keys():
		_save_config(mod_id)
	_pending_saves.clear()
	for save_key in _pending_extra_saves.keys():
		var key_parts = save_key.split("::")
		if key_parts.size() == 2:
			_save_extra_config(key_parts[0], key_parts[1])
	_pending_extra_saves.clear()


func _display_name_from_id(mod_id: String) -> String:
	var parts = mod_id.split("-")
	return parts[parts.size() - 1] if not parts.empty() else mod_id
