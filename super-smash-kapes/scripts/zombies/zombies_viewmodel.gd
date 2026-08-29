class_name ZombiesViewmodel
extends Node3D

## First-person pistol / SMG. Shared materials. Slide, barrel, sights, mag.

const METAL := Color("#1a1d22")
const METAL_DARK := Color("#121417")
const ACCENT := Color("#c9a227")
const FLASH := Color("#ffe8a0")

var weapon_id: String = "pistol"
var _root: Node3D
var _pistol: Node3D
var _smg: Node3D
var _flash_mesh: MeshInstance3D
var _flash_light: OmniLight3D
var _shell: MeshInstance3D
var _flash_left: float = 0.0
var _recoil: float = 0.0
var _dry: float = 0.0
var _t: float = 0.0
var _shell_t: float = 0.0
var _base_pos := Vector3(0.20, -0.18, -0.42)
var _base_rot := Vector3.ZERO
var _mat_metal: StandardMaterial3D
var _mat_dark: StandardMaterial3D
var _mat_accent: StandardMaterial3D


func _ready() -> void:
	position = _base_pos
	_mat_metal = _make(METAL, 0.45, 0.62)
	_mat_dark = _make(METAL_DARK, 0.5, 0.55)
	_mat_accent = _make(ACCENT, 0.4, 0.2)
	_root = Node3D.new()
	add_child(_root)
	_pistol = _build_pistol()
	_root.add_child(_pistol)
	_smg = _build_smg()
	_smg.visible = false
	_root.add_child(_smg)
	_flash_mesh = MeshInstance3D.new()
	var flash_box := BoxMesh.new()
	flash_box.size = Vector3(0.045, 0.045, 0.07)
	_flash_mesh.mesh = flash_box
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = FLASH
	flash_mat.emission_enabled = true
	flash_mat.emission = FLASH
	flash_mat.emission_energy_multiplier = 3.6
	_flash_mesh.set_surface_override_material(0, flash_mat)
	_flash_mesh.position = Vector3(0.0, 0.02, -0.28)
	_flash_mesh.visible = false
	_root.add_child(_flash_mesh)
	_flash_light = OmniLight3D.new()
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 2.8
	_flash_light.light_color = Color("#ffdca8")
	_flash_light.shadow_enabled = false
	_flash_light.position = Vector3(0.0, 0.02, -0.30)
	_root.add_child(_flash_light)
	_shell = _box(Vector3(0.012, 0.012, 0.028), Vector3(0.04, 0.02, -0.02), _mat_accent)
	_shell.visible = false
	_root.add_child(_shell)
	set_weapon("pistol")


func set_weapon(id: String) -> void:
	weapon_id = id
	var smg_on: bool = id == "smg"
	if _pistol != null:
		_pistol.visible = not smg_on
	if _smg != null:
		_smg.visible = smg_on
	if _flash_mesh != null:
		_flash_mesh.position = Vector3(0.0, 0.024, -0.40 if smg_on else -0.30)


func play_recoil(automatic: bool) -> void:
	_recoil = 0.055 if automatic else 0.11
	_flash_left = 0.045 if automatic else 0.055
	_shell_t = 0.12
	if _shell != null:
		_shell.visible = true
		_shell.position = Vector3(0.03, 0.03, -0.04)
		_shell.rotation = Vector3.ZERO


func play_dry() -> void:
	_dry = 0.10


