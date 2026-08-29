class_name KapesPortrait
extends RefCounted

static var _cache: Dictionary = {}

static func get_hud_portrait(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var key: String = source.resource_path
	if key.is_empty():
		key = str(source.get_instance_id())
	if _cache.has(key):
		return _cache[key]
	var processed := _build_hud_portrait(source)
	_cache[key] = processed
	return processed

static func get_hero_portrait(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var key: String = "hero:%s" % (source.resource_path if not source.resource_path.is_empty() else str(source.get_instance_id()))
	if _cache.has(key):
		return _cache[key]
	var processed := _build_hero_portrait(source)
	_cache[key] = processed
	return processed

static func _build_hud_portrait(source: Texture2D) -> Texture2D:
	var image := _source_image(source)
	if image == null:
		return source
	_remove_near_white_background(image)
	_crop_to_content(image)
	var texture := ImageTexture.create_from_image(image)
	return texture

static func _build_hero_portrait(source: Texture2D) -> Texture2D:
	var image := _source_image(source)
	if image == null:
		return source
	_remove_near_white_background(image)
	var texture := ImageTexture.create_from_image(image)
	return texture

static func _source_image(source: Texture2D) -> Image:
	if source is ImageTexture:
		var image_texture := source as ImageTexture
		return image_texture.get_image()
	return source.get_image()

static func _remove_near_white_background(image: Image) -> void:
	if image.is_empty():
		return
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.05:
				continue
			if color.r > 0.92 and color.g > 0.92 and color.b > 0.92:
				color.a = 0.0
				image.set_pixel(x, y, color)

static func _crop_to_content(image: Image) -> void:
	if image.is_empty():
		return
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	var pad := 4
	var crop := Rect2i(
		maxi(used.position.x - pad, 0),
		maxi(used.position.y - pad, 0),
		mini(used.size.x + pad * 2, image.get_width() - maxi(used.position.x - pad, 0)),
		mini(used.size.y + pad * 2, image.get_height() - maxi(used.position.y - pad, 0))
	)
	var cropped := image.get_region(crop)
	image.copy_from(cropped)
