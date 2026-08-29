extends Control

## Jeffrey UI System V1 review lab — not runtime authority.

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const JeffreyBtn := preload("res://scripts/ui/jeffrey/components/jeffrey_button.gd")
const ScoreRow := preload("res://scripts/ui/jeffrey/components/jeffrey_score_row.gd")
const Chip := preload("res://scripts/ui/jeffrey/components/jeffrey_player_chip.gd")
const PanelScript := preload("res://scripts/ui/jeffrey/components/jeffrey_panel.gd")
const TitleScript := preload("res://scripts/ui/jeffrey/components/jeffrey_title.gd")
const ModalScript := preload("res://scripts/ui/jeffrey/components/jeffrey_modal.gd")

var _stack: VBoxContainer


func _ready() -> void:
	Layout.bind_full(self)
	var bg := ColorRect.new()
	bg.color = Color("#07080c")
	Layout.bind_full(bg)
	add_child(bg)
	var scroll := ScrollContainer.new()
	Layout.bind_full(scroll)
	add_child(scroll)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 18)
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stack)
	_build()


func _build() -> void:
	var title = TitleScript.new()
	title.configure("JEFFREY UI SYSTEM V1 LAB", 1, HORIZONTAL_ALIGNMENT_LEFT)
	_stack.add_child(title)
	_add_section("Buttons")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_stack.add_child(row)
	for spec in [
		["PRIMARY", JeffreyBtn.Kind.PRIMARY],
		["SECONDARY", JeffreyBtn.Kind.SECONDARY],
		["DANGER", JeffreyBtn.Kind.DANGER],
	]:
		var btn = JeffreyBtn.new()
		btn.configure(spec[0], spec[1], ThemeRef.BTN_MIN)
		row.add_child(btn)
	_add_section("Player chip")
	var chip = Chip.new()
	chip.configure("p_lab", "ENZO", 0)
	chip.custom_minimum_size = Vector2(240, 40)
	_stack.add_child(chip)
	_add_section("Score rows")
	for i in range(1, 5):
		var score = ScoreRow.new()
		_stack.add_child(score)
		score.configure(i, ["ENZO", "JEFFREY", "JUAN", "TOMI"][i - 1], [5, 3, 2, 1][i - 1], 10 - i, i == 1, "p_%d" % i)
	_add_section("Mode accents")
	var accents := HBoxContainer.new()
	accents.add_theme_constant_override("separation", 10)
	_stack.add_child(accents)
	for mode_id in [ThemeRef.MODE_SMASH, ThemeRef.MODE_RACING, ThemeRef.MODE_ZOMBIES]:
		var panel = PanelScript.new()
		panel.configure(ThemeRef.mode_accent(mode_id), 0.9)
		panel.custom_minimum_size = Vector2(180, 64)
		accents.add_child(panel)
	_add_section("Modal trigger")
	var modal_btn = JeffreyBtn.new()
	modal_btn.configure("ABRIR MODAL DEMO", JeffreyBtn.Kind.PRIMARY, ThemeRef.BTN_PRIMARY)
	modal_btn.pressed.connect(_open_modal)
	_stack.add_child(modal_btn)
	print("[JEFFREY_UI_LAB] ready")


func _add_section(label: String) -> void:
	var t = TitleScript.new()
	t.configure(label, 2, HORIZONTAL_ALIGNMENT_LEFT)
	_stack.add_child(t)


func _open_modal() -> void:
	var modal = ModalScript.new()
	add_child(modal)
	modal.configure_dialog(
		"DEMO MODAL",
		"Modal de prueba del sistema Jeffrey UI.",
		"CONFIRMAR",
		"CANCELAR",
		Callable(),
		Callable(),
		false,
		true
	)
