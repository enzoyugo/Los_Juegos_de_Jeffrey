class_name ActivePlayerRow
extends Control

## One Hub roster line. Name sits in the painted nameplate.
## Slot badges P1–P6 are already in the panel art — do not redraw them.

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")


func setup(display_name: String, slot_index: int, portrait_path: String = "") -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, Styles.ACTIVE_ROW_HEIGHT)
	var avatar_slot := Control.new()
	avatar_slot.name = "AvatarSlot"
	avatar_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(avatar_slot)
	Layout.bind_frac_rect(avatar_slot, Styles.HUB_AVATAR_LEFT, 0.12, Styles.HUB_AVATAR_RIGHT, 0.88)
	if not portrait_path.is_empty():
		var tex := Assets.texture(portrait_path)
		if tex != null:
			var photo := TextureRect.new()
			photo.texture = tex
			photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			Layout.bind_full(photo)
			avatar_slot.add_child(photo)
	var name_zone := Control.new()
	name_zone.name = "NameSafeZone"
	name_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_zone.clip_contents = true
	add_child(name_zone)
	Layout.bind_frac_rect(name_zone, Styles.HUB_NAME_LEFT, 0.18, Styles.HUB_NAME_RIGHT, 0.82)
	var name_label := Layout.outlined_label(display_name.to_upper(), Styles.SIZE_PROFILE, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.name = "NameLabel"
	Styles.apply(name_label, "profile")
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Layout.bind_full(name_label)
	name_zone.add_child(name_label)
	var badge_zone := Control.new()
	badge_zone.name = "SlotBadgeSafeZone"
	badge_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge_zone)
	Layout.bind_frac_rect(badge_zone, 0.74, 0.20, 0.96, 0.80)
	var badge := Layout.outlined_label("P%d" % (slot_index + 1), Styles.SIZE_BADGE, ThemeRef.slot_color(slot_index), HORIZONTAL_ALIGNMENT_CENTER)
	badge.name = "SlotBadge"
	badge.custom_minimum_size = Vector2(Styles.SLOT_BADGE_WIDTH, 28)
	badge.visible = false
	Layout.bind_full(badge)
	badge_zone.add_child(badge)
