class_name GlobalShellTheme
extends RefCounted

## Neutral placeholder identity for Los Juegos de Jeffrey.
## Swap colors/type later without rewriting screens.
## Smash Paraguay / stadium palette lives in SmashShellTheme, not here.

const BG_TOP := Color("#07080c")
const BG_BOTTOM := Color("#12151c")
const SURFACE := Color("#1a1e27")
const SURFACE_ALT := Color("#222734")
const STROKE := Color("#3a4150")
const TEXT := Color("#e8eaef")
const MUTED := Color("#8b93a7")
const ACCENT := Color("#9eb4c9")
const GOLD := Color("#e8b84a")
const GOLD_HOT := Color("#ffcc33")
const DANGER := Color("#d36b6b")
const OK := Color("#7dba8a")
const SLOT_COLORS: Array[Color] = [
	Color("#d94a4a"),
	Color("#3d7ed9"),
	Color("#e0c14a"),
	Color("#4caf63"),
	Color("#8a5ad9"),
	Color("#e0893a"),
	Color("#3db8c9"),
	Color("#e07ab0"),
	Color("#f2f2f2"),
	Color("#8a8a8a"),
]

const SIZE_GAME_TITLE := 56
const SIZE_SCREEN_TITLE := 42
const SIZE_MODE_TITLE := 28
const SIZE_SECTION := 14
const SIZE_PLAYER := 22
const SIZE_HELPER := 16
const SIZE_STATUS := 13
const SIZE_BODY := 18

const MARGIN := 0.045
const FOOTER_HEIGHT := 96.0
const CARD_RADIUS := 10.0

const PROFILE_COLORS: Array[Color] = [
	Color("#c47a5a"),
	Color("#6a9cc4"),
	Color("#c4b05a"),
	Color("#7aaf7a"),
	Color("#b07ac4"),
	Color("#c47a9a"),
	Color("#5aa8b0"),
	Color("#c48a5a"),
	Color("#8a9ab8"),
	Color("#a8c47a"),
]


static func slot_color(index: int) -> Color:
	if SLOT_COLORS.is_empty():
		return ACCENT
	var wrapped: int = posmod(index, SLOT_COLORS.size())
	return SLOT_COLORS[wrapped]


static func profile_color(profile_id: String) -> Color:
	if profile_id.is_empty():
		return ACCENT
	var hash := 0
	for i in profile_id.length():
		hash = (hash * 31 + profile_id.unicode_at(i)) % 2147483647
	return PROFILE_COLORS[hash % PROFILE_COLORS.size()]


static func initials(display_name: String) -> String:
	var trimmed := display_name.strip_edges()
	if trimmed.is_empty():
		return "?"
	var parts := trimmed.split(" ", false)
	if parts.size() >= 2:
		return (str(parts[0])[0] + str(parts[1])[0]).to_upper()
	return trimmed.substr(0, mini(2, trimmed.length())).to_upper()
