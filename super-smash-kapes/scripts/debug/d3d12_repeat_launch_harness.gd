extends Node

## Rendered D3D12 repeat-launch analogue of editor F6 close/open.
## Instantiates real gameplay scenes, holds frames, frees, repeats.
## ResourceCache persists in-process the same way editor F5 does.

const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")

const CYCLE: PackedStringArray = [
	"res://scenes/zombies/ZombiesMain.tscn",
	"res://scenes/debug/TrackGeneratorV2Lab.tscn",
	"res://scenes/zombies/ZombiesMain.tscn",
	"res://scenes/debug/TrackGeneratorV2Lab.tscn",
	"res://scenes/track/TrackMain.tscn",
	"res://scenes/zombies/ZombiesMain.tscn",
]

var _hold_s: float = 5.2
var _live: Node
var _cycle: int = 0
var _index: int = -1
var _clock: float = 0.0
var _dumped_ready: bool = false
var _dumped_5: bool = false
var _fatal: bool = false
var _label: Label
const CYCLES := 3


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var hold := OS.get_environment("SSK_D3D12_HOLD").strip_edges()
	if not hold.is_empty():
		_hold_s = maxf(float(hold), 2.0)
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 10)
	_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(_label)
	print("[D3D12_REPEAT] START cycles=%d hold=%.1fs driver=d3d12" % [CYCLES, _hold_s])
	Probe.dump("editor_project_start", self)
	_next()


func _process(delta: float) -> void:
	_clock += delta
	if _label != null:
		_label.text = "D3D12 REPEAT c=%d i=%d t=%.1f %s" % [
			_cycle + 1, _index + 1, _clock, CYCLE[_index] if _index >= 0 and _index < CYCLE.size() else ""
		]
	if _live == null:
		if _clock >= 0.0 and _index >= 0:
			_next()
		return
	if not _dumped_ready and _clock >= 0.15:
		Probe.dump("scene_ready c%d i%d" % [_cycle + 1, _index + 1], _live)
		_dumped_ready = true
	if not _dumped_5 and _clock >= minf(5.0, _hold_s - 0.2):
		Probe.dump("t5 c%d i%d" % [_cycle + 1, _index + 1], _live)
		_dumped_5 = true
	if _clock >= _hold_s:
		Probe.dump("scene_exit c%d i%d" % [_cycle + 1, _index + 1], _live)
		_live.queue_free()
		_live = null
		_clock = -0.2


func _next() -> void:
	_index += 1
	if _index >= CYCLE.size():
		_index = 0
		_cycle += 1
		if _cycle >= CYCLES:
			print("[D3D12_REPEAT] PASS cycles=%d fatal=%s" % [CYCLES, str(_fatal)])
			get_tree().quit(0)
			return
	var path := CYCLE[_index]
	print("[D3D12_REPEAT] LAUNCH cycle=%d index=%d path=%s" % [_cycle + 1, _index + 1, path])
	if not ResourceLoader.exists(path):
		print("[D3D12_REPEAT] MISSING %s" % path)
		_fatal = true
		_next()
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("[D3D12_REPEAT] LOAD_FAIL %s" % path)
		_fatal = true
		_next()
		return
	_live = packed.instantiate()
	add_child(_live)
	_clock = 0.0
	_dumped_ready = false
	_dumped_5 = false
	Probe.dump("before_scene_launch c%d i%d" % [_cycle + 1, _index + 1], self)
