class_name StadiumCameraBackground
extends MeshInstance3D

const HERO_TEXTURE := preload("res://assets/stages/defensores_del_chaco/background/defensores_bg_main.png")
const HERO_REGION := Rect2(0, 0, 1672, 941)
const BACKGROUND_DISTANCE := 118.0
const COVER_MARGIN := 1.22

var _camera: Camera3D

func _ready() -> void:
	_camera = get_parent() as Camera3D
	name = "StadiumBackgroundQuad"
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Z
	mesh = quad
	position = Vector3(0.0, 0.0, -BACKGROUND_DISTANCE)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	sorting_offset = -128.0
	var material := StandardMaterial3D.new()
	material.albedo_texture = _hero_texture()
	material.albedo_color = Color(0.9, 0.94, 1.0, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material_override = material
	_update_cover()

func _process(_delta: float) -> void:
	_update_cover()

func _update_cover() -> void:
	if _camera == null or mesh == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.y <= 0.0:
		return
	var view_aspect := viewport_size.x / viewport_size.y
	var half_height := BACKGROUND_DISTANCE * tan(deg_to_rad(_camera.fov * 0.5)) * COVER_MARGIN
	var half_width := half_height * view_aspect * COVER_MARGIN
	(mesh as QuadMesh).size = Vector2(half_width * 2.0, half_height * 2.0)
	var tex_aspect := HERO_REGION.size.x / HERO_REGION.size.y
	var uv_scale := Vector2.ONE
	if view_aspect > tex_aspect:
		uv_scale.y = tex_aspect / view_aspect
	else:
		uv_scale.x = view_aspect / tex_aspect
	var material := material_override as StandardMaterial3D
	if material == null:
		return
	material.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	material.uv1_offset = Vector3((1.0 - uv_scale.x) * 0.5, (1.0 - uv_scale.y) * 0.5, 0.0)

func _hero_texture() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = HERO_TEXTURE
	atlas.region = HERO_REGION
	return atlas
