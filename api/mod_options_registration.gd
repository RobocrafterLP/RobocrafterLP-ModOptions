extends Reference

signal value_changed(config_path, value)

var manager = null
var mod_id := ""


func get_value(config_path: String):
	if not is_instance_valid(manager):
		return null
	return manager.get_value(mod_id, config_path)


func set_value(config_path: String, value) -> void:
	if is_instance_valid(manager):
		manager.set_value(mod_id, config_path, value)


func get_values() -> Dictionary:
	if not is_instance_valid(manager):
		return {}
	return manager.get_values(mod_id)


func get_schema() -> Dictionary:
	if not is_instance_valid(manager):
		return {}
	return manager.get_schema(mod_id)


func add_extra_config(config_name: String, config_schema: Dictionary):
	if not is_instance_valid(manager):
		return null
	return manager.add_extra_config(mod_id, config_name, config_schema)


func create_config_screen(parent_window: Node = null, schema_override: Dictionary = {}) -> Control:
	if not is_instance_valid(manager):
		return null
	return manager.create_config_screen(mod_id, parent_window, schema_override)


func _on_manager_value_changed(changed_mod_id: String, config_path: String, value) -> void:
	if changed_mod_id == mod_id:
		emit_signal("value_changed", config_path, value)
