@tool
extends Window

var preview_image: Texture2D = null
var mtl_select : OptionButton = null
var type_select : OptionButton = null
var name_entry : LineEdit = null
var preview_rect : TextureRect = null
var file_dialog: FileDialog = null
var input_file_path = null
var map_content_folder = null
var textures_folder = null
var materials_folder = null
var tex_subfolders = null

func _init() -> void:
	title = "Material Importer"
	visible = false
	exclusive = false
	min_size = Vector2i(300, 500)
	close_requested.connect(queue_free)
	_build_ui()

func _build_ui() -> void:
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	bg.add_child(vbox)
	
	mtl_select = OptionButton.new()
	vbox.add_child(mtl_select)
	mtl_select.item_selected.connect(p1)
	type_select = OptionButton.new()
	vbox.add_child(type_select)
	type_select.add_item("", 0)
	type_select.add_item("wall", 1)
	type_select.add_item("floor", 2)
	type_select.add_item("ceiling", 3)
	type_select.item_selected.connect(p1)
	name_entry = LineEdit.new()
	vbox.add_child(name_entry)
	preview_rect = TextureRect.new()
	preview_rect.custom_minimum_size = Vector2(0, 200)
	preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(preview_rect)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)
	var load_button := Button.new()
	load_button.text = "Load"
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.pressed.connect(_on_load_pressed)
	hbox.add_child(load_button)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(_on_save_pressed)
	hbox.add_child(save_button)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.svg ; Supported Images"])
	file_dialog.title = "Select Image"
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	get_directories()
	var i1 = 0
	for sd in tex_subfolders:
		mtl_select.add_item(sd, i1)
		i1+=1
	
func get_directories():
	map_content_folder = find_directory_in_res("MapContent")
	if map_content_folder.is_empty():
		printerr("\"MapContent\" folder not found.")
		return
	textures_folder = map_content_folder+"/Textures"
	materials_folder = map_content_folder+"/Materials"
	var base_dir = DirAccess.open(map_content_folder)
	if not base_dir.dir_exists(textures_folder): base_dir.make_dir(textures_folder)
	if not base_dir.dir_exists(materials_folder): base_dir.make_dir(materials_folder)
	tex_subfolders = DirAccess.get_directories_at(textures_folder)
	if tex_subfolders.size() == 0:
		print("No subdirs in: ", textures_folder)
	EditorInterface.get_resource_filesystem().scan()

func find_directory_in_res(dir_name: String, current_path: String = "res://") -> String:
	var dirs = DirAccess.get_directories_at(current_path)
	for d in dirs:
		var full_path = current_path.path_join(d)
		if d == dir_name:
			return full_path
		var result = find_directory_in_res(dir_name, full_path)
		if result != "":
			return result
	return ""

func _on_load_pressed() -> void:
	file_dialog.popup_centered_ratio(0.5)

func _on_file_selected(path: String) -> void:
	input_file_path = path
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("Failed to load image: %s (error %d)" % [path, err])
		input_file_path = null
		return
	preview_image = ImageTexture.create_from_image(img)
	preview_rect.texture = preview_image
	
	var mtl_hint = get_mtl_from_name(input_file_path.get_file())
	if not mtl_hint.is_empty():
		var i2 = 0
		for sd in tex_subfolders:
			if mtl_hint == sd.get_file():
				mtl_select.select(i2)
				break
			i2 += 1
	set_mtl_name()

func _on_save_pressed() -> void:
	if not input_file_path: return
	var base_dir = DirAccess.open(map_content_folder)
	var mtl = mtl_select.get_item_text(mtl_select.selected)
	var tx_subfolder = textures_folder + "/" + mtl
	var mtl_subfolder = materials_folder + "/" + mtl
	if not base_dir.dir_exists(mtl_subfolder): base_dir.make_dir(mtl_subfolder)
	var mtl_name = name_entry.get_text()
	var output_texture_path = tx_subfolder + "/" + mtl_name +  "_d." + input_file_path.get_extension()
	var output_material_path = mtl_subfolder +"/" + mtl_name + ".tres"
	if base_dir.file_exists(output_material_path) or base_dir.file_exists(output_texture_path):
		output_texture_path = tx_subfolder + "/" + mtl_name +  "2_d." + input_file_path.get_extension() # HACK
		output_material_path = mtl_subfolder +"/" + mtl_name + "2.tres"
	DirAccess.copy_absolute(input_file_path, output_texture_path)
	EditorInterface.get_resource_filesystem().scan()
	await get_tree().create_timer(2.0).timeout
	var texture = load(output_texture_path)
	var material = StandardMaterial3D.new()
	material.albedo_texture = texture
	var err = ResourceSaver.save(material, output_material_path)
	if err == OK:
		print("Material created successfully: " + output_material_path)
		EditorInterface.get_resource_filesystem().scan()
	else:
		push_error("Failed to save material: " + str(err))
	
func p1(index: int):
	set_mtl_name()
	
func get_mtl_from_name(tex_name : String) -> String:
	name = tex_name.to_lower()
	if name.contains("brick"):
		return "brick"
	if name.contains("stone"):
		return "stone"
	if name.contains("metal"):
		return "metal"
	return ""
	
func set_mtl_name():
	var mtl = mtl_select.get_item_text(mtl_select.selected)
	var tx_subfolder = textures_folder + "/" + mtl
	var files = DirAccess.get_files_at(tx_subfolder)
	var tex_count = files.size() / 2
	var number = "%03d" % (tex_count + 1)
	var type = type_select.get_item_text(type_select.selected)
	name_entry.set_text(mtl+type+number)
	
