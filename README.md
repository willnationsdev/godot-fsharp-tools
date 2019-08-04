# Godot F# Tools

A Godot Engine plugin to simplify using F# through the C# Mono language.

## Features

- Generating an F# project file and adding it to your Godot C# project/solution
    - via Tools menu shortcut.
- Generating an F# script from a selected C# script.
    - via Tools menu shortcut.
- Automatically Generating F# scripts from all C# scripts.
    - via configuration in ProjectSettings under Mono > F# Tools
    - Note: All F# classes must have the same name as their C# counterpart with an "Fs" on the end, e.g. `MyClass.cs -> MyClassFs.fs`.

## How to install

1. Download the .zip from GitHub or clone the repository.
2. Copy/paste the `addons` directory into your project or create a symlink between the `addons/godot-fsharp-tools` directory and a similar one in your project.
3. Open the ProjectSettings, go to the Plugins tab, find "Godot F# Tools" and switch it from "Inactive" to "Active" on the right-hand side.
4. Make sure that you've installed Mono and the [dotnet](https://docs.microsoft.com/en-us/dotnet/core/tools/?tabs=netcore2x) command line tool of which this plugin makes heavy use.

## How to use

These instructions assume that you...

1. Have already created a C# project/solution by first creating at least one C# script in your Godot project.
1. Have installed and activated the plugin.

### Generate F# Project

1. Go to `Project > Tools > Setup F# project...`. A dialog will open.
1. Fill in the necessary fields. Unnecessary fields will tell you what default value they become if left empty.
1. Once confirmed, the dialog will generate the F# project and connect it to your C# project/solution for you. This may take a short while.

### Generate single F# script from a C# script

1. Go to `Project > Tools > Generate F# script from C# script...`. A dialog will open.
1. Fill in the necessary fields. Unnecessary fields will tell you what default value they become if left empty.
    - The namespace must match that of the F# library project to which you plan to add it.
1. Once confirmed, the dialog will generate the F# script and update the C# script to inherit from your F# class and include its namespace.
1. You will need to add the new F# script file to your F# library project manually.\*

### Generate F# scripts from all created C# scripts

1. Go to `Project > ProjectSettings`. Go to the `General` tab. Scroll all the way to the bottom and find the `Mono > F# Tools` category.
1. Fill in information for all fields in this section.
    - The namespace must match that of the F# library project to which you plan to add it.
    - For better organization, we recommend using the F# library project directory for the output directory.
1. Create a C# script. The editor will generate a corresponding F# script in the output directory and update the C# script to inherit from your F# class and include its namespace.
1. You will need to add the new F# script file to your F# library project manually.\*

---

\* The reason you must do this manually is because...

1. the `dotnet` tool from Microsoft does not support adding items to projects ("Really? Seriously? Professional stuff here guys").
1. Godot's `XmlParser` class only allows you to read XML nodes, but not insert them into an .xml file ("Really? I mean, that could be useful guys...").
1. If you want to write your own XML parsing code to inject the file reference into the `<ItemGroup>` tag hierarchy, it would be appreciated.

For the uninformed, you add an existing item to an F# project in the following way:

1. Have Visual Studio installed with F# support.
1. Open the Godot .sln file in Visual Studio.
1. Right click on the F# library project in the Solution Explorer dock.
1. Go to `Add > Add Existing Item...`.
1. Choose the `<classname>Fs.fs` file you generated. Hit "OK".

OR

1. Have Visual Studio Code installed with the `Ionide-fsharp` extension.
1. Open the Godot directory in your workspace. Ionide's F# solution tab should
automatically detect and add the F# project.
1. In the F# tab on the left, you should see your project's .sln and under it the .csproj / .fsproj directories.
1. Right-click the F# project directory. Choose `Add file`.
1. Within the command pallete line edit, type out the name of the F# source file in that directory you want to add. Hit `Enter`.

The F# source file is now added to the F# project!

---

# Known Issues

ProjectSettings.add_property_info triggers an error the first time the settings are defined. It's supposed to check if the name of the custom property you are making already exists and then give you a warning if it does. Instead, it issues a warning when it DOESN'T exist.

As such, the first time you try to set up F# script auto-generation, you will see 3 errors about an invalid `pinfo.name` or something. Just ignore it. I've already submitted a PR to fix it, but it won't be there until 3.2 at the earliest.

---

If you like the project, please give it a star and consider donating to my [Kofi](https://ko-fi.com/willnationsdev). If you have any problems whatsoever, do not hesitate to open an Issue.