extends Node

const MOD_DIR_NAME := "RobocrafterLP-ModOptions"
const MOD_ID := "RobocrafterLP-ModOptions"


func _init() -> void:
	var mod_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	var extension_path = mod_dir.plus_file("extensions/ui/menus/pages/menu_options.gd")
	ModLoaderMod.install_script_extension(extension_path)

	var manager_script = load(mod_dir.plus_file("mod_options_manager.gd"))
	if manager_script == null:
		ModLoaderLog.error("Could not load the ModOptions manager", MOD_ID)
		return
	var manager = manager_script.new()
	manager.name = "ModOptions"
	add_child(manager)
