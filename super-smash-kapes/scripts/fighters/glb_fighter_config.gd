extends Resource

## Body height measurement mode for canonical sizing.
## FULL: use full mesh AABB height
## IGNORE_TOP: drop top ratio (e.g. Tereré bombilla)
## BODY_FRACTION: keep bottom fraction of AABB height (exclude tall extras)

const BODY_MEASURE_FULL := "FULL"
const BODY_MEASURE_IGNORE_TOP := "IGNORE_TOP"
const BODY_MEASURE_FRACTION := "BODY_FRACTION"

@export var glb_path: String = ""
@export var fallback_visual_script: Script
@export var fallback_visual_path: String = ""
@export var size_class: String = "MEDIUM"
@export var target_visual_height: float = 2.75
@export var body_measure_mode: String = BODY_MEASURE_FRACTION
@export var fit_ignore_top_ratio: float = 0.0
@export var body_height_fraction: float = 1.0
@export var body_anchor_y_fraction: float = 0.42
@export var horizontal_anchor_fraction: float = 0.5
@export var ground_anchor: float = 0.0
## Semantic V2 only. Applied on ImportCorrectionRoot as Ry * Rx * Rz (pitch then yaw).
## Production V4 must leave these at 0 and keep model_yaw_offset on ModelRoot.
@export var import_correction_pitch_deg: float = 0.0
@export var import_correction_yaw_deg: float = 0.0
@export var import_correction_roll_deg: float = 0.0
@export var model_pitch_offset: float = 0.0
@export var model_yaw_offset: float = 0.0
@export var extra_offset: Vector3 = Vector3.ZERO
@export var shadow_enabled: bool = true
@export var shadow_width: float = 1.1
@export var shadow_depth: float = 0.55
