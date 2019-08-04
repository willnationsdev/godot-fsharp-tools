tool
extends ConfirmationDialog

onready var grid := $VBoxContainer/GridContainer
onready var name_edit: LineEdit = grid.get_node("NameEdit")
onready var path_edit: LineEdit = grid.get_node("PathEdit")
onready var path_button: ToolButton = grid.get_node("PathButton")
onready var create_dir_check: CheckBox = grid.get_node("CreateDirCheck")
onready var final_path: Label = $VBoxContainer/FinalPathLabel
onready var file_dialog: FileDialog = $VBoxContainer/FileDialog

var plugin: EditorPlugin = null
var initialized := false

func init(p_plugin: EditorPlugin) -> void:
	if not p_plugin:
		push_error(tr("res://addons/godot-fsharp-tools/fsharp_setup_dialog.gd, line 9: Invalid EditorPlugin reference passed to FSharpSetupDialog. Please open an issue at https://github.com/willnationsdev/godot-fsharp-tools."))
		return
	
	if initialized:
		return
	
	initialized = true
	
	plugin = p_plugin
	theme = plugin.get_editor_theme()
	
	# warning-ignore:return_value_discarded
	path_button.connect("pressed", file_dialog, "popup_centered_ratio", [0.75])
	# warning-ignore:return_value_discarded
	create_dir_check.connect("toggled", self, "_reset_final_path")
	# warning-ignore:return_value_discarded
	name_edit.connect("text_changed", self, "_reset_final_path")
	# warning-ignore:return_value_discarded
	path_edit.connect("text_changed", self, "_reset_final_path")
	# warning-ignore:return_value_discarded
	connect("confirmed", self, "_on_confirmed")

func _on_confirmed():
	plugin.setup_fsharp_project(get_final_path())

func _reset_final_path(_p_text) -> void:
	final_path.text = path_edit.text.plus_file((name_edit.text + "/" if create_dir_check.pressed else "") + name_edit.text + ".fsproj")

func get_final_path() -> String:
	return final_path.text