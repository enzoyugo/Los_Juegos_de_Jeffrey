class_name KapesPauseOverlay
extends Control

const UILayout := preload("res://scripts/ui/kapes_ui_layout.gd")

signal resume_pressed
signal restart_pressed
signal menu_pressed

var _panel: KapesPanel

func _ready() -> void:
	UILayout.bind_full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.84)
	UILayout.bind_full_rect(dim)
	dim.focus_mode = Control.FOCUS_NONE
	add_child(dim)
	_panel = KapesPanel.new()
	_panel.accent_color = KapesVisual.GOLD
	add_child(_panel)
	resized.connect(_apply_layout)
	_apply_layout()
	call_deferred("_build_content")
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, KapesVisual.FAST_MOTION)

func _build_content() -> void:
	var title := _label("PAUSA", 56, KapesVisual.GOLD, Vector2(70, 48))
	var subtitle := _label("SMASH KAPES", 18, Color("#c47a5a"), Vector2(76, 118))
	var resume := _button("CONTINUAR", Vector2(70, 200), Vector2(570, 78), 30)
	resume.pressed.connect(func(): resume_pressed.emit())
	resume.grab_focus()
	var restart := _button("REINICIAR", Vector2(70, 300), Vector2(270, 62), 24)
	restart.pressed.connect(func(): restart_pressed.emit())
	var menu := _button("VOLVER AL HUB", Vector2(370, 300), Vector2(270, 62), 22)
	menu.pressed.connect(func(): menu_pressed.emit())
	var Hint := preload("res://scripts/ui/jeffrey/components/jeffrey_input_hint.gd")
	var hints := HBoxContainer.new()
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.add_theme_constant_override("separation", 16)
	hints.position = Vector2(70, 400)
	hints.size = Vector2(570, 36)
	_panel.add_child(hints)
	hints.add_child(Hint.make("confirm", "Continuar", KapesVisual.GOLD))
	hints.add_child(Hint.make("back", "Hub", KapesVisual.MUTED))
	hints.add_child(Hint.make("attack", "Ataque", KapesVisual.P1_COLOR))
	hints.add_child(Hint.make("jump", "Salto", KapesVisual.P2_COLOR))

func _apply_layout() -> void:
	var safe := UILayout.safe_rect(get_viewport())
	var panel_w := minf(800.0 * UILayout.scale_factor(get_viewport()), safe.size.x * 0.72)
	var panel_h := minf(560.0 * UILayout.scale_factor(get_viewport()), safe.size.y * 0.72)
	_panel.size = Vector2(panel_w, panel_h)
	_panel.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - panel_w * 0.5,
		safe.position.y + safe.size.y * 0.5 - panel_h * 0.5
	)

func _label(text: String, design_size: int, color: Color, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", UILayout.font_size(get_viewport(), design_size))
	label.add_theme_color_override("font_color", color)
	label.focus_mode = Control.FOCUS_NONE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(label)
	return label

func _button(text: String, pos: Vector2, size: Vector2, design_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.focus_mode = Control.FOCUS_ALL
	KapesVisual.apply_button_theme(button, UILayout.font_size(get_viewport(), design_size))
	_panel.add_child(button)
	return button
