extends Node2D
## Mektup okunduktan sonra topun hemen sağ tarafına yukarıdan düşen hediye kutusu
## ve kutuya tıklandığında ortaya çıkan, fare ile taşınabilen Giriş / Çıkış portalları.

enum State {
	FALLING_BOX,
	WAITING_CLICK,
	OPENING_BOX,
	PORTALS_ACTIVE,
}

var _state: int = State.FALLING_BOX
var _time: float = 0.0

# Hediye kutusu değişkenleri
var _box_pos := Vector2(235.0, -45.0)
var _box_target_y := 590.0
var _box_open_t := 0.0

# Giriş ve Çıkış portal konumları
var _entry_pos := Vector2(310.0, 450.0)
var _exit_pos := Vector2(980.0, 410.0)
var _portal_radius := 28.0
var _portal_scale := 0.0

# Fare ile sürükleme durumu (0: yok, 1: giriş portalı, 2: çıkış portalı)
var _dragging_portal := 0
var _drag_offset := Vector2.ZERO

# Işınlanma soğuma süresi ve efektleri
var _teleport_cooldown := 0.0
var _entry_flash := 0.0
var _exit_flash := 0.0

var ball: RigidBody2D = null
var main_node: Node2D = null

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not main_node:
		main_node = get_parent() as Node2D
	if main_node and not ball:
		ball = main_node.get_node_or_null("Ball") as RigidBody2D

	# Hediye kutusu yukarıdan topun hemen sağ tarafına (x=235, y=590) daha yavaş düşsün ve hafifçe seksin
	var tween := create_tween()
	tween.tween_property(self, "_box_pos:y", _box_target_y, 1.8) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_state = State.WAITING_CLICK
	)

func _input(event: InputEvent):
	if get_tree().paused:
		_dragging_portal = 0
		return
	if is_instance_valid(main_node) and main_node.get("game_over") == true:
		_dragging_portal = 0
		return

	if _state == State.WAITING_CLICK:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_pos := get_global_mouse_position()
			if _box_pos.distance_to(mouse_pos) <= 38.0:
				get_viewport().set_input_as_handled()
				_open_gift_box()
		return

	if _state == State.PORTALS_ACTIVE:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos := get_global_mouse_position()
				# Topun kendisine tıklanıyorsa topu fırlatma öncelikli olsun
				if is_instance_valid(ball) and mouse_pos.distance_to(ball.global_position) < 34.0:
					return
				if mouse_pos.distance_to(_entry_pos) <= _portal_radius + 12.0:
					_dragging_portal = 1
					_drag_offset = _entry_pos - mouse_pos
					get_viewport().set_input_as_handled()
				elif mouse_pos.distance_to(_exit_pos) <= _portal_radius + 12.0:
					_dragging_portal = 2
					_drag_offset = _exit_pos - mouse_pos
					get_viewport().set_input_as_handled()
			else:
				if _dragging_portal != 0:
					_dragging_portal = 0
					get_viewport().set_input_as_handled()

		elif event is InputEventMouseMotion and _dragging_portal != 0:
			var mouse_pos := get_global_mouse_position() + _drag_offset
			var clamped := Vector2(
				clampf(mouse_pos.x, 55.0, 1225.0),
				clampf(mouse_pos.y, 55.0, 575.0)
			)
			if _dragging_portal == 1:
				_entry_pos = clamped
			elif _dragging_portal == 2:
				_exit_pos = clamped
			queue_redraw()
			get_viewport().set_input_as_handled()

