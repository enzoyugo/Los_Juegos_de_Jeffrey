class_name TrackVisualQualityV2
extends RefCounted

## Authored Track visual pass — shared materials, signage atlas, facade cues.
## Does not own placement or physics. Consumed by TrackRace / kit / HUD.

const ATLAS_PATH := "res://assets/track/environment/runtime/signage_atlas_v2.png"
const FACADE_PATH := "res://assets/track/environment/runtime/facade_atlas_v2.png"
const ASPHALT_TEX_PATH := "res://assets/track/environment/runtime/asphalt_grain_v1.png"
const GROUND_TEX_PATH := "res://assets/track/environment/runtime/ground_grain_v1.png"

## Color script — cyan is accent only.
const ASPHALT := Color("#1c2128")
const ASPHALT_WARM := Color("#242830")
const CURB_CREAM := Color("#c9b89a")
const SIDEWALK := Color("#8e8a82")
const SHOULDER := Color("#6a655c")
const RAIL_CONCRETE := Color("#5a5e58")
const RAIL_METAL := Color("#3a424c")
const GROUND_DIRT := Color("#2c3428")
const GROUND_CONCRETE := Color("#3a4248")
const GROUND_GRASS := Color("#2a3a28")
const GROUND_PARKING := Color("#323840")
const CYAN := Color("#3db8c9")
const GOLD := Color("#e8b84a")
const GLASS := Color("#4a6070")
const SHOP_DARK := Color("#2a2830")

const BUILDING_PALETTE := [
	Color("#e8e4dc"), ## white concrete
	Color("#d8cbb4"), ## warm cream
	Color("#e0d08a"), ## pale yellow
	Color("#b86a4a"), ## terracotta accent
	Color("#2e2c34"), ## dark shopfront
	Color("#6a7a88"), ## glass blue-grey
	Color("#3a8a96"), ## painted commercial cyan (muted)
	Color("#8a4a48"), ## muted red
]

var _mats: Dictionary = {}
var _signage: Texture2D = null
var _facade: Texture2D = null
var _asphalt_tex: Texture2D = null
var _ground_tex: Texture2D = null
var _building_mats: Array = []
var _sign_mats: Array = []
var ready: bool = false


