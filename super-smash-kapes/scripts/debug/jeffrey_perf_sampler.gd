class_name JeffreyPerfSampler
extends RefCounted

## Lightweight frame/memory sampler for Jeffrey perf diagnostics.
## Not for continuous production use — call from debug labs only.

const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")


static func snapshot(tag: String = "") -> Dictionary:
	var fps := float(Performance.get_monitor(Performance.TIME_FPS))
	var frame_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var static_mb := float(OS.get_static_memory_usage()) / 1048576.0
	var peak_mb := float(OS.get_static_memory_peak_usage()) / 1048576.0
	var tex_mb := float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576.0
	return {
		"tag": tag,
		"fps": fps,
		"frame_ms": frame_ms,
		"physics_ms": physics_ms,
		"draw_calls": draw_calls,
		"objects": objects,
		"nodes": nodes,
		"orphans": orphans,
		"static_mb": static_mb,
		"peak_mb": peak_mb,
		"tex_mb": tex_mb,
		"gpu": str(RenderingServer.get_video_adapter_name()),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
	}


static func summarize(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {}
	var fps_vals: Array[float] = []
	var frame_vals: Array[float] = []
	for row in samples:
		if row is Dictionary:
			fps_vals.append(float(row.get("fps", 0.0)))
			frame_vals.append(float(row.get("frame_ms", 0.0)))
	fps_vals.sort()
	frame_vals.sort()
	var n := fps_vals.size()
	var fps_avg := 0.0
	var frame_avg := 0.0
	for i in n:
		fps_avg += fps_vals[i]
		frame_avg += frame_vals[i]
	fps_avg /= float(n)
	frame_avg /= float(n)
	var p1_idx := maxi(int(floorf(float(n) * 0.01)), 0)
	return {
		"samples": n,
		"fps_avg": fps_avg,
		"fps_1pct_low": fps_vals[p1_idx] if n > 0 else 0.0,
		"fps_min": fps_vals[0] if n > 0 else 0.0,
		"frame_ms_avg": frame_avg,
		"frame_ms_max": frame_vals[n - 1] if n > 0 else 0.0,
		"static_mb": samples[n - 1].get("static_mb", 0.0) if n > 0 else 0.0,
		"peak_mb": samples[n - 1].get("peak_mb", 0.0) if n > 0 else 0.0,
		"nodes": samples[n - 1].get("nodes", 0) if n > 0 else 0,
		"draw_calls_avg": _avg_int(samples, "draw_calls"),
	}


static func _avg_int(samples: Array, key: String) -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for row in samples:
		if row is Dictionary:
			total += float(row.get(key, 0))
	return total / float(samples.size())


static func print_line(prefix: String, row: Dictionary) -> void:
	print(
		"%s scenario=%s fps=%.1f frame_ms=%.2f physics_ms=%.2f draw=%d nodes=%d static=%.1fMB peak=%.1fMB orphans=%d"
		% [
			prefix,
			str(row.get("scenario", row.get("tag", "?"))),
			float(row.get("fps_avg", row.get("fps", 0.0))),
			float(row.get("frame_ms_avg", row.get("frame_ms", 0.0))),
			float(row.get("physics_ms", 0.0)),
			int(row.get("draw_calls_avg", row.get("draw_calls", 0))),
			int(row.get("nodes", 0)),
			float(row.get("static_mb", 0.0)),
			float(row.get("peak_mb", 0.0)),
			int(row.get("orphans", 0)),
		]
	)
