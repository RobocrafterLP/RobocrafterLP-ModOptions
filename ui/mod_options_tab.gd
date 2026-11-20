extends HBoxContainer

const SIDEBAR_WIDTH := 300.0

var manager = null
var _sidebar: VBoxContainer
var _screen_host: Control
var _selected_mod_id := ""


func build() -> void:
	name = "RobocrafterLPModOptionsTab"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set("custom_constants/separation", 18)
	var sidebar_scroll = ScrollContainer.new()
	sidebar_scroll.name = "ModOptionsSidebarScroll"
	sidebar_scroll.rect_min_size.x = SIDEBAR_WIDTH
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll.scroll_horizontal_enabled = false
	_sidebar = VBoxContainer.new()
	_sidebar.name = "ModOptionsSidebar"
	_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.add_child(_sidebar)
	add_child(sidebar_scroll)
	var separator = VSeparator.new()
	add_child(separator)
	var host = VBoxContainer.new()
	host.name = "SettingsHost"
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(host)
	_screen_host = host
	if not manager.is_connected("mod_registered", self, "_on_mod_registered"):
		manager.connect("mod_registered", self, "_on_mod_registered")
	_rebuild_sidebar()


func _rebuild_sidebar() -> void:
	for child in _sidebar.get_children():
		_sidebar.remove_child(child)
		child.queue_free()
	var mod_ids = manager.get_registered_mods()
	if mod_ids.empty():
		var empty_label = Label.new()
		empty_label.text = "No mods have configuration options."
		_sidebar.add_child(empty_label)
		return
	for mod_id in mod_ids:
		var button = Button.new()
		button.text = manager.get_mod_name(mod_id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.connect("pressed", self, "_select_mod", [mod_id])
		_sidebar.add_child(button)
	if _selected_mod_id.empty() or not mod_ids.has(_selected_mod_id):
		_select_mod(mod_ids[0])


func _select_mod(mod_id: String) -> void:
	_selected_mod_id = mod_id
	for child in _screen_host.get_children():
		_screen_host.remove_child(child)
		child.queue_free()
	var screen = manager.create_config_screen(mod_id)
	if screen != null:
		_screen_host.add_child(screen)


func _on_mod_registered(_mod_id: String) -> void:
	_rebuild_sidebar()
