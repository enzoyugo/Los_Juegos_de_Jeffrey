class_name KapesLayers
extends RefCounted

# Explicit viewport draw order. Negative layers render behind the 3D world;
# positive layers render in front. Do not reuse values for unrelated UI.
const BACKGROUND := -20
const STADIUM_MID := -10
const FOREGROUND := 5
const HUD := 10
const MATCH_INTRO := 20
const MENU_UI := 30
const TRANSITION := 40
