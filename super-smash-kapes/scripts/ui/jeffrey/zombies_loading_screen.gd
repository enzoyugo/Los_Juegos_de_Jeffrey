class_name JeffreyZombiesLoadingScreen
extends Control

## Presentation-only Zombies loading screen. Reuses existing transition timing.

signal finished(mode_id: String, context: Dictionary)

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")
const ZAssets := preload("res://scripts/ui/jeffrey/zombies_ui_assets.gd")

var embedded: bool = false
var auto_complete: bool = true
var duration: float = 1.2
var loading_text: Label
var flavor_text: Label
var progress_fill: Control
var _clip: Control
var _reveal: TextureRect
var _bar_host: Control
var _elapsed: float = 0.0
var _mode_id: String = ""
var _context: Dictionary = {}
var _busy: bool = false
var _built: bool = false


func _ready() -> void:
	name = "ZombiesLoading"
	Layout.bind_full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_input(true)
	if not _built:
		build_visual()


func present(mode_id: String, context: Dictionary = {}) -> void:
	_mode_id = mode_id
	_context = context.duplicate(true)
	if not _built:
		build_visual()
	_elapsed = 0.0
	_busy = auto_complete
	set_progress(0.12)
	set_process(auto_complete)
	AudioHooks.play_zombies_hit(self)


func freeze_for_capture(amount: float = 0.85) -> void:
	if not _built:
		build_visual()
	_busy = false
	set_process(false)
	set_progress(amount)


func build_visual() -> void:
	if _built:
		return
	_built = true
	for child in get_children():
		child.queue_free()

	var bg := TextureRect.new()
	bg.name = "Background"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.texture = Assets.texture(ZAssets.LOADING_BG)
	Layout.bind_full(bg)
	add_child(bg)

	var title := TextureRect.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	title.texture = Assets.texture(ZAssets.TITLE)
	add_child(title)
	Layout.apply_frac(title, 0.031, 0.051, 0.32, 0.32)

	var content := Control.new()
	content.name = "LoadingContent"
	Layout.bind_full(content)
	add_child(content)

	loading_text = Layout.outlined_label(ZAssets.LOADING_COPY, 34, ZAssets.SLIME, HORIZONTAL_ALIGNMENT_CENTER)
	loading_text.name = "LoadingText"
	Styles.apply(loading_text, "transition_status")
	loading_text.add_theme_font_size_override("font_size", 34)
	loading_text.add_theme_color_override("font_color", ZAssets.SLIME)
	content.add_child(loading_text)
	Layout.apply_frac(loading_text, 0.16, 0.755, 0.68, 0.055)

	flavor_text = Layout.outlined_label(ZAssets.FLAVOR, 18, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	flavor_text.name = "FlavorText"
	flavor_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Styles.apply(flavor_text, "small_helper")
	flavor_text.add_theme_font_size_override("font_size", 18)
	flavor_text.add_theme_color_override("font_color", ThemeRef.TEXT)
	content.add_child(flavor_text)
	Layout.apply_frac(flavor_text, 0.14, 0.805, 0.72, 0.065)

	_bar_host = Control.new()
	_bar_host.name = "LoadingBar"
	content.add_child(_bar_host)
	Layout.apply_frac(_bar_host, 0.203, 0.855, 0.594, 0.13)

	_clip = Control.new()
	_clip.name = "ProgressClip"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_host.add_child(_clip)
	_clip.anchor_left = 0.0
	_clip.anchor_top = 0.0
	_clip.anchor_bottom = 1.0
	_clip.anchor_right = 0.12
	_clip.offset_left = 0
	_clip.offset_right = 0
	_clip.offset_top = 0
	_clip.offset_bottom = 0

	_reveal = TextureRect.new()
	_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reveal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reveal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_reveal.texture = Assets.texture(ZAssets.LOADING_BAR)
	_clip.add_child(_reveal)
	progress_fill = _clip
	_bar_host.resized.connect(_sync_reveal_size)
	call_deferred("_sync_reveal_size")
	set_progress(0.12)


func _sync_reveal_size() -> void:
	if _reveal == null or _bar_host == null:
		return
	_reveal.size = _bar_host.size
	_reveal.position = Vector2.ZERO


func set_progress(amount: float) -> void:
	if _clip == null:
		return
	_clip.anchor_right = lerpf(0.10, 1.0, clampf(amount, 0.0, 1.0))
	_sync_reveal_size()


func _unhandled_input(event: InputEvent) -> void:
	if not _busy and not embedded:
		return
	if event.is_pressed():
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _busy:
		return
	_elapsed += delta
	set_progress(clampf(_elapsed / maxf(duration, 0.2), 0.0, 1.0))
	if _elapsed >= duration:
		_complete()


func _complete() -> void:
	if not _busy:
		return
	_busy = false
	set_process(false)
	finished.emit(_mode_id, _context)
