tool
extends EditorPlugin

##### CLASSES #####

##### SIGNALS #####

##### CONSTANTS #####

const MENU_FSHARP_SETUP := "Setup F# Project"
const MENU_FSHARP_GENERATE_SCRIPT := "Generate F# script from C# script."
const SETTINGS_FSHARP_NAME := "mono/fsharp_tools/auto_generate_f#_scripts"
const SETTINGS_FSHARP_TOOLTIP := "Toggle automatic F# script creation."

##### PROPERTIES #####

var setup_dialog_scn := preload("res://addons/fsharp_tools/fsharp_setup_dialog.tscn")

var setup_dialog: ConfirmationDialog = null
var find_csharp: FileDialog = null

##### NOTIFICATIONS #####

func _enter_tree() -> void:
	_setup_fsharp_settings()
	_setup_find_csharp()
	add_tool_menu_item(MENU_FSHARP_SETUP, self, "_show_setup_dialog")
	add_tool_menu_item(MENU_FSHARP_GENERATE_SCRIPT, find_csharp, "popup_centered_ratio", 0.75)

func _exit_tree() -> void:
	if find_csharp:
		find_csharp.queue_free()
	remove_tool_menu_item(MENU_FSHARP_GENERATE_SCRIPT)
	remove_tool_menu_item(MENU_FSHARP_SETUP)

##### CONNECTIONS #####

func _show_setup_dialog(_p_ud) -> void:
	_setup_setup_dialog()
	setup_dialog.popup_centered_minsize()

func setup_fsharp_project() -> void:
	var final_path := ProjectSettings.globalize_path(setup_dialog.get_final_path())
	
	var dir = Directory.new()
	var base_dir = final_path.get_base_dir()
	if not dir.dir_exists(base_dir):
		dir.make_dir_recursive(base_dir)
	
	OS.execute("dotnet", PoolStringArray(["new", "-o", base_dir, "-lang", "\"F#\""]), true)
	
	if not dir.dir_exists(final_path):
		push_error("fsharp_tools/plugin.gd::setup_fsharp_project(): Failed to create F# library project.")
		return
	
	print(final_path)
	var csharp_sln_path = ProjectSettings.globalize_path("res://" + ProjectSettings.get_setting("application/config/name") + ".sln")
	print(csharp_sln_path)
	print("setup_fsharp_project")

func create_fsharp_script() -> void:
	print("create_fsharp_script")

##### PRIVATE METHODS #####

func _setup_setup_dialog() -> void:
	setup_dialog = setup_dialog_scn.instance()
	setup_dialog.call_deferred("init", self)
	setup_dialog.theme = get_editor_theme()
	add_child(setup_dialog)

func _setup_find_csharp() -> void:
	find_csharp = FileDialog.new()
	find_csharp.access = FileDialog.ACCESS_RESOURCES
	find_csharp.dialog_hide_on_ok = true
	find_csharp.mode = FileDialog.MODE_OPEN_FILE
	find_csharp.filters = PoolStringArray(["*.cs ; C# Scripts"])
	find_csharp.window_title = "Select a C# script for which to generate F#"
	find_csharp.theme = get_editor_theme()
	# warning-ignore:return_value_discarded
	find_csharp.connect("confirmed", self, "create_fsharp_script")
	add_child(find_csharp)

func _setup_fsharp_settings() -> void:
	if ProjectSettings.get_setting(SETTINGS_FSHARP_NAME) == null:
		ProjectSettings.add_property_info({
			"name": SETTINGS_FSHARP_NAME,
			"hint_tooltip": "If true, when a user creates a C# script, Godot creates a corresponding F# script and makes the C# script derive it.",
			"type": TYPE_BOOL
		})
		ProjectSettings.set_setting(SETTINGS_FSHARP_NAME, false)

##### PUBLIC METHODS #####

func get_editor_theme():
	return get_editor_interface().get_base_control().theme