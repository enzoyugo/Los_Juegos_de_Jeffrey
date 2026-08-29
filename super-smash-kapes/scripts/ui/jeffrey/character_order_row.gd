class_name CharacterOrderRow
extends HBoxContainer

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")


func setup(slot: int, person: String, character_name: String, current: bool) -> void:
	custom_minimum_size = Vector2(0, 44)
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var badge := Layout.outlined_label("P%d" % slot, Styles.SIZE_BADGE, ThemeRef.slot_color(slot - 1), HORIZONTAL_ALIGNMENT_CENTER)
	badge.custom_minimum_size = Vector2(Styles.SLOT_BADGE_WIDTH, 26)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(badge)
	var name_label := Layout.outlined_label(person.to_upper(), Styles.SIZE_HELPER, ThemeRef.GOLD if current else ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	Styles.apply(name_label, "status" if current else "profile")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(name_label)
	var arrow := Layout.outlined_label("→", Styles.SIZE_HELPER, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	arrow.custom_minimum_size = Vector2(18, 26)
	add_child(arrow)
	var kape := Layout.outlined_label(character_name.to_upper(), Styles.SIZE_HELPER, ThemeRef.GOLD_HOT if current else ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	kape.clip_text = true
	kape.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	kape.custom_minimum_size = Vector2(90, 26)
	add_child(kape)
