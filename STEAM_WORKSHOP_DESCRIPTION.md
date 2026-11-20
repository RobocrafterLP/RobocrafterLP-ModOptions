# Steam Workshop description

Copy the text below into the Steam Workshop description field.

---

[h1]RobocrafterLP-ModOptions[/h1]

A shared settings framework for Brotato mods. It adds a [b]Mods[/b] tab with a
sidebar and automatically builds settings screens from each mod's
configuration schema.

[h2]Features[/h2]
[list]
[*]Toggle, slider, dropdown, text, color, and array controls.
[*]Nested sections to keep larger settings screens organized.
[*]Brotato's native color picker and slider controls where available.
[*]A simple API for mods to read and update their settings.
[*]Custom config screens that can be embedded in a mod's own menus.
[*]Separate JSON files for independent settings groups.
[/list]

[h2]For Mod Developers[/h2]
Add a [code]config_schema[/code] to your mod manifest to get a settings screen
automatically. Use the registration API to read values in code, listen for
changes, or create focused screens for runtime-generated settings.

Independent settings groups can be registered with
[code]add_extra_config("group_name", schema)[/code]. These are stored as
separate JSON files in the mod's folder under Brotato's [code]modsettings[/code]
directory.

[h2]Installation[/h2]
Requires Brotato ModLoader. Install and enable this mod through your usual
ModLoader workflow, then open the game's settings and select [b]Mods[/b].

[h2]Compatibility[/h2]
The included manifest lists Brotato 1.2.0.0 and ModLoader 6.2.0 as compatible.
Check the mod files for updated compatibility information.

[h2]Sample[/h2]
This mod includes example toggle, slider, dropdown, text, color, and nested
settings so you can preview the available controls in the Mods tab.

---

Source code and developer documentation: see the GitHub repository for
RobocrafterLP-ModOptions.
