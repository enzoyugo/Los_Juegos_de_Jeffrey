## DEPRECATED — experimental runtime Mixamo retarget.
## Production uses offline Blender bake. Research only.
class_name MixamoJaguareteRetarget
extends RefCounted

static func retarget_animation(_source: Animation, _skel_path: NodePath) -> Animation:
	push_warning("[JAG_RIG][DEPRECATED] runtime Mixamo retarget called — use baked GLB instead")
	return Animation.new()
