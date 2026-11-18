@tool
extends EditorPlugin

const ImporterWindow := preload("res://addons/mtl_importer/mtl_importer.gd")
const MENU_NAME := "Material Importer"

var _window: Window


func _enter_tree() -> void:
	add_tool_menu_item(MENU_NAME, _open_window)


func _open_window() -> void:
	_window = ImporterWindow.new()
	EditorInterface.get_base_control().add_child(_window)
	_window.popup_centered(Vector2i(300, 500))


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	if is_instance_valid(_window):
		_window.queue_free()
		_window = null
