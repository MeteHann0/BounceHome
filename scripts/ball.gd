extends RigidBody2D

@export var ball_radius: float = 15.0

var _wind_time: float = 0.0

func _process(delta: float):
	_wind_time += delta
	queue_redraw()

func _draw():
	if freeze or not visible:
		return
	if get_parent() and not bool(get_parent().get("ball_in_flight")):
		return

	var spd := linear_velocity.length()
	if spd < 50.0:
		return

	var intensity := clampf((spd - 50.0) / 340.0, 0.0, 1.0)
	# Top kendi etrafında döndüğü için hız yönünü yerel koordinata (-rotation) çevir
	var back_dir := (-linear_velocity.normalized()).rotated(-rotation)
	var side_dir := Vector2(-back_dir.y, back_dir.x)

	# Topun iki yanından (kenarlarından) geriye doğru akan küçük rüzgar/süzülme çizgileri
	var offsets := [
		{"side": -1.0, "dist": 17.5, "phase": 0.0, "len": 16.0},
		{"side": 1.0, "dist": 17.5, "phase": 0.45, "len": 16.0},
		{"side": -1.0, "dist": 22.0, "phase": 0.25, "len": 12.0},
		{"side": 1.0, "dist": 22.0, "phase": 0.70, "len": 12.0},
		{"side": -0.55, "dist": 15.0, "phase": 0.85, "len": 14.0},
		{"side": 0.55, "dist": 15.0, "phase": 0.15, "len": 14.0},
	]

	for i in range(offsets.size()):
		var item: Dictionary = offsets[i]
		var s_sign: float = item["side"]
		var s_dist: float = item["dist"]
		var ph: float = item["phase"]
		var base_len: float = item["len"]

		var cycle := fmod(_wind_time * (2.6 + intensity * 2.2) + ph, 1.0)
		var slide := lerpf(-8.0, 18.0, cycle)
		var alpha := sin(cycle * PI) * (0.28 + 0.48 * intensity)
		var line_len := base_len * (0.65 + 0.65 * intensity) * sin(cycle * PI)

		var start_pt := side_dir * (s_sign * s_dist) + back_dir * slide
		var end_pt := start_pt + back_dir * line_len
		draw_line(start_pt, end_pt, Color(0.95, 0.98, 1.0, alpha), 1.8, true)
