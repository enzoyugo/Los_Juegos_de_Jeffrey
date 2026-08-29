extends Node

## Diagnostic only: load the canonical Track car albedo. No atlas bake, no GLB, no physics.

const ATLAS_PATH := "res://assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg"


func _ready() -> void:
	print("[TRACK_TEXTURE_LOAD_ONLY] begin path=%s" % ATLAS_PATH)
	print("[TRACK_TEXTURE_LOAD_ONLY] exists=%s" % str(ResourceLoader.exists(ATLAS_PATH)))
	print("[TRACK_TEXTURE_LOAD_ONLY] os_static_memory_before=%d" % OS.get_static_memory_usage())
	var res: Resource = null
	if ResourceLoader.exists(ATLAS_PATH):
		res = ResourceLoader.load(ATLAS_PATH, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if res == null:
		print("[TRACK_TEXTURE_LOAD_ONLY] valid=false type=null")
		print("[TRACK_ATLAS] LOAD_FAILED path=%s fallback=true" % ATLAS_PATH)
		_quit_if_smoke()
		return
	print("[TRACK_TEXTURE_LOAD_ONLY] type=%s" % res.get_class())
	if not (res is Texture2D):
		print("[TRACK_TEXTURE_LOAD_ONLY] valid=false")
		_quit_if_smoke()
		return
	var tex := res as Texture2D
	var rid := tex.get_rid()
	print("[TRACK_TEXTURE_LOAD_ONLY] valid=%s" % str(tex.get_width() > 0 and rid.is_valid()))
	print("[TRACK_TEXTURE_LOAD_ONLY] width=%d" % tex.get_width())
	print("[TRACK_TEXTURE_LOAD_ONLY] height=%d" % tex.get_height())
	print("[TRACK_TEXTURE_LOAD_ONLY] format=%s" % tex.get_class())
	print("[TRACK_TEXTURE_LOAD_ONLY] rid=%s" % str(rid))
	print("[TRACK_TEXTURE_LOAD_ONLY] path=%s" % tex.resource_path)
	print("[TRACK_TEXTURE_LOAD_ONLY] os_static_memory_after=%d" % OS.get_static_memory_usage())
	print("[TRACK_TEXTURE_LOAD_ONLY] texture_mem=%d" % int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)))
	_quit_if_smoke()


func _quit_if_smoke() -> void:
	if OS.get_environment("SSK_TEXTURE_LOAD_SMOKE").strip_edges() == "1":
		get_tree().quit()
