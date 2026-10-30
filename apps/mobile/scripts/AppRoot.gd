extends Control

const TEST_SCENE_PATH := "res://poc/test_content/TestScene.tscn"
const TEST_PACK_PATH := "user://test-content.pck"

@onready var status_label: Label = $Center/Status
@onready var load_button: Button = $LoadPck

var loaded_test_scene: Node3D

func _ready() -> void:
	load_button.pressed.connect(_on_load_pck_pressed)

func _on_load_pck_pressed() -> void:
	load_button.disabled = true
	status_label.text = "Loading PCK..."
	var absolute_pack_path := ProjectSettings.globalize_path(TEST_PACK_PATH)
	if not FileAccess.file_exists(TEST_PACK_PATH):
		_show_error("PCK not found at %s" % absolute_pack_path)
		return

	if not ProjectSettings.load_resource_pack(absolute_pack_path, false):
		_show_error("Godot could not load the PCK.")
		return

	var packed_scene := load(TEST_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_show_error("PCK loaded, but test scene was missing or invalid.")
		return

	loaded_test_scene = packed_scene.instantiate() as Node3D
	if loaded_test_scene == null:
		_show_error("Test scene root must be Node3D.")
		return

	add_child(loaded_test_scene)
	loaded_test_scene.position = Vector3(0, 0, 0)
	status_label.text = "PCK loaded. Restart the app after each pack for clean reload tests."
	load_button.text = "PCK Loaded"

func _show_error(message: String) -> void:
	status_label.text = message
	load_button.disabled = false
