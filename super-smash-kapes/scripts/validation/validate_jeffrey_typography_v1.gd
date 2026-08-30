extends SceneTree

const Typography := preload("res://scripts/ui/jeffrey/system/jeffrey_typography.gd")

const FONT_PATHS := [
	"res://assets/fonts/global/boorsok.ttf",
	"res://assets/fonts/track/Veter.ttf",
	"res://assets/fonts/zombies/Super Midnight.ttf",
	"res://assets/fonts/soco/JUMBOTRON.otf",
	"res://assets/fonts/soco/Super Crawler.ttf",
]
const REQUIRED_GLYPHS := "ÁÉÍÓÚÑÜáéíóúñü¿¡"
const ROOT_BINDINGS := {
	"global": "scripts/core/jeffrey/jeffrey_app.gd",
	"track": "scripts/track/track_hud.gd",
	"zombies": "scripts/zombies/zombies_hud.gd",
	"soco": "scripts/ui/kapes_player_hud.gd",
}

func _init() -> void:
	var failures: Array[String] = []
	for path in FONT_PATHS:
		if not ResourceLoader.exists(path) or load(path) == null:
			failures.append("missing or unloadable font: %s" % path)
	for mode in [Typography.GLOBAL, Typography.TRACK, Typography.ZOMBIES, Typography.SOCO]:
		var font := Typography.font_for(mode)
		for i in REQUIRED_GLYPHS.length():
			var code := REQUIRED_GLYPHS.unicode_at(i)
			if not Typography.supports_glyph(font, code):
				failures.append("%s missing glyph U+%04X" % [mode, code])
	for mode in ROOT_BINDINGS:
		var source_path: String = ROOT_BINDINGS[mode]
		var source := FileAccess.get_file_as_string("res://%s" % source_path)
		if source.is_empty() or not source.contains("Typography.%s" % mode.to_upper()):
			failures.append("root binding not found: %s -> %s" % [mode, source_path])
	if failures.is_empty():
		print("JEFFREY TYPOGRAPHY V1 PASS: %d fonts, %d modes, glyph set OK" % [FONT_PATHS.size(), ROOT_BINDINGS.size()])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("JEFFREY TYPOGRAPHY V1 FAIL: %d issue(s)" % failures.size())
		quit(1)
