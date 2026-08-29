class_name TrackPieceGeometryContractV1
extends Resource

## Canonical connector and metadata contract for generated Track modules.
## Logical generator pieces stay in TrackGenerator. This resource describes
## visual/runtime modules that an adapter may attach later.

const FORWARD := Vector3(0.0, 0.0, -1.0)
const UP := Vector3(0.0, 1.0, 0.0)
const ROAD_WIDTH := 11.0
const SHOULDER_WIDTH := 0.7
const GUARDRAIL_HEIGHT := 0.9

@export var piece_id: String = ""
@export var piece_family: String = "core"
@export var road_width: float = ROAD_WIDTH
@export var shoulder_width: float = SHOULDER_WIDTH
@export var centerline_length: float = 0.0
@export var height_delta: float = 0.0
@export var yaw_delta: float = 0.0
@export var pitch_delta: float = 0.0
@export var roll_delta: float = 0.0
@export var left_guardrail: bool = true
@export var right_guardrail: bool = true
@export var estimated_traversal_time: float = 0.5
@export var difficulty: String = "tranqui"
@export var recommended_speed: float = 28.0
@export var tags: PackedStringArray = PackedStringArray()
@export var boost_strength: float = 0.0

## ENTRY at local origin. EXIT must align to the next piece ENTRY.
@export var entry_up: Vector3 = UP
@export var entry_forward: Vector3 = FORWARD
@export var exit_up: Vector3 = UP
@export var exit_forward: Vector3 = FORWARD
