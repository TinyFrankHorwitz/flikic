# Godot Android client

Pinned editor/runtime target: **Godot 4.5.2-stable**, standard (GDScript) build. The project uses the Compatibility renderer for broad Android device coverage. Android export templates must match the installed 4.5.2 editor exactly.

## Open and run

Open `apps/mobile/project.godot` in Godot 4.5.2. The persistent `AppRoot.tscn` stays loaded and has a basic local PCK loading control. Android export presets and the LAN API URL will be added after the runtime PCK feasibility gate.

## Runtime PCK proof of concept

The pack source is `apps/mobile/poc-pack`. It contains a Node3D scene, GDScript, and a mesh. In Godot 4.5.2, open that project and use **Project > Export > Export PCK/ZIP** with an export preset selected, writing `test-content.pck`. Copy the PCK into the app's writable user-data directory (`user://test-content.pck`), install/run the Android app, and tap **Load PCK**.

The root calls the Godot 4.5 API `ProjectSettings.load_resource_pack(path, false)`, then loads and instantiates the scene by its resource path. The runtime API is documented in the [Godot 4.5 pack export guide](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_pcks.html) and [ProjectSettings reference](https://docs.godotengine.org/en/4.5/classes/class_projectsettings.html).

## Device verification status

**Not yet verified.** Godot is not installed in the current environment, and no Android device/export setup is available here. Do not treat runtime PCK loading on Android, writable-path access, imported resource behavior, pack unloading/reloading, or post-restart cache loading as passed. Phase 2 must stop here until tested on a physical Android device. Record device/OS, exact Godot build, export template, pack path, results, and limitations before implementing remote game streaming.

The current proof scene only loads and instantiates one PCK. It does not unload packs (Godot's runtime pack API has no matching unload operation); version/path collision behavior still needs a device experiment. Use unique package resource paths and restart-based isolation in the initial feasibility tests. Do not claim arbitrary loaded GDScript is sandboxed.