func ensure() -> void:
	if ready:
		return
	_signage = _load_or_bake_signage()
	_facade = _load_or_bake_facade()
	_asphalt_tex = _load_or_bake_noise(ASPHALT_TEX_PATH, 256, Color(0.14, 0.16, 0.19), 0.07, 2)
	_ground_tex = _load_or_bake_noise(GROUND_TEX_PATH, 256, Color(0.22, 0.28, 0.20), 0.09, 1)
	_mats["road"] = _surfaced(ASPHALT, 0.93, 0.0, _asphalt_tex, Vector3(0.08, 0.08, 0.08))
	_mats["road_warm"] = _surfaced(ASPHALT_WARM, 0.91, 0.0, _asphalt_tex, Vector3(0.07, 0.07, 0.07))
	_mats["shoulder"] = _surfaced(SHOULDER, 0.88, 0.02, _ground_tex, Vector3(0.1, 0.1, 0.1))
	_mats["sidewalk"] = _surfaced(SIDEWALK, 0.86, 0.02, _ground_tex, Vector3(0.12, 0.12, 0.12))
	_mats["curb"] = _surfaced(CURB_CREAM, 0.78, 0.04, _ground_tex, Vector3(0.2, 0.2, 0.2))
	_mats["rail"] = _mat(RAIL_CONCRETE, 0.84, 0.08)
	_mats["rail_metal"] = _mat(RAIL_METAL, 0.55, 0.45)
	_mats["marking"] = _mat(Color("#eef2f6"), 0.55, 0.0)
	_mats["edge"] = _mat(Color("#d8dce0"), 0.6, 0.0)
	_mats["ground"] = _surfaced(GROUND_DIRT, 0.97, 0.0, _ground_tex, Vector3(0.04, 0.04, 0.04))
	_mats["ground_concrete"] = _surfaced(GROUND_CONCRETE, 0.95, 0.0, _ground_tex, Vector3(0.05, 0.05, 0.05))
	_mats["ground_grass"] = _surfaced(GROUND_GRASS, 0.96, 0.0, _ground_tex, Vector3(0.035, 0.035, 0.035))
	_mats["ground_parking"] = _surfaced(GROUND_PARKING, 0.94, 0.0, _ground_tex, Vector3(0.06, 0.06, 0.06))
	_mats["finish"] = _emissive(GOLD, 0.7, 1.1)
	_mats["checkpoint"] = _emissive(CYAN, 0.65, 1.0)
	_mats["glass"] = _mat(GLASS, 0.35, 0.15)
	_mats["shop"] = _mat(SHOP_DARK, 0.8, 0.05)
	for i in BUILDING_PALETTE.size():
		var c: Color = BUILDING_PALETTE[i]
		var bm := _mat(c, 0.82 if i != 5 else 0.38, 0.04 if i != 5 else 0.2)
		if _facade != null and i != 4:
			bm.albedo_texture = _facade
			bm.uv1_triplanar = true
			bm.uv1_world_triplanar = true
			bm.uv1_triplanar_sharpness = 8.0
			bm.uv1_scale = Vector3(0.12, 0.18, 0.12)
		_building_mats.append(bm)
	for board in 8:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color.WHITE
		sm.roughness = 0.72
		if _signage != null:
			sm.albedo_texture = _signage
			## Atlas cell — BoxMesh UVs are 0–1; remap via uv1_scale/offset.
			var col := board % 4
			var row := int(board / 4)
			sm.uv1_scale = Vector3(0.25, 0.5, 1.0)
			sm.uv1_offset = Vector3(0.25 * float(col), 0.5 * float(row), 0.0)
		else:
			sm.albedo_color = Color("#1a3040") if board % 2 == 0 else Color("#3a2a18")
		sm.emission_enabled = false
		_sign_mats.append(sm)
	ready = true


func material_for_solid_kind(kind: String, color: Color) -> StandardMaterial3D:
	ensure()
	match kind:
		"road":
			return _mats["road"] if color.v < 0.55 else _mats["road_warm"]
		"shoulder":
			return _mats["shoulder"]
		"curb":
			return _mats["curb"]
		"rail":
			return _mats["rail"]
		"finish", "finish_mark":
			return _mats["finish"]
		_:
			## Finish gold strip from generator uses bright color without kind.
			if color.r > 0.65 and color.g > 0.55 and color.b < 0.45:
				return _mats["finish"]
			if color.v <= 0.42:
				return _mats["road"]
			if color.v >= 0.55:
				return _mats["rail"]
			return _mats["shoulder"]


func building_material(variant: int) -> StandardMaterial3D:
	ensure()
	if _building_mats.is_empty():
		return _mat(BUILDING_PALETTE[0], 0.82, 0.04)
	return _building_mats[absi(variant) % _building_mats.size()]


func signage_material(board: int) -> StandardMaterial3D:
	ensure()
	if _sign_mats.is_empty():
		return _mat(CYAN, 0.7, 0.05)
	return _sign_mats[absi(board) % _sign_mats.size()]


func mat(key: String) -> StandardMaterial3D:
	ensure()
	return _mats.get(key, _mats["ground"])


func signage_texture() -> Texture2D:
	ensure()
	return _signage


func facade_texture() -> Texture2D:
	ensure()
	return _facade


static func shared():
	if _instance == null:
		_instance = new()
		_instance.ensure()
	return _instance


static var _instance = null