func tick(delta: float, moving: bool, reloading: bool) -> void:
	_t += delta
	_recoil = move_toward(_recoil, 0.0, delta * (10.0 if weapon_id == "smg" else 7.0))
	_dry = move_toward(_dry, 0.0, delta * 8.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash_mesh != null:
		_flash_mesh.visible = _flash_left > 0.0
	if _flash_light != null:
		_flash_light.light_energy = 6.2 if _flash_left > 0.0 else 0.0
	if _shell_t > 0.0:
		_shell_t = maxf(_shell_t - delta, 0.0)
		if _shell != null:
			_shell.position += Vector3(delta * 0.55, delta * 0.8, delta * 0.15)
			_shell.rotation.z += delta * 8.0
			if _shell_t <= 0.0:
				_shell.visible = false
	var sway_x: float = sin(_t * 1.15) * 0.006
	var sway_y: float = cos(_t * 1.35) * 0.004
	var bob: float = 0.0
	if moving:
		bob = sin(_t * 8.5) * 0.012
	var dip: float = 0.07 if reloading else 0.0
	var dip_rot: float = 0.42 if reloading else 0.0
	position = _base_pos + Vector3(sway_x, sway_y + bob - dip, _recoil * 0.22)
	rotation = _base_rot + Vector3(-_recoil * 0.85 - dip_rot, 0.0, _dry * 0.35)


func _build_pistol() -> Node3D:
	var root := Node3D.new()
	root.name = "Pistol"
	## Grip
	root.add_child(_box(Vector3(0.046, 0.125, 0.052), Vector3(0.0, -0.068, 0.028), _mat_dark))
	root.add_child(_box(Vector3(0.026, 0.09, 0.02), Vector3(0.0, -0.055, 0.012), _mat_accent))
	## Frame / slide
	root.add_child(_box(Vector3(0.062, 0.048, 0.19), Vector3(0.0, 0.018, -0.04), _mat_metal))
	root.add_child(_box(Vector3(0.058, 0.016, 0.16), Vector3(0.0, 0.044, -0.05), _mat_dark))
	## Barrel
	root.add_child(_box(Vector3(0.022, 0.022, 0.14), Vector3(0.0, 0.018, -0.18), _mat_metal))
	root.add_child(_box(Vector3(0.028, 0.028, 0.03), Vector3(0.0, 0.018, -0.27), _mat_dark))
	## Trigger guard
	root.add_child(_box(Vector3(0.012, 0.05, 0.038), Vector3(0.0, -0.018, -0.02), _mat_metal))
	root.add_child(_box(Vector3(0.012, 0.012, 0.038), Vector3(0.0, -0.04, -0.02), _mat_metal))
	## Mag
	root.add_child(_box(Vector3(0.032, 0.08, 0.04), Vector3(0.0, -0.08, 0.01), _mat_dark))
	## Sights
	root.add_child(_box(Vector3(0.01, 0.022, 0.016), Vector3(0.0, 0.058, -0.14), _mat_dark))
	root.add_child(_box(Vector3(0.028, 0.014, 0.012), Vector3(0.0, 0.054, 0.04), _mat_accent))
	return root


func _build_smg() -> Node3D:
	var root := Node3D.new()
	root.name = "SMG"
	## Receiver
	root.add_child(_box(Vector3(0.054, 0.054, 0.28), Vector3(0.0, 0.014, -0.08), _mat_metal))
	## Stock
	root.add_child(_box(Vector3(0.03, 0.03, 0.14), Vector3(0.0, 0.012, 0.14), _mat_dark))
	root.add_child(_box(Vector3(0.08, 0.012, 0.08), Vector3(0.0, -0.02, 0.18), _mat_dark))
	## Grip
	root.add_child(_box(Vector3(0.036, 0.125, 0.048), Vector3(0.0, -0.07, -0.02), _mat_dark))
	## Mag
	root.add_child(_box(Vector3(0.028, 0.14, 0.04), Vector3(0.0, -0.1, -0.06), _mat_metal))
	## Barrel + front sight
	root.add_child(_box(Vector3(0.02, 0.02, 0.18), Vector3(0.0, 0.02, -0.28), _mat_metal))
	root.add_child(_box(Vector3(0.032, 0.032, 0.04), Vector3(0.0, 0.02, -0.38), _mat_dark))
	root.add_child(_box(Vector3(0.016, 0.04, 0.016), Vector3(0.0, 0.05, -0.22), _mat_dark))
	## Top rail
	root.add_child(_box(Vector3(0.02, 0.012, 0.16), Vector3(0.0, 0.046, -0.06), _mat_accent))
	return root


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.set_surface_override_material(0, mat)
	return mesh


func _make(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
