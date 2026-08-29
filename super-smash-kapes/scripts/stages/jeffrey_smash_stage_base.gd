class_name JeffreySmashStageBase
extends Node3D

## Shared Smash stage presentation: sky backdrop + optional Blender visual GLB + KO pulse.

const UI_LAYERS := preload("res://scripts/ui/kapes_layers.gd")

@export var stage_id: String = ""
@export var display_name: String = ""
@export var sky_top: Color = Color("#1a2740")
@export var sky_bottom: Color = Color("#6a8ab0")
@export var accent: Color = Color("#c62828")
@export var visual_glb_path: String = ""

var fx_overlay: ColorRect
var event_fx_tween: Tween
var _bg: MeshInstance3D
var _light_sweep: float = 0.0
var _visual_glb_root: Node3D
var _ko_burst: ColorRect


func _ready() -> void:
	_build_platform_colors()
	_attach_procedural_background()
	_try_attach_visual_glb()
	set_process(true)


func _process(delta: float) -> void:
	_light_sweep += delta
	if _bg != null and _bg.material_override is ShaderMaterial:
		pass
	elif _bg != null and _bg.material_override is StandardMaterial3D:
		var mat := _bg.material_override as StandardMaterial3D
		var pulse := 0.92 + sin(_light_sweep * 0.7) * 0.04
		mat.albedo_color = Color(sky_top.r * pulse, sky_top.g * pulse, sky_top.b * pulse, 1.0)


func show_ko() -> void:
	_pulse_event_fx(0.28, 0.55)
	_pulse_ko_burst(0.55)


func show_final_ko() -> void:
	_pulse_event_fx(0.48, 1.0)
	_pulse_ko_burst(0.9)


func get_stage_display_name() -> String:
	return display_name


func _pulse_event_fx(peak_alpha: float, fade_seconds: float) -> void:
	_ensure_event_fx_layer()
	if event_fx_tween != null:
		event_fx_tween.kill()
	if fx_overlay == null:
		return
	fx_overlay.visible = true
	fx_overlay.color = Color(accent.r, accent.g, accent.b, peak_alpha)
	event_fx_tween = create_tween()
	event_fx_tween.tween_property(fx_overlay, "color:a", 0.0, fade_seconds)
	event_fx_tween.tween_callback(func():
		fx_overlay.visible = false
	)


func _ensure_event_fx_layer() -> void:
	if fx_overlay != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = UI_LAYERS.MATCH_INTRO if UI_LAYERS != null else 40
	add_child(layer)
	fx_overlay = ColorRect.new()
	fx_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_overlay.visible = false
	layer.add_child(fx_overlay)
	_ko_burst = ColorRect.new()
	_ko_burst.name = "KoBurst"
	_ko_burst.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ko_burst.custom_minimum_size = Vector2(80, 80)
	_ko_burst.size = Vector2(80, 80)
	_ko_burst.pivot_offset = Vector2(40, 40)
	_ko_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ko_burst.visible = false
	_ko_burst.color = Color(1.0, 0.92, 0.55, 0.0)
	layer.add_child(_ko_burst)


func _pulse_ko_burst(strength: float) -> void:
	_ensure_event_fx_layer()
	if _ko_burst == null:
		return
	_ko_burst.visible = true
	_ko_burst.scale = Vector2(0.6, 0.6)
	_ko_burst.color = Color(1.0, 0.9, 0.45, 0.55 * strength)
	var tw := create_tween()
	tw.tween_property(_ko_burst, "scale", Vector2(14.0, 14.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_ko_burst, "color:a", 0.0, 0.28)
	tw.tween_callback(func():
		_ko_burst.visible = false
	)


func _try_attach_visual_glb() -> void:
	if OS.get_environment("SSK_DISABLE_STAGE_VISUALS") == "1":
		return
	var path := visual_glb_path.strip_edges()
	if path.is_empty():
		path = _default_visual_glb_path()
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var packed = load(path)
	if packed == null or not (packed is PackedScene):
		return
	var art := get_node_or_null("ArtRoot") as Node3D
	if art == null:
		art = Node3D.new()
		art.name = "ArtRoot"
		add_child(art)
	_visual_glb_root = (packed as PackedScene).instantiate() as Node3D
	if _visual_glb_root == null:
		return
	_visual_glb_root.name = "BlenderVisualV1"
	## Keep scenery behind combat platforms; collision stays on StageGameplayRoot.
	_visual_glb_root.position = Vector3(0.0, -1.0, -28.0)
	_visual_glb_root.scale = Vector3.ONE * 1.15
	art.add_child(_visual_glb_root)
	## Prefer Blender depth over flat silhouette props when GLB loads.
	var sil := get_tree().get_first_node_in_group("jeffrey_stage_silhouette")
	if sil != null:
		sil.visible = false


func _default_visual_glb_path() -> String:
	match stage_id:
		"palacio":
			return "res://assets/stages/palacio_de_lopez/visual/palacio_visual_v1.glb"
		"costanera":
			return "res://assets/stages/costanera_de_asuncion/visual/costanera_visual_v1.glb"
		_:
			return ""


func _build_platform_colors() -> void:
	var root := get_node_or_null("StageGameplayRoot")
	if root == null:
		return
	_tint_meshes(root, Color("#4a5568"))


func _tint_meshes(node: Node, color: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 0.72
			(child as MeshInstance3D).material_override = mat
			(child as MeshInstance3D).visible = true
		_tint_meshes(child, color)


func _attach_procedural_background() -> void:
	if OS.get_environment("SSK_DISABLE_STAGE_VISUALS") == "1":
		return
	var playground := get_parent()
	if playground == null:
		return
	var camera := playground.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	_bg = MeshInstance3D.new()
	_bg.name = "JeffreyStageBackdrop"
	var quad := QuadMesh.new()
	quad.size = Vector2(220, 120)
	_bg.mesh = quad
	_bg.position = Vector3(0.0, 8.0, -110.0)
	_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = sky_top
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bg.material_override = mat
	camera.add_child(_bg)
	_build_silhouette_props(camera)


func _build_silhouette_props(_camera: Camera3D) -> void:
	## Override in subclasses for recognizable landmarks.
	pass