func attach_start_finish_gantry(parent: Node3D, xform: Transform3D, finish: bool) -> void:
	ensure()
	var root := Node3D.new()
	root.name = "FinishGantry" if finish else "StartGantry"
	parent.add_child(root)
	root.global_transform = xform
	var accent := GOLD if finish else CYAN
	## Twin posts
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.28, 5.2, 0.28)
		post.mesh = box
		post.position = Vector3(side * 5.6, 2.6, 0.0)
		post.material_override = _mat(Color("#2a3038"), 0.55, 0.35)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(post)
	## Crossbeam
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(11.4, 0.35, 0.45)
	beam.mesh = bm
	beam.position = Vector3(0, 5.15, 0)
	beam.material_override = _mat(Color("#1e242c"), 0.6, 0.3)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	## Brand board
	var board := MeshInstance3D.new()
	var face := BoxMesh.new()
	face.size = Vector3(6.5, 1.15, 0.12)
	board.mesh = face
	board.position = Vector3(0, 5.15, -0.28)
	board.material_override = signage_material(3 if not finish else 2)
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(board)
	## Accent stripe under beam
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(11.2, 0.12, 0.2)
	stripe.mesh = sm
	stripe.position = Vector3(0, 4.85, 0)
	stripe.material_override = _emissive(accent, 0.55, 1.4)
	stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stripe)
	## Road paint bar (visual only — original collision checkpoint remains)
	var paint := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(10.2, 0.06, 0.55)
	paint.mesh = pm
	paint.position = Vector3(0, 0.55, 0)
	paint.material_override = _emissive(accent, 0.5, 1.2)
	paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(paint)


func attach_checkpoint_markers(parent: Node3D, xform: Transform3D, finish: bool) -> void:
	ensure()
	if finish:
		attach_start_finish_gantry(parent, xform, true)
		return
	var root := Node3D.new()
	root.name = "CheckpointMarkers"
	parent.add_child(root)
	root.global_transform = xform
	var accent := CYAN
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 2.4, 0.22)
		post.mesh = box
		post.position = Vector3(side * 5.4, 1.3, 0)
		post.material_override = _mat(Color("#2c343c"), 0.6, 0.25)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(post)
		var flag := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.08, 0.85, 0.55)
		flag.mesh = fm
		flag.position = Vector3(side * 5.4, 2.35, -0.15)
		flag.material_override = _emissive(accent, 0.55, 1.15)
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(flag)
	## Subtle road paint chevron
	var paint := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(9.5, 0.05, 0.28)
	paint.mesh = pm
	paint.position = Vector3(0, 0.52, 0)
	paint.material_override = _emissive(Color(accent.r, accent.g, accent.b, 1.0), 0.6, 0.85)
	paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(paint)


func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _surfaced(color: Color, roughness: float, metallic: float, tex: Texture2D, uv_scale: Vector3) -> StandardMaterial3D:
	var m := _mat(color, roughness, metallic)
	if tex != null:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = uv_scale
	return m


func _emissive(color: Color, roughness: float, energy: float) -> StandardMaterial3D:
	var m := _mat(color, roughness, 0.05)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _load_or_bake_noise(res_path: String, size: int, base: Color, amp: float, seed_n: int) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var loaded = load(res_path)
		if loaded is Texture2D:
			return loaded
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n * 7919 + 4242
	for y in size:
		for x in size:
			## Dual-frequency grain — cheap tileable asphalt/ground breakup.
			var n1 := rng.randf()
			var n2 := sin(float(x) * 0.37 + float(y) * 0.21) * 0.5 + 0.5
			var n := clampf(n1 * 0.65 + n2 * 0.35, 0.0, 1.0)
			var d := (n - 0.5) * amp * 2.0
			img.set_pixel(x, y, Color(
				clampf(base.r + d, 0.0, 1.0),
				clampf(base.g + d * 0.95, 0.0, 1.0),
				clampf(base.b + d * 0.9, 0.0, 1.0),
				1.0
			))
	## Soft macro blotches
	for _b in 18:
		var cx := rng.randi_range(0, size - 1)
		var cy := rng.randi_range(0, size - 1)
		var rad := rng.randi_range(8, 28)
		var tint := (rng.randf() - 0.5) * amp * 1.4
		for yy in range(maxi(cy - rad, 0), mini(cy + rad, size)):
			for xx in range(maxi(cx - rad, 0), mini(cx + rad, size)):
				var dx := float(xx - cx)
				var dy := float(yy - cy)
				if dx * dx + dy * dy > float(rad * rad):
					continue
				var p := img.get_pixel(xx, yy)
				img.set_pixel(xx, yy, Color(
					clampf(p.r + tint, 0.0, 1.0),
					clampf(p.g + tint * 0.9, 0.0, 1.0),
					clampf(p.b + tint * 0.85, 0.0, 1.0),
					1.0
				))
	_try_save_png(img, res_path)
	return ImageTexture.create_from_image(img)


