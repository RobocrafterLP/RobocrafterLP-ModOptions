# RobocrafterLP-ModOptions

RobocrafterLP-ModOptions is a shared settings framework for Brotato mods. It
adds a **Mods** tab to the settings menu and builds controls from each mod's
`extra.godot.config_schema` manifest data.

## Features

- A sidebar listing mods that provide configuration schemas.
- Generated controls for toggles, sliders, dropdowns, text, colors, and arrays.
- Nested object sections for grouping related settings.
- Brotato's native color picker and slider components where available.
- A small API for reading and updating a mod's settings from code.
- Focused generated screens for custom mod menus.
- Independent JSON files for extra settings groups.

## Installation

Install **Brotato ModLoader** and place `RobocrafterLP-ModOptions` in the
ModLoader's `mods-unpacked` directory. Enable it in the mod loader, then open
the game's settings menu and select **Mods**.

The manifest currently declares compatibility with Brotato `1.2.0.0` and
ModLoader `6.2.0`. Check the manifest when using a different game or loader
version.

## Manifest settings

Add a schema under `extra.godot.config_schema` in your mod's manifest:

```json
{
  "title": "My Mod Settings",
  "description": "Options for My Mod.",
  "type": "object",
  "properties": {
    "enabled": {
      "type": "boolean",
      "title": "Enabled",
      "default": true
    },
    "strength": {
      "type": "number",
      "title": "Strength",
      "minimum": 0,
      "maximum": 2,
      "multipleOf": 0.1,
      "default": 1
    },
    "mode": {
      "type": "string",
      "title": "Mode",
      "enum": ["safe", "balanced", "fast"],
      "enumNames": ["Safe", "Balanced", "Fast"],
      "default": "balanced"
    },
    "accent": {
      "type": "string",
      "format": "color",
      "title": "Accent color",
      "default": "76ff76"
    }
  }
}
```

Supported controls:

| Schema | Control |
| --- | --- |
| `boolean` | Toggle |
| `integer` or `number` | Slider (`minimum`, `maximum`, `multipleOf`) |
| Any supported type with `enum` | Dropdown |
| `string` with `format: color` | Brotato color picker |
| `string` | Text field (`multiline: true` for a text area) |
| `array` | JSON text area |
| `object` | Nested settings section |

Use `title`, `description`, and `default` to label controls, explain settings,
and define initial values.

## Mod API

The manager is available at
`/root/ModLoader/RobocrafterLP-ModOptions/ModOptions`. Manifest schemas are
registered automatically. Mods can retrieve their registration handle to read
and react to changes:

```gdscript
const MOD_ID := "YourName-YourMod"
var mod_settings

func _ready() -> void:
    call_deferred("_register_settings")

func _register_settings() -> void:
    var manager = get_node_or_null("/root/ModLoader/RobocrafterLP-ModOptions/ModOptions")
    if manager == null:
        return
    var mod_data = ModLoaderMod.get_mod_data(MOD_ID)
    if mod_data == null:
        return
    mod_settings = manager.register_mod_options(MOD_ID, mod_data.manifest.config_schema)
    mod_settings.connect("value_changed", self, "_on_setting_changed")
    var enabled = mod_settings.get_value("enabled")
    mod_settings.set_value("enabled", enabled)

func _on_setting_changed(config_path: String, value) -> void:
    if config_path == "enabled":
        pass # Apply the updated value to your mod.
```

The returned handle scopes calls to your mod, so use `get_value("enabled")`
and `set_value("enabled", true)`. Nested paths use dot notation, such as
`get_value("advanced.enabled")`.

### Custom config screens

Create a generated screen and parent it to a custom menu or window:

```gdscript
var screen = mod_settings.create_config_screen()
screen.parent_to(your_menu)
```

For runtime-generated options, register a schema with additional properties.
The manager merges new properties into the mod's schema. Pass a focused schema
to `create_config_screen(null, runtime_schema)` to show only that group.

### Separate settings files

Use `add_extra_config()` for a settings group that should be saved separately
from the main manifest configuration:

```gdscript
var level_settings = mod_settings.add_extra_config("level_options", {
    "title": "Level options",
    "type": "object",
    "properties": {
        "preferred_stat": {
            "type": "string",
            "enum": ["damage", "speed", "armor"],
            "default": "damage"
        }
    }
})

level_settings.set_value("preferred_stat", "speed")
var selected_stat = level_settings.get_value("preferred_stat")
```

The extra-config handle also has `get_values()`, `get_schema()`,
`has_saved_value()`, and `create_config_screen()`. A config named
`level_options` is stored at:

```text
Brotato/modsettings/YourName-YourMod/level_options.json
```

The main manifest settings are stored in `_main.json` in the same folder.
Extra-config names must be plain filenames without dots or path separators.

## Sample settings

This mod includes example toggle, slider, dropdown, text, color, and nested
settings in its own manifest schema. Open the **Mods** tab to see the sample
controls.

## Project notes

- Mod ID: `RobocrafterLP-ModOptions`
- Version: `1.0.0`
- Author: RobocrafterLP
- License: not specified yet
