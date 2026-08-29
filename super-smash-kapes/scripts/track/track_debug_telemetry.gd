class_name TrackDebugTelemetry
extends RefCounted

## Safe optional debug property access. Never crash HUD on null / missing fields.
## OPTIONAL_DEBUG_PROPERTY may default. REQUIRED_GAMEPLAY_PROPERTY must be explicit.


static func has_prop(obj, prop: String) -> bool:
	if obj == null:
		return false
	var v = obj.get(prop)
	return v != null


static func debug_int(obj, prop: String, default_value: int = 0) -> int:
	var v = _raw(obj, prop)
	if v == null:
		return default_value
	if v is int:
		return v
	if v is float:
		return int(v)
	if v is bool:
		return 1 if v else 0
	return default_value


static func debug_float(obj, prop: String, default_value: float = 0.0) -> float:
	var v = _raw(obj, prop)
	if v == null:
		return default_value
	if v is float:
		return v
	if v is int:
		return float(v)
	if v is bool:
		return 1.0 if v else 0.0
	return default_value


static func debug_bool(obj, prop: String, default_value: bool = false) -> bool:
	var v = _raw(obj, prop)
	if v == null:
		return default_value
	if v is bool:
		return v
	if v is int:
		return v != 0
	if v is float:
		return v != 0.0
	return default_value


static func debug_string(obj, prop: String, default_value: String = "") -> String:
	var v = _raw(obj, prop)
	if v == null:
		return default_value
	var s := str(v)
	if s.is_empty() or s == "<null>":
		return default_value
	return s


static func required_float(obj, prop: String) -> float:
	var v = _raw(obj, prop)
	assert(v != null, "REQUIRED_GAMEPLAY_PROPERTY missing: %s" % prop)
	return float(v)


static func dict_int(d: Dictionary, key: String, default_value: int = 0) -> int:
	if not d.has(key):
		return default_value
	return debug_int(d, key, default_value)


static func dict_float(d: Dictionary, key: String, default_value: float = 0.0) -> float:
	if not d.has(key):
		return default_value
	return debug_float(d, key, default_value)


static func _raw(obj, prop: String):
	if obj == null:
		return null
	return obj.get(prop)