func _load_or_bake_signage() -> Texture2D:
	if ResourceLoader.exists(ATLAS_PATH):
		var loaded = load(ATLAS_PATH)
		if loaded is Texture2D:
			return loaded
	var img := _bake_signage_image()
	_try_save_png(img, ATLAS_PATH)
	return ImageTexture.create_from_image(img)


func _load_or_bake_facade() -> Texture2D:
	if ResourceLoader.exists(FACADE_PATH):
		var loaded = load(FACADE_PATH)
		if loaded is Texture2D:
			return loaded
	var img := _bake_facade_image()
	_try_save_png(img, FACADE_PATH)
	return ImageTexture.create_from_image(img)


func _try_save_png(img: Image, res_path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(res_path)
	var dir := abs_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(abs_path)


func _bake_signage_image() -> Image:
	var img := Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.06, 0.08, 0.1, 1.0))
	var boards := [
		{"t": "JEFFREY", "sub": "LOS JUEGOS", "bg": Color("#123038"), "fg": CYAN},
		{"t": "COPA", "sub": "JEFFREY", "bg": Color("#2a2418"), "fg": GOLD},
		{"t": "TRACK", "sub": "ASUNCION", "bg": Color("#102028"), "fg": CYAN},
		{"t": "GALLO", "sub": "PICANTE", "bg": Color("#3a2018"), "fg": Color("#e07040")},
		{"t": "DALE", "sub": "YA", "bg": Color("#0e2830"), "fg": GOLD},
		{"t": "TERERE", "sub": "EXPRESS", "bg": Color("#1a3020"), "fg": Color("#80c070")},
		{"t": "COSTA", "sub": "NIGHT", "bg": Color("#182030"), "fg": Color("#80a0c0")},
		{"t": "PARTY", "sub": "JEFFREY", "bg": Color("#201828"), "fg": Color("#d060a0")},
	]
	for i in boards.size():
		var col := i % 4
		var row := int(i / 4)
		var x0 := col * 256
		var y0 := row * 256
		var b: Dictionary = boards[i]
		_fill_rect(img, x0 + 8, y0 + 8, 240, 240, b["bg"])
		_fill_rect(img, x0 + 8, y0 + 8, 240, 18, b["fg"])
		_fill_rect(img, x0 + 8, y0 + 230, 240, 18, Color(b["fg"].r, b["fg"].g, b["fg"].b, 0.65))
		_blit_text(img, x0 + 24, y0 + 80, str(b["t"]), b["fg"], 4)
		_blit_text(img, x0 + 24, y0 + 150, str(b["sub"]), Color(0.92, 0.94, 0.96), 2)
	return img


