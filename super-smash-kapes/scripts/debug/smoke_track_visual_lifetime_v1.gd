extends Node

## 50 Hotseat-style visual spawn/free cycles. Expect bounded live_visuals=1.

const Visual := preload("res://scripts/track/track_car_visual.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/track/TrackCarWheelPhysics.tscn") as PackedScene
	if packed == null:
		print("[TRACK_VISUAL_LIFE] FAIL missing car")
		get_tree().quit(1)
		return
	var max_live := 0
	var last := 0
	for i in 50:
		var car = packed.instantiate()
		add_child(car)
		await get_tree().process_frame
		last = Visual.live_visuals()
		max_live = maxi(max_live, last)
		print("[TRACK_VISUAL_LIFE] attempt=%d live=%d ghost=%d" % [i + 1, last, Visual.ghost_visuals()])
		car.free()
		await get_tree().process_frame
		last = Visual.live_visuals()
	print("[TRACK_VISUAL_LIFE] DONE max_live=%d final_live=%d ghost=%d" % [max_live, last, Visual.ghost_visuals()])
	var leak := last > 1 or max_live > 2
	get_tree().quit(1 if leak else 0)
