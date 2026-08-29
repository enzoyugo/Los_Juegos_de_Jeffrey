## DEPRECATED — experimental runtime Mixamo idle binder.
## Production uses offline-baked `jaguarete_game_ready_idle.glb`.
## Kept for research only. Do not use in normal gameplay.
extends RefCounted

const IDLE_FBX := "res://assets/fighters/animations/Idle.fbx"

const BONE_MAP := {
	"mixamorig5_Hips": "Hip",
	"mixamorig5_Spine": "Waist",
	"mixamorig5_Spine1": "Spine01",
	"mixamorig5_Spine2": "Spine02",
	"mixamorig5_Neck": "NeckTwist01",
	"mixamorig5_Head": "Head",
	"mixamorig5_LeftShoulder": "L_Clavicle",
	"mixamorig5_LeftArm": "L_Upperarm",
	"mixamorig5_LeftForeArm": "L_Forearm",
	"mixamorig5_LeftHand": "L_Hand",
	"mixamorig5_RightShoulder": "R_Clavicle",
	"mixamorig5_RightArm": "R_Upperarm",
	"mixamorig5_RightForeArm": "R_Forearm",
	"mixamorig5_RightHand": "R_Hand",
	"mixamorig5_LeftUpLeg": "L_Thigh",
	"mixamorig5_LeftLeg": "L_Calf",
	"mixamorig5_LeftFoot": "L_Foot",
	"mixamorig5_LeftToeBase": "L_ToeBase",
	"mixamorig5_RightUpLeg": "R_Thigh",
	"mixamorig5_RightLeg": "R_Calf",
	"mixamorig5_RightFoot": "R_Foot",
	"mixamorig5_RightToeBase": "R_ToeBase",
}

static func bind_idle(skeleton: Skeleton3D, model_root: Node3D) -> AnimationPlayer:
	push_warning("[JAG_RIG][DEPRECATED] runtime idle binder called — use baked GLB instead")
	return null