func _bake_facade_image() -> Image:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.92, 0.90, 0.86, 1.0))
	## Window grid — dark glass bands.
	for row in 6:
		for col in 5:
			var x := 18 + col * 46
			var y := 16 + row * 40
			_fill_rect(img, x, y, 28, 22, Color(0.22, 0.28, 0.34, 1.0))
			_fill_rect(img, x + 2, y + 2, 10, 8, Color(0.45, 0.55, 0.62, 0.55))
	## Storefront band
	_fill_rect(img, 0, 210, 256, 46, Color(0.18, 0.16, 0.18, 1.0))
	_fill_rect(img, 20, 220, 50, 28, Color(0.35, 0.55, 0.62, 1.0))
	_fill_rect(img, 90, 220, 50, 28, Color(0.35, 0.55, 0.62, 1.0))
	_fill_rect(img, 160, 220, 70, 28, Color(0.12, 0.12, 0.14, 1.0))
	## Roof trim
	_fill_rect(img, 0, 0, 256, 10, Color(0.55, 0.5, 0.42, 1.0))
	return img


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(maxi(y, 0), mini(y + h, img.get_height())):
		for xx in range(maxi(x, 0), mini(x + w, img.get_width())):
			img.set_pixel(xx, yy, color)


## Tiny 5x7 block font for atlas bake (A-Z, 0-9, space).
func _blit_text(img: Image, x: int, y: int, text: String, color: Color, scale: int) -> void:
	var cx := x
	for ch in text.to_upper():
		var glyph := _glyph(ch)
		for row in 7:
			for col in 5:
				if glyph[row] & (1 << (4 - col)):
					_fill_rect(img, cx + col * scale, y + row * scale, scale, scale, color)
		cx += 6 * scale


func _glyph(ch: String) -> Array:
	## Each entry: 7 rows, 5-bit columns.
	var g := {
		" ": [0, 0, 0, 0, 0, 0, 0],
		"A": [14, 17, 17, 31, 17, 17, 17],
		"B": [30, 17, 17, 30, 17, 17, 30],
		"C": [14, 17, 16, 16, 16, 17, 14],
		"D": [30, 17, 17, 17, 17, 17, 30],
		"E": [31, 16, 16, 30, 16, 16, 31],
		"F": [31, 16, 16, 30, 16, 16, 16],
		"G": [14, 17, 16, 19, 17, 17, 14],
		"H": [17, 17, 17, 31, 17, 17, 17],
		"I": [14, 4, 4, 4, 4, 4, 14],
		"J": [1, 1, 1, 1, 17, 17, 14],
		"K": [17, 18, 20, 24, 20, 18, 17],
		"L": [16, 16, 16, 16, 16, 16, 31],
		"M": [17, 27, 21, 21, 17, 17, 17],
		"N": [17, 25, 21, 19, 17, 17, 17],
		"O": [14, 17, 17, 17, 17, 17, 14],
		"P": [30, 17, 17, 30, 16, 16, 16],
		"Q": [14, 17, 17, 17, 21, 18, 13],
		"R": [30, 17, 17, 30, 20, 18, 17],
		"S": [14, 17, 16, 14, 1, 17, 14],
		"T": [31, 4, 4, 4, 4, 4, 4],
		"U": [17, 17, 17, 17, 17, 17, 14],
		"V": [17, 17, 17, 17, 17, 10, 4],
		"W": [17, 17, 17, 21, 21, 21, 10],
		"X": [17, 17, 10, 4, 10, 17, 17],
		"Y": [17, 17, 10, 4, 4, 4, 4],
		"Z": [31, 1, 2, 4, 8, 16, 31],
		"0": [14, 17, 19, 21, 25, 17, 14],
		"1": [4, 12, 4, 4, 4, 4, 14],
		"2": [14, 17, 1, 6, 8, 16, 31],
		"3": [30, 1, 1, 14, 1, 1, 30],
		"4": [2, 6, 10, 18, 31, 2, 2],
		"5": [31, 16, 30, 1, 1, 17, 14],
		"6": [14, 16, 16, 30, 17, 17, 14],
		"7": [31, 1, 2, 4, 8, 8, 8],
		"8": [14, 17, 17, 14, 17, 17, 14],
		"9": [14, 17, 17, 15, 1, 1, 14],
	}
	return g.get(ch, g[" "])