func _open_gift_box():
	_state = State.OPENING_BOX
	_box_open_t = 0.0
	_entry_pos = _box_pos + Vector2(0.0, -25.0)
	_exit_pos = _box_pos + Vector2(30.0, -25.0)
	_portal_scale = 0.1

	var tween := create_tween()
	tween.tween_property(self, "_box_open_t", 1.0, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_state = State.PORTALS_ACTIVE
		var ptween := create_tween()
		ptween.set_parallel(true)
		ptween.tween_property(self, "_portal_scale", 1.0, 0.38) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ptween.tween_property(self, "_entry_pos", Vector2(315.0, 440.0), 0.42) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ptween.tween_property(self, "_exit_pos", Vector2(960.0, 410.0), 0.48) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

func _physics_process(delta: float):
	_time += delta
	if _teleport_cooldown > 0.0:
		_teleport_cooldown -= delta
	if _entry_flash > 0.0:
		_entry_flash = move_toward(_entry_flash, 0.0, delta * 2.8)
	if _exit_flash > 0.0:
		_exit_flash = move_toward(_exit_flash, 0.0, delta * 2.8)

	if _state == State.PORTALS_ACTIVE and _portal_scale > 0.8 and _teleport_cooldown <= 0.0:
		if is_instance_valid(ball) and not ball.freeze:
			var shot_active := true
			if is_instance_valid(main_node) and int(main_node.get("shot_count")) == 0:
				shot_active = false
			if shot_active and ball.global_position.distance_to(_entry_pos) <= _portal_radius + 13.0:
				_teleport_ball()

	queue_redraw()

func _teleport_ball():
	_teleport_cooldown = 0.45
	_entry_flash = 1.0
	_exit_flash = 1.0

	var vel := ball.linear_velocity
	var speed := maxf(vel.length(), 300.0)
	var dir := vel.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	ball.global_position = _exit_pos + dir * 18.0
	ball.linear_velocity = dir * speed

func _draw():
	if _state == State.FALLING_BOX or _state == State.WAITING_CLICK or _state == State.OPENING_BOX:
		_draw_gift_box()
	if _state == State.PORTALS_ACTIVE:
		_draw_portals()

func _draw_gift_box():
	var pos := _box_pos
	if _state == State.WAITING_CLICK:
		pos.y += sin(_time * 5.0) * 2.2

	var bw := 38.0
	var bh := 34.0
	var hw := bw * 0.5
	var hh := bh * 0.5
	var alpha := clampf(1.0 - _box_open_t * 0.9, 0.0, 1.0)

	# Hediye kutusu etrafındaki parıltı
	var glow_r := 32.0 + sin(_time * 6.0) * 3.5
	draw_circle(pos, glow_r, Color(1.0, 0.82, 0.32, 0.25 * alpha))

	# Kutu gövdesi (kırmızı-mercan hediye paketi ve altın kurdele)
	var box_rect := Rect2(pos.x - hw, pos.y - hh, bw, bh)
	draw_rect(box_rect, Color(0.88, 0.2, 0.26, alpha))
	draw_rect(Rect2(pos.x - hw, pos.y - hh, bw * 0.5, bh), Color(0.95, 0.28, 0.34, alpha))
	# Dikey ve yatay altın kurdele
	draw_rect(Rect2(pos.x - 4.0, pos.y - hh, 8.0, bh), Color(1.0, 0.84, 0.25, alpha))
	draw_rect(Rect2(pos.x - hw, pos.y - 3.5, bw, 7.0), Color(1.0, 0.84, 0.25, alpha))
	draw_rect(box_rect, Color(0.45, 0.08, 0.12, alpha), false, 2.0)

	# Kutu kapağı ve fiyonk (açılırken yukarı fırlar)
	var lid_offset_y := -_box_open_t * 28.0
	var lid_pos := Vector2(pos.x, pos.y - hh - 3.0 + lid_offset_y)
	var lid_rect := Rect2(lid_pos.x - hw - 3.0, lid_pos.y - 4.0, bw + 6.0, 9.0)
	draw_rect(lid_rect, Color(0.96, 0.25, 0.32, alpha))
	draw_rect(Rect2(lid_pos.x - 4.5, lid_pos.y - 4.0, 9.0, 9.0), Color(1.0, 0.88, 0.32, alpha))
	draw_rect(lid_rect, Color(0.45, 0.08, 0.12, alpha), false, 1.8)

	# Üst altın fiyonk halkaları
	draw_circle(lid_pos + Vector2(-6.5, -6.5), 5.0, Color(1.0, 0.84, 0.22, alpha))
	draw_circle(lid_pos + Vector2(6.5, -6.5), 5.0, Color(1.0, 0.84, 0.22, alpha))
	draw_circle(lid_pos + Vector2(0.0, -5.5), 3.2, Color(0.95, 0.68, 0.12, alpha))

	# Kutu açılırken çıkan parıltı kıvılcımları
	if _state == State.OPENING_BOX:
		for i in range(8):
			var a := i * (TAU / 8.0) + _box_open_t * 1.5
			var sp := pos + Vector2(cos(a), sin(a)) * (12.0 + _box_open_t * 36.0)
			draw_circle(sp, lerpf(5.0, 1.2, _box_open_t), Color(0.35, 0.95, 1.0, alpha))

func _draw_portals():
	var r := _portal_radius * _portal_scale
	if r <= 1.0:
		return

	# Giriş ve Çıkış portalları arasındaki hafif kesikli enerji bağı
	var diff := _exit_pos - _entry_pos
	var dist := diff.length()
	if dist > r * 2.4:
		var dir := diff / dist
		var steps := int((dist - r * 2.2) / 24.0)
		for i in range(steps):
			var p1 := _entry_pos + dir * (r * 1.15 + i * 24.0 + fmod(_time * 42.0, 24.0))
			if p1.distance_to(_exit_pos) > r * 1.15:
				draw_circle(p1, 2.2, Color(0.65, 0.85, 1.0, 0.32))

	# 1. GİRİŞ PORTALI (Mavi - Turkuaz girdap)
	_draw_single_portal(
		_entry_pos,
		r,
		Color("#00E5FF"),
		Color("#1565C0"),
		Color("#081B3A"),
		1.0,
		_entry_flash
	)

	# 2. ÇIKIŞ PORTALI (Turuncu - Altın girdap)
	_draw_single_portal(
		_exit_pos,
		r,
		Color("#FFAB00"),
		Color("#E65100"),
		Color("#3A1205"),
		-1.0,
		_exit_flash
	)

func _draw_single_portal(pos: Vector2, r: float, bright_col: Color, mid_col: Color, core_col: Color, spin_dir: float, flash: float):
	var pulse := 1.0 + sin(_time * 5.5) * 0.06 + flash * 0.32
	var pr := r * pulse

	# Dış enerji هاله (glow)
	draw_circle(pos, pr * 1.42, Color(bright_col.r, bright_col.g, bright_col.b, 0.22 + flash * 0.3))
	draw_circle(pos, pr * 1.12, mid_col)
	draw_circle(pos, pr * 0.86, bright_col)
	draw_circle(pos, pr * 0.62, core_col)

	# Dönen spiral enerji kolları
	for i in range(4):
		var base_a := _time * 4.2 * spin_dir + i * (TAU / 4.0)
		draw_arc(pos, pr * 0.74, base_a, base_a + 1.05, 10, Color(1.0, 1.0, 1.0, 0.85), 2.4)
		draw_arc(pos, pr * 0.46, base_a + 0.5, base_a + 1.35, 8, bright_col, 2.0)

	# Merkez parlak çekirdek
	draw_circle(pos, pr * 0.22, Color(1.0, 1.0, 1.0, 0.9))
