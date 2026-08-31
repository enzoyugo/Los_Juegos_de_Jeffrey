class_name AuthoredPngStage
extends "res://scripts/stages/jeffrey_smash_stage_base.gd"

@export var background_path: String = ""
@export var platform_paths: Array[String] = []

func _build_silhouette_props(camera: Camera3D) -> void:
	var root := Node3D.new()
	root.name = "AuthoredStageArtwork"
	root.add_to_group("jeffrey_stage_silhouette")
	camera.add_child(root)
	var background := _sprite(background_path, Vector3(0.0, 9.0, -88.0), 0.055)
	if background != null:
		root.add_child(background)
	var positions := [Vector3(0.0, 0.9, -22.0), Vector3(-7.0, 3.3, -21.5), Vector3(7.0, 3.3, -21.5)]
	for i in mini(platform_paths.size(), positions.size()):
		var platform_scale := 0.009 if i == 0 else 0.004
		var platform := _sprite(platform_paths[i], positions[i], platform_scale)
		if platform != null:
			root.add_child(platform)

func _sprite(path: String, pos: Vector3, pixel_size: float) -> Sprite3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var sprite := Sprite3D.new()
	sprite.texture = load(path)
	sprite.position = pos
	sprite.pixel_size = pixel_size
	sprite.no_depth_test = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite
