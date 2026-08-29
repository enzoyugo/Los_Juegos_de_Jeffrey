class_name ZombiesBuyableDoor
extends "res://scripts/zombies/zombies_interactable.gd"

signal opened

const Config := preload("res://scripts/zombies/zombies_config.gd")

var display_name: String = Config.DOOR_NAME
var cost: int = Config.DOOR_COST
var locked: bool = true
var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _label: Label3D
var _obstacle: NavigationObstacle3D
var _shutter: Node3D


func configure(name_text: String, point_cost: int) -> void:
	display_name = name_text
	cost = point_cost


func _ready() -> void:
	collision_layer = Config.LAYER_WORLD | Config.LAYER_INTERACT
	collision_mask = 0
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(5.0, 3.6, 0.35)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Config.COLOR_DOOR
	_mesh.set_surface_override_material(0, mat)
	_mesh.position = Vector3(0, 1.8, 0)
	add_child(_mesh)
	_shutter = Node3D.new()
	_shutter.name = "Shutter"
	add_child(_shutter)
	for i in 6:
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(0.12, 3.2, 0.08)
		bar.mesh = bar_mesh
		var bar_mat := StandardMaterial3D.new()
		bar_mat.albedo_color = Color("#3a3530")
		bar_mat.metallic = 0.4
		bar_mat.roughness = 0.45
		bar.set_surface_override_material(0, bar_mat)
		bar.position = Vector3(-2.0 + float(i) * 0.8, 1.7, 0.22)
		_shutter.add_child(bar)
	var slat := MeshInstance3D.new()
	var slat_mesh := BoxMesh.new()
	slat_mesh.size = Vector3(5.0, 1.1, 0.06)
	slat.mesh = slat_mesh
	var slat_mat := StandardMaterial3D.new()
	slat_mat.albedo_color = Color("#6a6258")
	slat.set_surface_override_material(0, slat_mat)
	slat.position = Vector3(0, 2.9, 0.20)
	_shutter.add_child(slat)
	_col = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 3.6, 0.35)
	_col.shape = shape
	_col.position = Vector3(0, 1.8, 0)
	add_child(_col)
	_label = Label3D.new()
	_label.position = Vector3(0, 3.15, 0.22)
	_label.font_size = 48
	_label.modulate = Config.COLOR_CREAM
	_label.outline_modulate = Color(0, 0, 0, 0.9)
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	_obstacle = NavigationObstacle3D.new()
	_obstacle.radius = 2.6
	_obstacle.position = Vector3(0, 0.1, 0)
	_obstacle.avoidance_enabled = true
	add_child(_obstacle)
	_refresh_label()


func get_prompt() -> String:
	if not locked:
		return ""
	return "[E] ABRIR %s\n%d" % [display_name, cost]


func try_interact(player: Node) -> bool:
	if not locked:
		return false
	if player == null or not player.has_method("spend_points"):
		return false
	var ok = player.call("spend_points", cost)
	if ok != true:
		return false
	unlock()
	return true


func unlock() -> void:
	if not locked:
		return
	locked = false
	if _mesh != null:
		_mesh.visible = false
	if _shutter != null:
		_shutter.visible = false
	if _col != null:
		_col.disabled = true
	collision_layer = 0
	if _label != null:
		_label.visible = false
	if _obstacle != null:
		_obstacle.avoidance_enabled = false
	opened.emit()


func _refresh_label() -> void:
	if _label == null:
		return
	_label.text = "%s  ·  %d" % [display_name, cost]
