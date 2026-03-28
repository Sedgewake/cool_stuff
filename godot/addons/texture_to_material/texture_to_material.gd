@tool
extends EditorPlugin

const SHADER_PATH = "res://Shaders/model_main.gdshader"
const TEXTURES_FOLDER = "Textures"
const MATERIALS_FOLDER = "Materials"

var inspector_plugin: EditorInspectorPlugin

func _enter_tree():
	inspector_plugin = ContextMenuPlugin.new()
	add_inspector_plugin(inspector_plugin)

func _exit_tree():
	remove_inspector_plugin(inspector_plugin)

class ContextMenuPlugin extends EditorInspectorPlugin:
	
	func _can_handle(object):
		return object is Texture2D
	
	func _parse_begin(object):
		if object is Texture2D:
			var button = Button.new()
			button.text = "Create Material from Texture"
			button.pressed.connect(_on_create_material.bind(object))
			add_custom_control(button)
	
	func _on_create_material(texture: Texture2D):
		var texture_path = texture.resource_path
		
		if texture_path.is_empty():
			push_error("Texture has no resource path")
			return
		
		# Get texture filename without extension
		var texture_name = texture_path.get_file().get_basename()
		
		# Find the subfolder (Brick, Metal, etc.)
		var path_parts = texture_path.split("/")
		var subfolder = ""
		
		for i in range(path_parts.size()):
			if path_parts[i] == TEXTURES_FOLDER and i + 1 < path_parts.size():
				subfolder = path_parts[i + 1]
				break
		
		if subfolder.is_empty():
			push_error("Could not determine texture subfolder")
			return
		
		# Construct materials path
		var base_path = texture_path.substr(0, texture_path.find(TEXTURES_FOLDER))
		var materials_path = base_path + MATERIALS_FOLDER + "/" + subfolder
		
		# Create directory if it doesn't exist
		var dir = DirAccess.open(base_path + MATERIALS_FOLDER)
		if dir == null:
			dir = DirAccess.open(base_path)
			if dir:
				dir.make_dir(MATERIALS_FOLDER)
		
		dir = DirAccess.open(base_path + MATERIALS_FOLDER)
		if dir and not dir.dir_exists(subfolder):
			dir.make_dir(subfolder)
		
		# Load shader
		var shader = load(SHADER_PATH)
		if shader == null:
			push_error("Could not load shader: " + SHADER_PATH)
			return
		
		# Create material
		var material = ShaderMaterial.new()
		material.shader = shader
		
		# Set texture parameter
		material.set_shader_parameter("_MainTex", texture)
		
		# Save material
		var material_name = texture_name + "_mtl.tres"
		var material_path = materials_path + "/" + material_name
		
		var err = ResourceSaver.save(material, material_path)
		if err == OK:
			print("Material created successfully: " + material_path)
			EditorInterface.get_resource_filesystem().scan()
		else:
			push_error("Failed to save material: " + str(err))
