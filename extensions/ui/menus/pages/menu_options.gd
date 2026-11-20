extends "res://ui/menus/pages/menu_options.gd"

const MOD_ID := "RobocrafterLP-ModOptions"
const MOD_BUTTON_NAME := "RobocrafterLP_ModsButton"
const MOD_TAB_NAME := "RobocrafterLPModOptionsTab"
const MOD_BUTTON_ICON := preload("res://ui/menus/global/mods_icon.png")


func _ready() -> void:
	._ready()
	call_deferred("_inject_mod_options_tab")


func _inject_mod_options_tab() -> void:
	var manager_node = get_node_or_null("/root/ModLoader/%s/ModOptions" % MOD_ID)
	if manager_node == null:
		return
	var button_container = get_node_or_null("Buttons/HBoxContainer2")
	var button_controller = get_node_or_null("Buttons")
	var tabs_row = get_node_or_null("Buttons/HBoxContainer3")
	var tab_container = get_node_or_null("Buttons/HBoxContainer3/TabContainer")
	if button_container == null or button_controller == null or tabs_row == null or tab_container == null:
		return
	tabs_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.rect_min_size.x = 0
	if tab_container.get_node_or_null(MOD_TAB_NAME) != null:
		return

	var settings_tab = manager_node.create_options_tab()
	settings_tab.name = MOD_TAB_NAME
	var tab_index = tab_container.get_child_count()
	tab_container.add_child(settings_tab)

	var button = button_container.get_node_or_null(MOD_BUTTON_NAME)
	if button == null:
		var template = button_container.get_node_or_null("Accessibility_but")
		if template == null:
			return
		button = template.duplicate()
		button.name = MOD_BUTTON_NAME
		button.text = "Mods"
		button.icon = MOD_BUTTON_ICON
		button_container.add_child_below_node(template, button)
		button_controller.buttons_tab_np.push_back(button.get_path())
		button_controller.buttons_tab.push_back(button)
		button.connect("pressed", button_controller, "_change_tab", [tab_index])
