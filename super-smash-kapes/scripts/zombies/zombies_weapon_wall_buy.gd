class_name ZombiesWeaponWallBuy
extends "res://scripts/zombies/zombies_interactable.gd"

const Config := preload("res://scripts/zombies/zombies_config.gd")
const Props := preload("res://scripts/zombies/zombies_mall_props.gd")

var weapon_id: String = "smg"
var cost: int = Config.WALL_SMG_COST
var ammo_cost: int = Config.WALL_AMMO_COST
var _label: Label3D


func configure(id: String, point_cost: int, refill_cost: int) -> void:
	weapon_id = id
	cost = point_cost
	ammo_cost = refill_cost
	_refresh_label()


func _ready() -> void:
	collision_layer = Config.LAYER_INTERACT
	collision_mask = 0
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 1.1, 0.55)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3a3530")
	mesh.set_surface_override_material(0, mat)
	mesh.position = Vector3(0, 1.35, 0)
	add_child(mesh)
	Props.add_smg_silhouette(self, Vector3(0.12, 0, 0))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.6, 1.0)
	col.shape = shape
	col.position = Vector3(0, 1.2, 0)
	add_child(col)
	_label = Label3D.new()
	_label.position = Vector3(0.2, 2.15, 0)
	_label.font_size = 36
	_label.modulate = Config.COLOR_CREAM
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.9)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	_refresh_label()


func get_prompt() -> String:
	return "[E] COMPRAR %s\n%d" % [_pretty(), cost]


func prompt_for(player: Node) -> String:
	if player != null and player.has_method("owns_weapon"):
		var owned = player.call("owns_weapon", weapon_id)
		if owned == true:
			return "[E] MUNICIÓN %s\n%d" % [_pretty(), ammo_cost]
	return get_prompt()


func try_interact(player: Node) -> bool:
	if player == null:
		return false
	var owned := false
	if player.has_method("owns_weapon"):
		var flag = player.call("owns_weapon", weapon_id)
		owned = flag == true
	if owned:
		if not player.has_method("spend_points"):
			return false
		var paid = player.call("spend_points", ammo_cost)
		if paid != true:
			return false
		if player.has_method("refill_weapon"):
			player.call("refill_weapon", weapon_id)
		return true
	if not player.has_method("spend_points"):
		return false
	var bought = player.call("spend_points", cost)
	if bought != true:
		return false
	if player.has_method("give_weapon"):
		player.call("give_weapon", weapon_id)
	return true


func _pretty() -> String:
	if weapon_id == "smg":
		return "SMG"
	return weapon_id.to_upper()


func _refresh_label() -> void:
	if _label == null:
		return
	_label.text = "%s  ·  %d" % [_pretty(), cost]
