class_name ShellAssets
extends RefCounted

## Central swap table for Los Juegos de Jeffrey shell art.
## Drop files in these paths later; screens already read through these helpers.

const BACKGROUND := "res://assets/ui/global/shell_background.png"
const LOGO := "res://assets/ui/global/logo.png"
const MODE_SMASH := "res://assets/ui/global/mode_cards/smash.png"
const MODE_HOTSEAT := "res://assets/ui/global/mode_cards/hotseat.png"
const MODE_ZOMBIES := "res://assets/ui/global/mode_cards/zombies.png"

const MODE_ART := {
	"smash": MODE_SMASH,
	"racing": MODE_HOTSEAT,
	"zombies": MODE_ZOMBIES,
}


static func texture_or_null(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	if loaded is Texture2D:
		return loaded
	return null


static func mode_thumbnail(mode_id: String) -> Texture2D:
	var path: String = str(MODE_ART.get(mode_id, ""))
	return texture_or_null(path)


static func logo() -> Texture2D:
	return texture_or_null(LOGO)


static func background() -> Texture2D:
	return texture_or_null(BACKGROUND)
