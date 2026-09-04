extends Node3D

## Isolated adapter contract. The canonical post-fix driver remains untouched.
## This wrapper is the only S019-owned bridge for mapping Pharos route data.
const CANONICAL_DRIVER_PATH := "res://scripts/debug/track_autonomous_runtime_validation_v1.gd"
const PHAROS_ROOT := "res://tests/integration/pharos_track_s018"
const TRACKS := {"SHORT":"S016_SHORT_SEED_1601.glb","MEDIUM":"S016_MEDIUM_SEED_1602.glb","LONG":"S016_LONG_SEED_1603.glb"}
var adapter_status := "CONTRACT_ONLY_NOT_RUN"
func _ready() -> void:
 var requested := OS.get_environment("PHAROS_S019_TRACK").to_upper()
 if not TRACKS.has(requested):
  adapter_status = "BLOCKED_CONFIG"
  push_error("PHAROS_S019_TRACK must be SHORT, MEDIUM, or LONG")
  get_tree().quit(2)
  return
 adapter_status = "READY_FOR_CANONICAL_DRIVER_BINDING"
 print("[PHAROS_S019_ADAPTER] canonical=%s track=%s glb=%s" % [CANONICAL_DRIVER_PATH,requested,PHAROS_ROOT+"/"+TRACKS[requested]])
 ## TrackRace.build() emits solids/checkpoints; Pharos GLBs currently do not.
 ## Binding is pending explicit route/checkpoint extraction. No teleport,
 ## transform advance, substitute collider, or production edits are allowed.
 get_tree().quit(0)
