class_name JeffreyModal
extends Control

signal closed

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const Motion := preload("res://scripts/ui/jeffrey/system/jeffrey_ui_motion.gd")
const JeffreyBtn := preload("res://scripts/ui/jeffrey/components/jeffrey_button.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

var _panel: Panel
var _content: VBoxContainer
var _focus_cancel: bool = true


func _ready() -> void:
	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Layout.bind_full(self)
	var wash := ColorRect.new()
	wash.color = Color(0, 0, 0, 0.78)
	Layout.bind_full(wash)
	add_child(wash)
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", ThemeRef.panel_style())
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", ThemeRef.SPACE_MD)
	Layout.bind_full(_content)
	_content.offset_left = ThemeRef.SPACE_LG
	_content.offset_top = ThemeRef.SPACE_LG
	_content.offset_right = -ThemeRef.SPACE_LG
	_content.offset_bottom = -ThemeRef.SPACE_LG
	_panel.add_child(_content)
	Motion.modal_pop(_panel)
	AudioHooks.play_modal_open(self)


func configure_dialog(
	title: String,
	body: String,
	primary_text: String,
	secondary_text: String,
	on_primary: Callable,
	on_secondary: Callable,
	destructive: bool = false,
	focus_secondary: bool = true,
	panel_size: Vector2 = Vector2(560, 260)
) -> void:
	_focus_cancel = focus_secondary
	_panel.custom_minimum_size = panel_size
	_panel.offset_left = -panel_size.x * 0.5
	_panel.offset_top = -panel_size.y * 0.5
	_panel.offset_right = panel_size.x * 0.5
	_panel.offset_bottom = panel_size.y * 0.5
	var title_label := Layout.outlined_label(title, ThemeRef.Base.SIZE_MODE_TITLE, ThemeRef.Base.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(title_label)
	var body_label := Layout.outlined_label(body, ThemeRef.Base.SIZE_BODY, ThemeRef.Base.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(body_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", ThemeRef.SPACE_MD)
	_content.add_child(actions)
	var cancel = JeffreyBtn.new()
	cancel.configure(secondary_text, JeffreyBtn.Kind.SECONDARY, ThemeRef.BTN_PRIMARY)
	cancel.pressed.connect(func():
		AudioHooks.play_back(self)
		if on_secondary.is_valid():
			on_secondary.call()
		_close()
	)
	actions.add_child(cancel)
	var confirm_btn = JeffreyBtn.new()
	var kind := JeffreyBtn.Kind.DANGER if destructive else JeffreyBtn.Kind.PRIMARY
	confirm_btn.configure(primary_text, kind, ThemeRef.BTN_PRIMARY)
	confirm_btn.pressed.connect(func():
		AudioHooks.play_confirm(self)
		if on_primary.is_valid():
			on_primary.call()
		_close()
	)
	actions.add_child(confirm_btn)
	call_deferred("_focus_button", cancel if focus_secondary else confirm_btn)


func content_box() -> VBoxContainer:
	return _content


func _focus_button(button: Button) -> void:
	if button != null and is_instance_valid(button):
		button.grab_focus()


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		AudioHooks.play_back(self)
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()
