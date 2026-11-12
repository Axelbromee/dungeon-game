extends Node
## Autoload "IconBaker". Renders an inventory icon for every InventoryItem from
## its 3D pickup model (world_scene): an off-screen SubViewport with a
## three-quarter camera, soft key/fill/rim lights and a transparent
## background. Results are cached as PNGs in user://icon_cache and reused on
## the next start until the item or its scene changes.
##
## All items in res://items/ are baked at startup, so new items get icons
## automatically. Items with keep_custom_icon keep their own icon. Anything
## else can call IconBaker.request(item).

signal icon_ready(item: InventoryItem)

const ITEMS_DIR := "res://items"
const CACHE_DIR := "user://icon_cache"
const ICON_SIZE := 128
## Bump to throw away every cached icon (e.g. after changing the lighting).
const CACHE_VERSION := 2
const CAMERA_FOV := 30.0
const CAMERA_YAW_DEGREES := 35.0
const CAMERA_PITCH_DEGREES := 28.0
## Extra space around the model (1.0 = touching the edges).
const FRAMING_PADDING := 1.12

var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D
var _queue: Array[InventoryItem] = []
## resource_path -> item. Also keeps every item loaded, so the baked icon
## stays on the shared resource the inventory uses.
var _known: Dictionary = {}
var _busy: bool = false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return  # Nothing renders without a display.
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	_build_studio()
	for path in _find_item_files(ITEMS_DIR):
		var item := load(path) as InventoryItem
		if item:
			request(item)


## Queue an icon for `item` (no-op if it keeps a custom icon or is done).
func request(item: InventoryItem) -> void:
	if item == null or item.keep_custom_icon or item.world_scene == null or _viewport == null:
		return
	var key := _key_for(item)
	if _known.has(key):
		return
	_known[key] = item
	if _load_cached(item):
		return
	_queue.append(item)
	if not _busy:
		_process_queue()


func _process_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		var item: InventoryItem = _queue.pop_front()
		var image := await _render(item)
		if image == null:
			continue
		item.icon = ImageTexture.create_from_image(image)
		image.save_png(_cache_path(item))
		icon_ready.emit(item)
	_busy = false


func _render(item: InventoryItem) -> Image:
	var visual := ItemVisuals.build(item.world_scene)
	if visual == null:
		return null
	_stage.add_child(visual)

	# Frame the model's bounds from a three-quarter angle.
	var bounds := ItemVisuals.local_aabb(visual)
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.01)
	var distance := radius / sin(deg_to_rad(CAMERA_FOV * 0.5)) * FRAMING_PADDING
	var yaw := deg_to_rad(CAMERA_YAW_DEGREES)
	var pitch := deg_to_rad(CAMERA_PITCH_DEGREES)
	var direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	_camera.position = center + direction * distance
	_camera.look_at(center, Vector3.UP)
	_camera.near = maxf(distance - radius * 2.0, 0.005)
	_camera.far = distance + radius * 2.0

	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()

	_stage.remove_child(visual)
	visual.queue_free()
	if image == null or image.is_empty():
		return null
	return image


func _build_studio() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "IconStudio"
	_viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.6, 0.66)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	_add_light(Vector3(-50, 35, 0), Color(1.0, 0.95, 0.88), 1.5)   # Key, warm, above-left.
	_add_light(Vector3(-15, -60, 0), Color(0.75, 0.82, 1.0), 0.5)  # Fill, cool, right.
	_add_light(Vector3(-30, 215, 0), Color(1.0, 1.0, 1.0), 0.7)    # Rim, from behind.

	_stage = Node3D.new()
	_viewport.add_child(_stage)

	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_viewport.add_child(_camera)
	_camera.current = true


func _add_light(rotation_deg: Vector3, color: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = rotation_deg
	light.light_color = color
	light.light_energy = energy
	_viewport.add_child(light)


func _load_cached(item: InventoryItem) -> bool:
	var path := _cache_path(item)
	if not FileAccess.file_exists(path):
		return false
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return false
	item.icon = ImageTexture.create_from_image(image)
	icon_ready.emit.call_deferred(item)
	return true


## Cache file name changes when the item, its scene or CACHE_VERSION changes.
func _cache_path(item: InventoryItem) -> String:
	var scene_path := item.world_scene.resource_path
	var stamp := "%s|%d|%s|%d|%d" % [
		item.resource_path, FileAccess.get_modified_time(item.resource_path),
		scene_path, FileAccess.get_modified_time(scene_path), CACHE_VERSION,
	]
	var base := item.resource_path.get_file().get_basename()
	if base == "":
		base = "item_%d" % item.get_instance_id()
	return "%s/%s_%x.png" % [CACHE_DIR, base, hash(stamp)]


func _key_for(item: InventoryItem) -> String:
	return item.resource_path if item.resource_path != "" else str(item.get_instance_id())


func _find_item_files(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for file in dir.get_files():
		# Exported builds list "x.tres.remap"; load() takes the plain path.
		var clean := file.trim_suffix(".remap")
		if clean.ends_with(".tres") or clean.ends_with(".res"):
			found.append(dir_path.path_join(clean))
	for sub in dir.get_directories():
		found.append_array(_find_item_files(dir_path.path_join(sub)))
	return found
