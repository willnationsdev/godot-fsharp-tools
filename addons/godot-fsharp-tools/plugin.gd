tool
extends EditorPlugin

##### CLASSES #####

##### SIGNALS #####

##### CONSTANTS #####

const MENU_FSHARP_SETUP := "Setup F# project..."
const MENU_FSHARP_GENERATE_SCRIPT := "Generate F# script from C# script..."
const SETTINGS_FSHARP_AUTOGEN := "mono/f#_tools/auto_generate_f#_scripts"
const SETTINGS_FSHARP_DEFAULT_OUTPUT_DIR := "mono/f#_tools/default_output_dir"
const SETTINGS_FSHARP_DEFAULT_NAMESPACE := "mono/f#_tools/default_namespace"
# The version of Mono C# that Godot Engine supports

const REPO_NAME = "godot-fsharp-tools"
const PLUGIN_DIR = "res://addons/" + REPO_NAME

##### PROPERTIES #####

# .NET 4.5 (net45) is the currently supported C# Mono version in Godot Engine.
# GodotSharp.dll is a dependency required for an F# library to access Godot-related classes.
# Library.fs is the default name given to the source file made for a classlib.
var default_fsharp_project_text :=(
"""<Project Sdk=\"Microsoft.NET.Sdk\">

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
"""namespace %s

open Godot

type %s() =
    inherit %s()

    [<Export>]
    member val Text = \"Hello World!\" with get, set

    override this._Ready() =
        GD.Print(this.Text)
"""
)

var default_csharp_file_text :=(
"""using Godot;
using System;

using %s;

public class %s : %s
{
}

"""
)

var setup_dialog_scn := preload("res://addons/godot-fsharp-tools/fsharp_setup_dialog.tscn")
var create_fsharp_script_scn := preload("res://addons/godot-fsharp-tools/create_fsharp_script_dialog.tscn")

var setup_dialog: ConfirmationDialog = null
var create_fsharp_script_dialog: ConfirmationDialog = null

##### NOTIFICATIONS #####

func _enter_tree() -> void:
	_setup_fsharp_settings()
	_setup_create_fsharp_script_dialog()
	add_tool_menu_item(MENU_FSHARP_SETUP, self, "_show_setup_dialog")
	add_tool_menu_item(MENU_FSHARP_GENERATE_SCRIPT, create_fsharp_script_dialog, "popup_centered_minsize", Vector2.ZERO)
	
	var fs := get_editor_interface().get_resource_filesystem()
	# warning-ignore:return_value_discarded
	fs.connect("filesystem_changed", self, "_on_filesystem_changed")

func _exit_tree() -> void:
	ProjectSettings.set_setting(SETTINGS_FSHARP_AUTOGEN, null)
	ProjectSettings.set_setting(SETTINGS_FSHARP_DEFAULT_NAMESPACE, null)
	ProjectSettings.set_setting(SETTINGS_FSHARP_DEFAULT_OUTPUT_DIR, null)
	remove_tool_menu_item(MENU_FSHARP_GENERATE_SCRIPT)
	remove_tool_menu_item(MENU_FSHARP_SETUP)

##### CONNECTIONS #####

func _show_setup_dialog(_p_ud) -> void:
	_setup_setup_dialog()
	setup_dialog.popup_centered_minsize()
	setup_dialog.name_edit.grab_focus()

func _on_filesystem_changed() -> void:
	if true and "Prerequisites Check":
		var dir := Directory.new()
		if not (ProjectSettings.has_setting(SETTINGS_FSHARP_AUTOGEN) and
			ProjectSettings.has_setting(SETTINGS_FSHARP_DEFAULT_OUTPUT_DIR) and
			ProjectSettings.has_setting(SETTINGS_FSHARP_DEFAULT_NAMESPACE) and
			dir.dir_exists(ProjectSettings.get_setting(SETTINGS_FSHARP_DEFAULT_OUTPUT_DIR))
			):
			
			return
	
	var top_dir := "res://"
	var dirs: Array = [top_dir]
	var dir := Directory.new()
	var first := true
	var csdata := {}

	# generate 'csdata' map
	while not dirs.empty():
		var dir_name = dirs.back()
		dirs.pop_back()

		if dir.open(dir_name) == OK:
			#warning-ignore:return_value_discarded
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name:
				if first and not dir_name == top_dir:
					first = false
				# Ignore hidden content
				if not file_name.begins_with("."):
					var a_path = dir.get_current_dir() + ("" if first else "/") + file_name
					var a_name = file_name.get_basename()

					# If a directory, then add to list of directories to visit
					if dir.current_is_dir():
						dirs.push_back(dir.get_current_dir().plus_file(file_name))
					# If a file, check if we already have a record for the same name.
					# Only use files with extensions
					elif not csdata.has(a_name) and file_name.ends_with(".cs"):
						csdata[a_name] = a_path

				# Move on to the next file in this directory
				file_name = dir.get_next()

			# We've exhausted all files in this directory. Close the iterator
			dir.list_dir_end()

	dirs = [top_dir]
	dir = Directory.new()
	first = true

	# Remove from 'csdata' entries that already have matching F# scripts
	while not dirs.empty():
		var dir_name = dirs.back() as String
		dirs.pop_back()

		if dir.open(dir_name) == OK:
			#warning-ignore:return_value_discarded
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name:
				if first and not dir_name == top_dir:
					first = false
				# Ignore hidden content
				if not file_name.begins_with("."):
					
					# If a directory, then add to list of directories to visit
					if dir.current_is_dir():
						dirs.push_back(dir.get_current_dir().plus_file(file_name))
					# If a file, check if an F# script
					elif file_name.ends_with(".fs"):
						# If so, remove the F# script's C# class name equivalent from the list of C# scripts.
						var a_csname := file_name.get_basename()
						a_csname = a_csname.substr(0, len(a_csname) - 2) # remove "Fs"
						if csdata.has(a_csname):
							# warning-ignore:return_value_discarded
							csdata.erase(a_csname)

				# Move on to the next file in this directory
				file_name = dir.get_next()

			# We've exhausted all files in this directory. Close the iterator
			dir.list_dir_end()
	
	# scripts that need to be generated
	var f := File.new()
	var find_typenames := RegEx.new()
	# warning-ignore:return_value_discarded
	find_typenames.compile("public class (?P<classname>.+) : (?P<basename>.+)")
	for a_csname in csdata:
		var path = csdata[a_csname]
		var fsname = path.get_file().get_basename() + "Fs"
		var fspath = ProjectSettings.get_setting(SETTINGS_FSHARP_DEFAULT_OUTPUT_DIR)
		if not fspath:
			return
		fspath = fspath.plus_file(fsname + ".fs")
		if dir.file_exists(fspath):
			return
		var csharp_classname := ""
		var basename := ""
		if f.open(fspath, File.WRITE) == OK:
			var csf := File.new()
			if csf.open(path, File.READ) == OK:
				var match_ = find_typenames.search(csf.get_as_text())
				if match_:
					csharp_classname = match_.strings[match_.names.classname] as String
					basename = match_.strings[match_.names.basename] as String
				csf.close()
			
			var namespace = ProjectSettings.get_setting(SETTINGS_FSHARP_DEFAULT_NAMESPACE)
			f.store_string(default_fsharp_file_text % [namespace, fsname, basename])
			f.close()
		
			if csf.open(path, File.WRITE) == OK:
				csf.store_string(default_csharp_file_text % [namespace, csharp_classname, fsname])
				csf.close()

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
	if not ProjectSettings.has_setting(SETTINGS_FSHARP_AUTOGEN):
		ProjectSettings.set_setting(SETTINGS_FSHARP_AUTOGEN, false)
		
	if not ProjectSettings.has_setting(SETTINGS_FSHARP_DEFAULT_OUTPUT_DIR):
		ProjectSettings.set_setting(SETTINGS_FSHARP_DEFAULT_OUTPUT_DIR, "")
	
	if not ProjectSettings.has_setting(SETTINGS_FSHARP_DEFAULT_NAMESPACE):
		ProjectSettings.set_setting(SETTINGS_FSHARP_DEFAULT_NAMESPACE, "")

func _print_and_clear_output(var p_output: Array) -> void:
	for line in p_output:
		print(line)
	p_output.clear()

##### PUBLIC METHODS #####

func get_editor_theme() -> Theme:
	return get_editor_interface().get_base_control().theme

func setup_fsharp_project(p_fspath: String) -> void:
	var res_final_path := p_fspath
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
# warning-ignore:return_value_discarded
	OS.execute("dotnet", PoolStringArray(["add", final_path, "package", "System.Runtime"]), true, output)
	_print_and_clear_output(output)
	
	# Register the F# library to the C# project.
	print("Running `dotnet add %s reference %s`" % [csharp_proj_path, final_path])
	# warning-ignore:return_value_discarded
	OS.execute("dotnet", PoolStringArray(["add", csharp_proj_path, "reference", final_path]), true)
	_print_and_clear_output(output)

func create_fsharp_script_from_csharp(p_fspath: String, p_cspath: String, p_fsclass: String, p_namespace: String) -> void:
	var classname = p_fspath.get_file().get_basename() if not p_fsclass else p_fsclass
	
	var basename := ""
	if true and "Extract C# class name and base type from C# script.":
		var regex := RegEx.new()
		# warning-ignore:return_value_discarded
		regex.compile("public class (?P<classname>.+) : (?P<basename>.+)")
		var f := File.new()
		if f.open(p_cspath, File.READ) == OK:
			var match_ = regex.search(f.get_as_text())
			if match_:
				basename = match_.strings[match_.names.basename] as String
			f.close()
	
	var namespace = p_namespace
	if not namespace:
		var list := p_fspath.get_base_dir().split("/", false)
		namespace = list[list.size() - 1]
	
	if true and "Create F# script.":
		var text = default_fsharp_file_text % [namespace, classname, basename]
		var f := File.new()
		if f.open(p_fspath, File.WRITE) == OK:
			f.store_string(text)
			f.close()
	
	if true and "Update inheritance of C# script.":
		var replace_inheritance := RegEx.new()
		# warning-ignore:return_value_discarded
		replace_inheritance.compile(" : .+\\b")
		
		var include_namespace := RegEx.new()
		# warning-ignore:return_value_discarded
		include_namespace.compile("using System;")
		var f := File.new()
		if f.open(p_cspath, File.READ_WRITE) == OK:
			var text = f.get_as_text()
			text = replace_inheritance.sub(text, " : %s" % classname)
			text = include_namespace.sub(text, (
"""using System;

using %s;"""
			) % namespace)
			f.seek(0)
			f.store_string(text)
			
			
			f.close()
