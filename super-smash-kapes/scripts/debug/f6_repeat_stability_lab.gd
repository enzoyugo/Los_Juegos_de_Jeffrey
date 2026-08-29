extends Node

## Alternating Track showcase + ZombiesMain launches. Standalone F6 analogue.

const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")

const SEQ: PackedStringArray = [
	"res://scenes/debug/TrackTurboV8Showcase.tscn",
	"res://scenes/debug/ShoppingBlenderEnvironmentV3Lab.tscn",
	"res://scenes/zombies/ZombiesMain.tscn",
]

var _hold := 3.2
var _launches := 10
var _i := -1
var _live: Node
var _t := 0.0
var _fatal := false


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var n := OS.get_environment("SSK_F6_LAUNCHES").strip_edges()
	if not n.is_empty():
		_launches = maxi(int(n), 2)
	print("[F6_STABILITY] START launches=%d hold=%.1f pid=%d" % [_launches, _hold, OS.get_process_id()])
	Probe.dump("f6_start", self)
	_next()


func _process(delta: float) -> void:
	if _live == null:
		return
	_t += delta
	if _t >= _hold:
		Probe.dump("f6_exit_%d" % _i, _live)
		_live.queue_free()
		_live = null
		_next()


func _next() -> void:
	_i += 1
	if _i >= _launches:
		print("[F6_STABILITY] PASS launches=%d fatal=%s" % [_launches, str(_fatal)])
		get_tree().quit(1 if _fatal else 0)
		return
	var path := SEQ[_i % SEQ.size()]
	print("[F6_STABILITY] LAUNCH %d %s" % [_i + 1, path])
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("[F6_STABILITY] FAIL load %s" % path)
		_fatal = true
		_next()
		return
	_live = packed.instantiate()
	add_child(_live)
	if _live.get_script() == null:
		print("[F6_STABILITY] FAIL no_script %s" % path)
		_fatal = true
	if _live.has_method("_generate_and_reveal"):
		_live.call("_generate_and_reveal")
		var rev = _live.get("_reveal")
		if rev != null:
			rev.set("skip", true)
	_t = 0.0
	Probe.dump("f6_ready_%d" % (_i + 1), _live)
