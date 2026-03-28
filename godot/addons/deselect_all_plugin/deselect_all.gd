@tool
extends EditorPlugin

var shortcut: Shortcut

func _enter_tree():
	# Create the shortcut (Shift+Q)
	shortcut = Shortcut.new()
	var input_event = InputEventKey.new()
	input_event.keycode = KEY_Q
	input_event.shift_pressed = true
	shortcut.events = [input_event]

func _exit_tree():
	shortcut = null

func _input(event: InputEvent):
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_Q and event.shift_pressed and not event.ctrl_pressed and not event.alt_pressed:
			# Deselect everything in the scene
			var editor_selection = get_editor_interface().get_selection()
			editor_selection.clear()
			get_viewport().set_input_as_handled()
