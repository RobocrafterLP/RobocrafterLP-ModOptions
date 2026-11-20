extends Reference

signal value_changed(config_path, value)

var manager = null
var mod_id := ""
var config_name := ""


func get_value(config_path: String):
	if not is_instance_valid(manager):
		return null
	return manager.get_extra_value(mod_id, config_name, config_path)


func set_value(config_path: String, value) -> void:
	if is_instance_valid(manager):
		manager.set_extra_value(mod_id, config_name, config_path, value)


func get_values() -> Dictionary:
	if not is_instance_valid(manager):
		return {}
	return manager.get_extra_values(mod_id, config_name)


func get_schema() -> Dictionary:
	if not is_instance_valid(manager):
		return {}
	return manager.get_extra_schema(mod_id, config_name)


func has_saved_value(config_path: String) -> bool:
	if not is_instance_valid(manager):
		return false
	return manager.has_saved_extra_value(mod_id, config_name, config_path)


func create_config_screen(parent_window: Node = null, schema_override: Dictionary = {}) -> Control:
	if not is_instance_valid(manager):
		return null
	return manager.create_extra_config_screen(mod_id, config_name, parent_window, schema_override)


func _on_manager_extra_value_changed(changed_mod_id: String, changed_config_name: String, config_path: String, value) -> void:
	if changed_mod_id == mod_id and changed_config_name == config_name:
		emit_signal("value_changed", config_path, value)
