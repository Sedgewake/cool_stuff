extends Node

## Graphics Settings Manager
## Loads and saves graphics settings from video.cfg file next to executable

var CONFIG_FILE = "video.cfg"

# Default settings
var default_settings = {
	"resolution_width": 1920,
	"resolution_height": 1080,
	"fullscreen_mode": 3,  # 0 = Windowed, 3 = Fullscreen, 4 = Exclusive Fullscreen
	"vsync_mode": 1,  # 0 = Disabled, 1 = Enabled, 2 = Adaptive, 3 = Mailbox
	"msaa_3d": 0,  # 0 = Disabled, 1 = 2x, 2 = 4x, 3 = 8x
	"screen_space_aa": 0,  # 0 = Disabled, 1 = FXAA
	"taa": false,
	"max_fps": 0,  # 0 = Unlimited
	"shadow_quality": 1,  # 0 = Low, 1 = Medium, 2 = High
	"texture_filter": 3,  # 0 = Nearest, 1 = Linear, 2 = Nearest Mipmap, 3 = Linear Mipmap
}

var config = ConfigFile.new()

func _ready():
	# Get the path to the executable directory
	var exe_path = OS.get_executable_path().get_base_dir()
	CONFIG_FILE = exe_path.path_join("video.cfg")
	
	print("Looking for config at: ", CONFIG_FILE)
	load_settings()

func load_settings():
	var err = config.load(CONFIG_FILE)
	
	if err != OK:
		print("video.cfg not found, creating with default settings...")
		create_default_config()
		save_settings()
	else:
		print("video.cfg loaded successfully!")
	
	apply_settings()

func create_default_config():
	for key in default_settings.keys():
		config.set_value("Graphics", key, default_settings[key])

func apply_settings():
	var window = get_window()
	
	# Fullscreen mode (apply BEFORE resolution)
	var fullscreen = config.get_value("Graphics", "fullscreen_mode", default_settings.fullscreen_mode)
	if Engine.is_editor_hint():
		window.mode = 0
	else:
		window.mode = fullscreen
	print("Fullscreen mode set to: ", fullscreen)
	
	# Resolution
	var width = config.get_value("Graphics", "resolution_width", default_settings.resolution_width)
	var height = config.get_value("Graphics", "resolution_height", default_settings.resolution_height)
	
	if fullscreen == Window.MODE_WINDOWED or fullscreen == Window.MODE_MAXIMIZED:
		# For windowed mode, set size and center
		window.size = Vector2i(width, height)
		window.borderless = false
		window.unresizable = false
		# Center the window
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - window.size) / 2
		window.position = window_pos
	else:
		window.size = Vector2i(DisplayServer.screen_get_size())
		var vp := get_tree().root
		vp.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		vp.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		vp.set_content_scale_size(Vector2i(width, height))
	

	
	# VSync
	var vsync = config.get_value("Graphics", "vsync_mode", default_settings.vsync_mode)
	DisplayServer.window_set_vsync_mode(vsync)
	print("VSync mode set to: ", vsync)
	
	# MSAA 3D
	var msaa = config.get_value("Graphics", "msaa_3d", default_settings.msaa_3d)
	get_viewport().msaa_3d = msaa
	
	# Screen Space AA
	var ssaa = config.get_value("Graphics", "screen_space_aa", default_settings.screen_space_aa)
	get_viewport().screen_space_aa = ssaa
	
	# TAA
	var taa = config.get_value("Graphics", "taa", default_settings.taa)
	get_viewport().use_taa = taa
	
	# Max FPS
	var max_fps = config.get_value("Graphics", "max_fps", default_settings.max_fps)
	Engine.max_fps = max_fps
	
	# Shadow quality
	var shadow_quality = config.get_value("Graphics", "shadow_quality", default_settings.shadow_quality)
	apply_shadow_quality(shadow_quality)
	
	# Texture filter
	var tex_filter = config.get_value("Graphics", "texture_filter", default_settings.texture_filter)
	apply_texture_filter(tex_filter)
	
	print("Graphics settings loaded and applied successfully!")

func apply_shadow_quality(quality: int):
	# This adjusts directional shadow quality
	match quality:
		0:  # Low
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		1:  # Medium
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		2:  # High
			RenderingServer.directional_shadow_atlas_set_size(8192, true)

func apply_texture_filter(filter: int):
	# Apply to viewport canvas items
	get_viewport().canvas_item_default_texture_filter = filter as Viewport.DefaultCanvasItemTextureFilter

func save_settings():
	var err = config.save(CONFIG_FILE)
	if err == OK:
		print("Settings saved successfully to video.cfg")
	else:
		print("Error saving settings: ", err)

func update_setting(key: String, value):
	config.set_value("Graphics", key, value)
	save_settings()
	apply_settings()

func get_setting(key: String):
	return config.get_value("Graphics", key, default_settings.get(key))
