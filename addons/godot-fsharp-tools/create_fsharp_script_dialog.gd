tool
extends ConfirmationDialog

onready var grid := $VBoxContainer/GridContainer
onready var cs_path_edit: LineEdit = grid.get_node("CSPathEdit")
onready var cs_path_button: ToolButton = grid.get_node("CSPathButton")
onready var fs_proj_path_edit: LineEdit = grid.get_node("FSProjPathEdit")
onready var fs_proj_path_button: ToolButton = grid.get_node("FSProjPathButton")
# warning-ignore:unused_class_variable
onready var namespace_edit: LineEdit = grid.get_node("NamespaceEdit")
# warning-ignore:unused_class_variable
onready var name_edit: LineEdit = grid.get_node("NameEdit")
onready var final_path: Label = $VBoxContainer/FinalPathLabel
onready var file_dialog_cs: FileDialog = $VBoxContainer/FileDialogCS
onready var file_dialog_fs: FileDialog = $VBoxContainer/FileDialogLib

var plugin: EditorPlugin = null
var initialized := false

func init(p_plugin: EditorPlugin) -> void:
	if not p_plugin:
		push_error(tr("%s/fsharp_setup_dialog.gd, line 9: Invalid EditorPlugin reference passed to FSharpSetupDialog. Please open an issue at https://github.com/willnationsdev/%s." % [plugin.PLUGIN_DIR, plugin.REPO_NAME]))
		return
	
	if initialized:
		return
	
	initialized = true
	
	plugin = p_plugin
	theme = plugin.get_editor_theme()
	
	# warning-ignore:return_value_discarded
	cs_path_button.connect("pressed", file_dialog_cs, "popup_centered_ratio", [0.75])
	# warning-ignore:return_value_discarded
	fs_proj_path_button.connect("pressed", file_dialog_fs, "popup_centered_ratio", [0.75])
	# warning-ignore:return_value_discarded
	cs_path_edit.connect("text_changed", self, "_reset_final_path")
	# warning-ignore:return_value_discarded
	fs_proj_path_edit.connect("text_changed", self, "_reset_final_path")
	# warning-ignore:return_value_discarded
	file_dialog_cs.connect("confirmed", self, "_on_cs_path_confirmed")
	# warning-ignore:return_value_discarded
	file_dialog_cs.connect("file_selected", self, "_on_cs_path_confirmed")
	# warning-ignore:return_value_discarded
	file_dialog_fs.connect("confirmed", self, "_on_fs_proj_path_confirmed")
	# warning-ignore:return_value_discarded
	file_dialog_fs.connect("file_selected", self, "_on_fs_proj_path_confirmed")
	# warning-ignore:return_value_discarded
	connect("confirmed", self, "_on_confirmed")

func _on_confirmed() -> void:
	plugin.create_fsharp_script_from_csharp(get_final_path(), cs_path_edit.text, name_edit.text, namespace_edit.text)

func _on_cs_path_confirmed(_p_path = "") -> void:
	cs_path_edit.text = file_dialog_cs.current_path
	_reset_final_path()

func _on_fs_proj_path_confirmed(_p_path = "") -> void:
	fs_proj_path_edit.text = file_dialog_fs.current_path
	_reset_final_path()

func _reset_final_path(_p_text = null) -> void:
	final_path.text = fs_proj_path_edit.text.get_base_dir().plus_file(cs_path_edit.text.get_file().get_basename() + "Fs.fs")

func get_final_path() -> String:
	return final_path.text