class_name DefensoresDelChacoStage
extends Node3D

const PLATFORM_TEXTURE := preload("res://assets/stages/defensores_del_chaco/platforms/defensores_platform_kit.png")
const FX_OVERLAY_PATH := "res://assets/stages/defensores_del_chaco/fx/stadium_light_confetti_overlay.png"
const CAMERA_BACKGROUND := preload("res://scripts/stages/stadium_camera_background.gd")
## Event-only art remains on disk and is not preloaded for normal battle:
## defensores_bg_main.png is owned by stadium_camera_background.gd (one hero BG).
## crowd_strips.png crowd_loop_variants.png mosaic_variants.png tifo_atlas.png
## scoreboard_sheet.png foreground_overlay.png stadium_light_confetti_overlay.png
const UI_LAYERS := preload("res://scripts/ui/kapes_layers.gd")

var fx_overlay: TextureRect
var event_fx_tween: Tween

func _ready() -> void:
	_audit_log("Defensores stage ready")
	_hide_greybox_visuals()
	_build_art_layers()
	_audit_log("composition ready: hero background + platform art + event fx only")

func show_ko() -> void:
	_pulse_event_fx(0.22, 0.65, "ko presentation")


func show_final_ko() -> void:
	_pulse_event_fx(0.42, 1.05, "final ko presentation")


func _pulse_event_fx(peak_alpha: float, fade_seconds: float, audit_message: String) -> void:
	_audit_log(audit_message)
	_ensure_event_fx_layer()
	if event_fx_tween != null:
		event_fx_tween.kill()
	if fx_overlay == null:
		return
	fx_overlay.visible = true
	fx_overlay.modulate.a = peak_alpha
	event_fx_tween = create_tween()
	event_fx_tween.tween_property(fx_overlay, "modulate:a", 0.0, fade_seconds)
	event_fx_tween.tween_callback(func():
		fx_overlay.visible = false
	)

func set_scoreboard_state(_state: String) -> void:
	# V3 uses the scoreboard baked into the hero background.
	pass

func show_mosaic(_id: int = 0) -> void:
	# Future event hook. Normal gameplay remains clean.
	_audit_log("show_mosaic deferred id=%d" % _id)

func hide_mosaic() -> void:
	_audit_log("hide_mosaic deferred")

func cycle_match_intro_mosaic() -> void:
	_audit_log("cycle_match_intro_mosaic deferred")

func _hide_greybox_visuals() -> void:
	var gameplay_root := get_node_or_null("StageGameplayRoot")
	if gameplay_root != null:
		_hide_meshes_recursive(gameplay_root)

func _hide_meshes_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
		_hide_meshes_recursive(child)

func _build_art_layers() -> void:
	if OS.get_environment("SSK_DISABLE_STAGE_VISUALS") == "1":
		print("[FREEZE_AUDIT] stage visuals disabled by SSK_DISABLE_STAGE_VISUALS")
		return
	_attach_camera_background()
	_build_platform_art()

func _attach_camera_background() -> void:
	var playground := get_parent()
	if playground == null:
		return
	var camera := playground.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	if camera.get_node_or_null("StadiumBackgroundQuad") != null:
		return
	var background = CAMERA_BACKGROUND.new()
	camera.add_child(background)

func _build_platform_art() -> void:
	var platform_art := $ArtRoot.get_node("PlatformArtLayer")
	_add_sprite(
		platform_art,
		PLATFORM_TEXTURE,
		Vector3(0.0, 0.08, 0.72),
		0.0185,
		Color(0.12, 0.16, 0.22, 0.92),
		Rect2(0, 500, 1672, 120)
	)
	_add_sprite(
		platform_art,
		PLATFORM_TEXTURE,
		Vector3(0.0, 0.22, 0.85),
		0.0185,
		Color.WHITE,
		Rect2(0, 200, 1672, 300)
	)
	_add_sprite(
		platform_art,
		PLATFORM_TEXTURE,
		Vector3(0.0, 0.30, 0.86),
		0.0185,
		Color(0.95, 0.88, 0.55, 0.42),
		Rect2(0, 150, 1672, 60)
	)
	_add_sprite(
		platform_art,
		PLATFORM_TEXTURE,
		Vector3(-7.0, 3.12, 0.85),
		0.0092,
		Color(1.0, 1.0, 1.0, 0.96),
		Rect2(900, 570, 770, 170)
	)
	_add_sprite(
		platform_art,
		PLATFORM_TEXTURE,
		Vector3(7.0, 3.12, 0.85),
		0.0092,
		Color(1.0, 1.0, 1.0, 0.96),
		Rect2(900, 570, 770, 170),
		true
	)
	_add_sprite(
		platform_art,
		PLATFORM_TEXTURE,
		Vector3(-7.0, 2.95, 0.78),
		0.0092,
		Color(0.14, 0.18, 0.24, 0.88),
		Rect2(900, 740, 770, 90)
	)
	_add_sprite(
		platform_art,
		PLATFORM_TEXTURE,
		Vector3(7.0, 2.95, 0.78),
		0.0092,
		Color(0.14, 0.18, 0.24, 0.88),
		Rect2(900, 740, 770, 90),
		true
	)

func _ensure_event_fx_layer() -> void:
	if fx_overlay != null:
		return
	_build_event_fx_layer()


func _build_event_fx_layer() -> void:
	var overlay_texture := load(FX_OVERLAY_PATH) as Texture2D
	if overlay_texture == null:
		return
	var fx_canvas := CanvasLayer.new()
	fx_canvas.name = "ScreenSpaceEventFX"
	fx_canvas.layer = UI_LAYERS.FOREGROUND
	add_child(fx_canvas)
	fx_overlay = _screen_image(
		fx_canvas,
		_atlas(overlay_texture, Rect2(0, 0, 2172, 724)),
		Rect2(0, 0, 1920, 540),
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	fx_overlay.modulate.a = 0.0
	fx_overlay.visible = false

func _screen_image(parent: Node, texture: Texture2D, rect: Rect2, stretch_mode: int) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.position = rect.position
	image.size = rect.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = stretch_mode
	image.focus_mode = Control.FOCUS_NONE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas

func _audit_log(message: String) -> void:
	if OS.get_environment("SSK_FREEZE_AUDIT") == "1":
		print("[FREEZE_AUDIT] %s" % message)

func _add_sprite(parent: Node3D, texture: Texture2D, position: Vector3, pixel_size: float, tint: Color, region: Rect2 = Rect2(), flip_h: bool = false) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = pixel_size
	sprite.position = position
	sprite.modulate = tint
	sprite.shaded = false
	sprite.flip_h = flip_h
	sprite.render_priority = 1
	if region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = region
	parent.add_child(sprite)
	return sprite
