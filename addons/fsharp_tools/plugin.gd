tool
extends EditorPlugin

##### CLASSES #####

##### SIGNALS #####

##### CONSTANTS #####

const MENU_FSHARP_SETUP := "Setup F# Project"
const MENU_FSHARP_GENERATE_SCRIPT := "Generate F# script from C# script."
const SETTINGS_FSHARP_NAME := "mono/fsharp_tools/auto_generate_f#_scripts"
const SETTINGS_FSHARP_TOOLTIP := "Toggle automatic F# script creation."
# The version of Mono C# that Godot Engine supports
const MONO_VERSION = "net45"

##### PROPERTIES #####

# .NET 4.5 (net45) is the currently supported C# Mono version in Godot Engine.
# GodotSharp.dll is a dependency required for an F# library to access Godot-related classes.
# Library.fs is the default name given to the source file made for a classlib.
var default_fsharp_project_text :=(
"""
<Project Sdk=\"Microsoft.NET.Sdk\">

  <PropertyGroup>
    <TargetFramework>net45</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <Reference Include=\"GodotSharp\">
      <HintPath>%s</HintPath>
    </Reference>
  </ItemGroup>

  <ItemGroup>
    <Compile Include=\"Library.fs\" />
  </ItemGroup>

</Project>

"""
)

# 
var default_fsharp_file_text :=(
"""
namespace %s

open Godot

type %s() =
    inherit %s()
    
    [<Export>]
    member val Text = \"Hello World!\" with get, set
    
    override this._Ready() =
        GD.Print(Text)

"""
)

var default_csharp_file_text :=(
"""
using Godot;
using System;

using %s;

public class ControlCs : %s
{
}

"""
)


var setup_dialog_scn := preload("res://addons/fsharp_tools/fsharp_setup_dialog.tscn")
var create_fsharp_script_scn := preload("res://addons/fsharp_tools/create_fsharp_script_dialog.tscn")

var setup_dialog: ConfirmationDialog = null
var create_fsharp_script_dialog: ConfirmationDialog = null

##### NOTIFICATIONS #####

func _enter_tree() -> void:
	_setup_fsharp_settings()
	_setup_create_fsharp_script_dialog()
	add_tool_menu_item(MENU_FSHARP_SETUP, self, "_show_setup_dialog")
	add_tool_menu_item(MENU_FSHARP_GENERATE_SCRIPT, create_fsharp_script_dialog, "popup_centered_minsize", Vector2.ZERO)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_FSHARP_GENERATE_SCRIPT)
	remove_tool_menu_item(MENU_FSHARP_SETUP)

##### CONNECTIONS #####

func _show_setup_dialog(_p_ud) -> void:
	_setup_setup_dialog()
	setup_dialog.popup_centered_minsize()
	setup_dialog.name_edit.grab_focus()

func _on_tool_create_fsharp_script_pressed() -> void:
	create_fsharp_script_from_csharp(create_fsharp_script_dialog.get_final_path())

##### PRIVATE METHODS #####

func _setup_setup_dialog() -> void:
	setup_dialog = setup_dialog_scn.instance() as ConfirmationDialog
	setup_dialog.call_deferred("init", self)
	setup_dialog.theme = get_editor_theme()
	add_child(setup_dialog)

func _setup_create_fsharp_script_dialog() -> void:
	create_fsharp_script_dialog = create_fsharp_script_scn.instance() as ConfirmationDialog
	create_fsharp_script_dialog.call_deferred("init", self)
	create_fsharp_script_dialog.theme = get_editor_theme()
	add_child(create_fsharp_script_dialog)

func _setup_fsharp_settings() -> void:
	if ProjectSettings.get_setting(SETTINGS_FSHARP_NAME) == null:
		ProjectSettings.add_property_info({
			"name": SETTINGS_FSHARP_NAME,
			"hint_tooltip": "If true, when a user creates a C# script, Godot creates a corresponding F# script and makes the C# script derive it.",
			"type": TYPE_BOOL
		})
		ProjectSettings.set_setting(SETTINGS_FSHARP_NAME, false)

func _print_and_clear_output(var p_output: Array) -> void:
	for line in p_output:
		print(line)
	p_output.clear()

##### PUBLIC METHODS #####

func get_editor_theme() -> Theme:
	return get_editor_interface().get_base_control().theme

func setup_fsharp_project() -> void:
	var res_final_path := setup_dialog.get_final_path() as String
	var final_path := ProjectSettings.globalize_path(res_final_path)
	var output := []
	
	var godot_sharp_path := ""
	if true:
		var a_path := res_final_path
		var start = true
		while a_path != "res://":
			if not start:
				godot_sharp_path += "../"
			a_path = a_path.get_base_dir()
			start = false
		godot_sharp_path += ".mono/assemblies/GodotSharp.dll"
	
	var root_path = "res://" + ProjectSettings.get_setting("application/config/name")
	var csharp_proj_path = ProjectSettings.globalize_path(root_path + ".csproj")
	var sln_path = ProjectSettings.globalize_path(root_path + ".sln")
	
	# Create F# class library and containing directory.
	var dir = Directory.new()
	var base_dir = final_path.get_base_dir()
	var proj_name = final_path.get_file().get_basename()
	if not dir.dir_exists(base_dir):
		dir.make_dir_recursive(base_dir)
	
	print("Running `dotnet new classlib -o %s -n %s -lang F#`" % [base_dir, proj_name])
	# warning-ignore:return_value_discarded
	OS.execute("dotnet", PoolStringArray(["new", "classlib", "-o", base_dir, "-n", proj_name, "-lang", "F#"]), true, output)
	_print_and_clear_output(output)
	
	# Update F# project settings by rewriting entire file (trust me, it's easier this way)
	var fsproj = File.new()
	if fsproj.open(final_path, File.WRITE) != OK:
		push_error("fsharp_tools/plugin.gd::setup_fsharp_project(): Failed to open F# project file at '%s'." % final_path)
		return
	
	var text = default_fsharp_project_text % godot_sharp_path
	fsproj.store_string(text)
	fsproj.close()
	
	# Add the F# library to the solution.
	print("Running `dotnet sln %s add %s`" % [sln_path, final_path])
	# warning-ignore:return_value_discarded
	OS.execute("dotnet", PoolStringArray(["sln", sln_path, "add", final_path]), true, output)
	_print_and_clear_output(output)
	
	# Add the System.Runtime dependency to the F# library.
	print("Running `dotnet add %s package System.Runtime`" % final_path)
	OS.execute("dotnet", PoolStringArray(["add", final_path, "package", "System.Runtime"]), true, output)
	_print_and_clear_output(output)
	
	# Register the F# library to the C# project.
	print("Running `dotnet add %s reference %s`" % [csharp_proj_path, final_path])
	# warning-ignore:return_value_discarded
	OS.execute("dotnet", PoolStringArray(["add", csharp_proj_path, "reference", final_path]), true)
	_print_and_clear_output(output)

func create_fsharp_script_from_csharp(p_path: String) -> void:
	var classname = p_path.get_file().get_basename()
	
	var csharp_classname := ""
	var basename := ""
	if true:
		var regex := RegEx.new()
		regex.compile("public class (?P<classname>.+) : (?P<basename>.+)")
		var f := File.new()
		if f.open(create_fsharp_script_dialog.cs_path_edit.text, File.READ) == OK:
			var match_ = regex.search(f.get_as_text())
			if match_:
				csharp_classname = match_.strings[match_.names.classname] as String
				basename = match_.strings[match_.names.basename] as String
			f.close()
	
	var namespace = create_fsharp_script_dialog.namespace_edit.text
	if not namespace:
		var list := p_path.get_base_dir().split("/", false)
		namespace = list[list.size() - 1]
	
	var text = default_fsharp_file_text % [namespace, classname, basename]
	
	if true:
		var f := File.new()
		if f.open(p_path, File.WRITE) == OK:
			f.store_string(text)
			f.close()
	
	_setup_fsharp_settings()
	if ProjectSettings.get_setting(SETTINGS_FSHARP_NAME):
		var f := File.new()
		if f.open(create_fsharp_script_dialog.cs_path_edit.text, File.WRITE) == OK:
			f.store_string(default_csharp_file_text % classname)
	
	# User will need to add the file to the project themselves as `dotnet` can't do that.
	# Godot's built-in XmlParser class does not have the ability to insert elements or edit existing ones,
	# so there is no *simple* way to just add the necessary registration data to the *.csproj file.