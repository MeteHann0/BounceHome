extends Node2D
## Bölüm 9 (Kayıp Atlantis): Oyuncu topu ilk kez fırlattığında Poseidon yukarıdan
## hızla dalıp topu yakalar, 3 karelik çizgi roman sahnesi oynar ve topu başlangıç
## noktasına geri fırlatır.

const GameProgress := preload("res://scripts/game_progress.gd")
const BALL_TEX := preload("res://assets/basketball.png")

const LEVEL_INDEX := 8
const BODY_SCALE := 0.8
const HAND_LOCAL := Vector2(150, -74)

enum { IDLE, WAIT, DIVE, HOLD, PANELS, THROW, ASCEND, DONE }

## Aynı oyun oturumunda (tekrar denemelerde) sahne bir daha oynamasın
static var _shown_this_session := false

var _state := IDLE
var _t := 0.0
var _timer := 0.0
var _dive_t := 0.0
var _dive_from := Vector2.ZERO
var _grab_flash := 0.0
var _arm_raise := 0.0
var _throw_t := 0.0
var _throw_from := Vector2.ZERO
var _expr := 2 # 0: kızgın, 1: umursamaz, 2: sert

var _main: Node2D = null
var _ball: RigidBody2D = null
var _ball_start := Vector2.ZERO

# Çizgi roman arayüzü
var _layer: CanvasLayer = null
var _overlay: ColorRect = null
var _panel: Control = null
var _bubble: Label = null
var _bubble_label: Label = null
var _bubble_text := ""
var _bubble_fs := 24
var _bubble_style: StyleBoxFlat = null
var _font: Font = null
var _hint: Label = null
var _panel_index := 0
var _panel_start := 0.0
var _zoom := 1.0
var _tail_target := Vector2.ZERO

const SKIN := Color("#E8B98A")
const SKIN_DARK := Color("#C48E62")
const HAIR := Color("#EEF3F7")
const HAIR_SHADOW := Color("#AFC0CE")
const GOLD := Color("#F4C430")
const GOLD_DARK := Color("#9C6F08")
const ROBE := Color("#1F8A8A")
const ROBE_DARK := Color("#135E5E")
const INK := Color("#1A1A1A")

func _ready():
	z_index = 20
	hide()
	_main = get_parent() as Node2D
	if _main:
		_ball = _main.get_node_or_null("Ball") as RigidBody2D
	if _ball:
		_ball_start = _ball.global_position
	_build_ui()

func _texts() -> Array:
	if GameProgress.get_lang() == "tr":
		return [
			"Sen kimsin ve burada ne arıyorsun?!",
			"Sizi rahatsız etmek istememiştim... Sadece evime gitmeye çalışıyorum.",
			"Neyse ne...",
		]
	return [
		"Who are you, and what are you doing here?!",
		"I didn't mean to disturb you... I'm just trying to get home.",
		"Whatever...",
	]

## true ise bölüm tamamlanmış olsa veya yeniden başlatılsa bile her oyunda ilk atışta sahne çıkar
@export var always_show: bool = false

## main.gd, top fırlatıldığında çağırır.
func try_trigger() -> bool:
	if _state != IDLE or not _ball:
		return false
	if not always_show:
		if _shown_this_session or GameProgress.is_completed(LEVEL_INDEX):
			return false
	_shown_this_session = true
	_state = WAIT
	_timer = 0.22
	if _main:
		_main.set("cutscene_active", true)
	return true

# ------------------------------------------------------------------------------
# Akış
# ------------------------------------------------------------------------------

func _hand_world() -> Vector2:
	return global_position + (HAND_LOCAL + Vector2(0, -_arm_raise)) * BODY_SCALE

func _ball_hold_pos() -> Vector2:
	return _hand_world() + Vector2(0, -24)

func _process(delta: float):
	if _state == IDLE or _state == DONE:
		return
	if get_tree().paused:
		return
	_t += delta
	_grab_flash = maxf(0.0, _grab_flash - delta * 2.5)

	match _state:
		WAIT:
			_timer -= delta
			if _timer <= 0.0:
				_state = DIVE
				_dive_t = 0.0
				_expr = 2
				_dive_from = Vector2(_ball.global_position.x - HAND_LOCAL.x * BODY_SCALE, -420.0)
				global_position = _dive_from
				show()
		DIVE:
			_dive_t = minf(1.0, _dive_t + delta / 0.36)
			var target := _ball.global_position - (HAND_LOCAL + Vector2(0, -24)) * BODY_SCALE
			global_position = _dive_from.lerp(target, _dive_t * _dive_t)
			if _dive_t >= 1.0:
				_grab_ball()
		HOLD:
			_ball.global_position = _ball_hold_pos()
			_timer -= delta
			if _timer <= 0.0:
				_show_panels()
		PANELS:
			_ball.global_position = _ball_hold_pos()
			if _panel:
				_panel.queue_redraw()
			if _t - _panel_start > 4.8:
				_advance_panel()
		THROW:
			var p := _throw_from.lerp(_ball_start, _throw_t)
			p.y -= sin(PI * _throw_t) * 170.0
			_ball.global_position = p
			_ball.rotation -= delta * 14.0

	queue_redraw()

func _grab_ball():
	_state = HOLD
	_timer = 0.6
	_expr = 0
	_grab_flash = 1.0
	_ball.freeze = true
	_ball.linear_velocity = Vector2.ZERO
	_ball.angular_velocity = 0.0
	if _main:
		_main.set("is_dragging", false)
		_main.queue_redraw()

func _show_panels():
	_state = PANELS
	_overlay.modulate.a = 0.0
	_overlay.show()
	_set_panel(0)
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.2)

func _set_panel(i: int):
	_panel_index = i
	_panel_start = _t
	var W := _panel.custom_minimum_size.x
	var texts := _texts()
	_bubble_text = texts[i]

	match i:
		0:
			_bubble.position = Vector2(W * 0.55, 36)
			_bubble.custom_minimum_size = Vector2(320, 150)
			_bubble_fs = 26
		1:
			_bubble.position = Vector2(W * 0.61, 34)
			_bubble.custom_minimum_size = Vector2(278, 200)
			_bubble_fs = 22
		2:
			_bubble.position = Vector2(W * 0.56, 46)
			_bubble.custom_minimum_size = Vector2(270, 110)
			_bubble_fs = 32
	_bubble.size = _bubble.custom_minimum_size
	_bubble.hide()
	_hint.text = "Devam etmek için tıkla  ▸" if GameProgress.get_lang() == "tr" else "Click to continue  ▸"

	_panel.scale = Vector2(0.82, 0.82)
	var tw := create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if i == 1:
		_zoom = 0.45
		var tz := create_tween()
		tz.tween_property(self, "_zoom", 1.0, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_panel.queue_redraw()

func _advance_panel():
	if _state != PANELS:
		return
	if _t - _panel_start < 0.5:
		return
	if _panel_index < 2:
		_set_panel(_panel_index + 1)
	else:
		_close_panels_and_throw()

func _on_overlay_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_panel()
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		_advance_panel()

func _close_panels_and_throw():
	_state = THROW
	_expr = 1
	_throw_t = 0.0
	_throw_from = _ball.global_position
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 0.0, 0.2)
	tw.tween_callback(_overlay.hide)

	# Kol kaldırma (fırlatma hareketi) ve topun yay çizerek başlangıca gitmesi
	var ta := create_tween()
	ta.tween_property(self, "_arm_raise", 45.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ta.tween_property(self, "_arm_raise", -8.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var tt := create_tween()
	tt.tween_interval(0.2)
	tt.tween_property(self, "_throw_t", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tt.tween_callback(_release_ball)

func _release_ball():
	_state = ASCEND
	_ball.global_position = _ball_start
	_ball.rotation = 0.0
	_ball.freeze = false
	_ball.linear_velocity = Vector2.ZERO
	_ball.angular_velocity = 0.0
	_ball.gravity_scale = 0.08
	_ball.linear_damp = 0.35

	if _main:
		# Poseidon'un geri attığı atış hamle sayılmasın
		var shots: int = max(0, int(_main.get("shot_count")) - 1)
		_main.set("shot_count", shots)
		var lbl = _main.get("shot_counter_label")
		if lbl:
			lbl.text = GameProgress.t("moves") % shots
		_main.set("cutscene_active", false)

	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(self, "global_position:y", -520.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_state = DONE
		queue_free()
	)

# ------------------------------------------------------------------------------
# Arayüz
# ------------------------------------------------------------------------------

func _build_ui():
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)

	_overlay = ColorRect.new()
	_overlay.visible = false
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.01, 0.05, 0.12, 0.72)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.focus_mode = Control.FOCUS_ALL
	_overlay.gui_input.connect(_on_overlay_input)
	_layer.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	_panel = Control.new()
	_panel.custom_minimum_size = Vector2(780, 440)
	_panel.pivot_offset = Vector2(390, 220)
	_panel.clip_contents = true
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_panel)
	center.add_child(_panel)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Comic Sans MS", "Segoe UI", "Arial"])
	font.font_weight = 700

	# Konuşma balonu: tek bir Label (kendi arka plan stiliyle). Container kullanılmıyor,
	# çünkü gizli başlayan container ilk gösterimde metni yerleştirmeyebiliyordu.
	_bubble = Label.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = INK
	style.set_border_width_all(4)
	style.set_corner_radius_all(28)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_bubble.add_theme_stylebox_override("normal", style)
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bubble.add_theme_font_override("font", font)
	_bubble.add_theme_color_override("font_color", INK)
	_bubble.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_bubble.add_theme_constant_override("outline_size", 0)
	_bubble.add_theme_constant_override("shadow_outline_size", 0)
	_panel.add_child(_bubble)
	_bubble_label = _bubble
	_bubble.visible = false
	_bubble_style = style
	_font = font

	_hint = Label.new()
	_hint.text = "Devam etmek için tıkla  ▸" if GameProgress.get_lang() == "tr" else "Click to continue  ▸"
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -52
	_hint.offset_bottom = -20
	_hint.offset_left = -200
	_hint.offset_right = 200
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font", font)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_hint.add_theme_constant_override("outline_size", 0)
	_overlay.add_child(_hint)

# ------------------------------------------------------------------------------
# Çizim yardımcıları
# ------------------------------------------------------------------------------

func _ell(c: Vector2, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out

func _mirror(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(-p.x, p.y))
	return out

func _draw_trident(ci: CanvasItem, top: Vector2, length: float, k: float):
	ci.draw_line(top, top + Vector2(0, length), GOLD_DARK, 9.0 * k)
	ci.draw_line(top, top + Vector2(0, length), GOLD, 5.0 * k)
	var tips := [top + Vector2(-30, -42) * k, top + Vector2(0, -62) * k, top + Vector2(30, -42) * k]
	for layer in 2:
		var col := GOLD_DARK if layer == 0 else GOLD
		var w := (9.0 if layer == 0 else 5.0) * k
		ci.draw_line(top + Vector2(-30, 0) * k, top + Vector2(30, 0) * k, col, w)
		ci.draw_line(top + Vector2(-30, 0) * k, tips[0], col, w)
		ci.draw_line(top, tips[1], col, w)
		ci.draw_line(top + Vector2(30, 0) * k, tips[2], col, w)
	for tip in tips:
		var tri := PackedVector2Array([tip + Vector2(-10, 5) * k, tip + Vector2(0, -20) * k, tip + Vector2(10, 5) * k])
		ci.draw_colored_polygon(tri, GOLD)
		ci.draw_polyline(_closed(tri), GOLD_DARK, 2.5 * k)

## Poseidon'un başı. expr: 0 kızgın, 1 umursamaz, 2 sert
func _draw_head(ci: CanvasItem, o: Vector2, s: float, expr: int):
	ci.draw_set_transform(o, 0.0, Vector2(s, s))
	var skin := SKIN
	if expr == 0:
		skin = SKIN.lerp(Color("#E2654F"), 0.35)

	# Arka saçlar
	ci.draw_colored_polygon(_ell(Vector2(0, -6), 62, 62), HAIR_SHADOW)
	ci.draw_colored_polygon(_ell(Vector2(0, -10), 57, 58), HAIR)
	# Kulaklar ve yüz
	ci.draw_colored_polygon(_ell(Vector2(-42, 0), 8, 12), skin.darkened(0.1))
	ci.draw_colored_polygon(_ell(Vector2(42, 0), 8, 12), skin.darkened(0.1))
	ci.draw_colored_polygon(_ell(Vector2.ZERO, 42, 50), skin)

	# Gözler
	var eyes := [Vector2(-17, -6), Vector2(17, -6)]
	for e in eyes:
		ci.draw_colored_polygon(_ell(e, 10, 7), Color.WHITE)
	match expr:
		0:
			for e in eyes:
				ci.draw_circle(e + Vector2(0, 1), 6.5, Color(1, 0.25, 0.1, 0.35))
				ci.draw_circle(e + Vector2(0, 1), 4.0, Color("#C8102E"))
			# Kızgın göz kapakları (içe doğru eğik)
			var lid := PackedVector2Array([Vector2(-29, -17), Vector2(-5, -17), Vector2(-5, -3), Vector2(-29, -11)])
			ci.draw_colored_polygon(lid, skin)
			ci.draw_colored_polygon(_mirror(lid), skin)
			ci.draw_line(Vector2(-29, -11), Vector2(-5, -3), INK, 2.0)
			ci.draw_line(Vector2(29, -11), Vector2(5, -3), INK, 2.0)
			# Çatık kaşlar
			ci.draw_line(Vector2(-33, -22), Vector2(-5, -10), INK, 9.0)
			ci.draw_line(Vector2(33, -22), Vector2(5, -10), INK, 9.0)
			ci.draw_line(Vector2(-32, -22), Vector2(-6, -11), HAIR, 5.5)
			ci.draw_line(Vector2(32, -22), Vector2(6, -11), HAIR, 5.5)
			# Alında öfke işareti
			var v := Vector2(27, -32)
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var a0: float = atan2(q.y, q.x) + PI - 0.7
				ci.draw_arc(v + q * 5.0, 4.0, a0, a0 + 1.4, 8, Color("#D7191C"), 2.5)
		1:
			for e in eyes:
				# Gözlerini devirmiş, yarı kapalı
				ci.draw_circle(e + Vector2(4, -2), 3.8, Color("#1C2E4A"))
				var lid := PackedVector2Array([e + Vector2(-11, -9), e + Vector2(11, -9), e + Vector2(11, 0), e + Vector2(-11, 0)])
				ci.draw_colored_polygon(lid, skin)
				ci.draw_line(e + Vector2(-10, 0), e + Vector2(10, 0), INK, 2.2)
			# Bir kaş düz, diğeri kalkık
			ci.draw_line(Vector2(-31, -18), Vector2(-6, -17), INK, 8.0)
			ci.draw_line(Vector2(-30, -18), Vector2(-7, -17), HAIR, 4.5)
			ci.draw_line(Vector2(7, -24), Vector2(31, -30), INK, 8.0)
			ci.draw_line(Vector2(8, -24), Vector2(30, -30), HAIR, 4.5)
		_:
			for e in eyes:
				ci.draw_circle(e, 4.0, Color("#1C2E4A"))
			ci.draw_line(Vector2(-31, -20), Vector2(-6, -15), INK, 8.0)
			ci.draw_line(Vector2(31, -20), Vector2(6, -15), INK, 8.0)
			ci.draw_line(Vector2(-30, -20), Vector2(-7, -15), HAIR, 4.5)
			ci.draw_line(Vector2(30, -20), Vector2(7, -15), HAIR, 4.5)

	# Burun
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(-7, 11), Vector2(7, 11)]), skin.darkened(0.14))

	# Sakal
	var beard := PackedVector2Array([
		Vector2(-43, 2), Vector2(-42, 30), Vector2(-32, 54), Vector2(-17, 68), Vector2(0, 78),
		Vector2(17, 68), Vector2(32, 54), Vector2(42, 30), Vector2(43, 2),
		Vector2(30, 14), Vector2(18, 21), Vector2(-18, 21), Vector2(-30, 14),
	])
	ci.draw_colored_polygon(beard, HAIR)
	for i in 5:
		var bx := -24.0 + i * 12.0
		ci.draw_arc(Vector2(bx, 50 + absf(bx) * -0.2), 8.0, 0.2, PI - 0.2, 8, HAIR_SHADOW, 2.0)

	# Ağız
	match expr:
		0:
			var mouth := PackedVector2Array([Vector2(-14, 24), Vector2(14, 24), Vector2(10, 39), Vector2(0, 42), Vector2(-10, 39)])
			ci.draw_colored_polygon(mouth, Color("#5A1414"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, 24), Vector2(12, 24), Vector2(11, 29), Vector2(-11, 29)]), Color.WHITE)
			ci.draw_polyline(_closed(mouth), INK, 2.0)
		1:
			ci.draw_line(Vector2(-9, 30), Vector2(9, 27), INK, 3.0)
		_:
			ci.draw_line(Vector2(-10, 30), Vector2(10, 30), INK, 3.0)

	# Bıyık
	var stache := PackedVector2Array([Vector2(0, 15), Vector2(-10, 11), Vector2(-24, 16), Vector2(-32, 26), Vector2(-19, 22), Vector2(-6, 21)])
	ci.draw_colored_polygon(stache, HAIR)
	ci.draw_colored_polygon(_mirror(stache), HAIR)
	ci.draw_polyline(stache, HAIR_SHADOW, 1.5)
	ci.draw_polyline(_mirror(stache), HAIR_SHADOW, 1.5)

	# Altın taç
	for x in [-30.0, -10.0, 10.0, 30.0]:
		var h := -74.0 if absf(x) < 20.0 else -64.0
		var spike := PackedVector2Array([Vector2(x - 9, -44), Vector2(x, h), Vector2(x + 9, -44)])
		ci.draw_colored_polygon(spike, GOLD)
		ci.draw_polyline(spike, GOLD_DARK, 2.0)
	var band := PackedVector2Array([Vector2(-41, -46), Vector2(41, -46), Vector2(37, -33), Vector2(-37, -33)])
	ci.draw_colored_polygon(band, GOLD)
	ci.draw_polyline(_closed(band), GOLD_DARK, 2.0)
	ci.draw_circle(Vector2(0, -39.5), 4.5, Color("#D7263D"))
	ci.draw_circle(Vector2(-22, -39.5), 3.5, Color("#1E88E5"))
	ci.draw_circle(Vector2(22, -39.5), 3.5, Color("#1E88E5"))

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Tam boy Poseidon (oyun dünyasında görünen)
func _draw_body(ci: CanvasItem, o: Vector2, s: float, expr: int, arm_raise: float):
	ci.draw_set_transform(o, 0.0, Vector2(s, s))

	# Üç uçlu mızrak (gövdenin arkasında)
	_draw_trident(ci, Vector2(-112, -250), 420.0, 1.0)

	# Etek / cübbe
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-58, 30), Vector2(58, 30), Vector2(80, 175), Vector2(40, 162),
		Vector2(0, 180), Vector2(-40, 162), Vector2(-80, 175),
	]), ROBE)
	ci.draw_line(Vector2(-20, 45), Vector2(-30, 165), ROBE_DARK, 3.0)
	ci.draw_line(Vector2(22, 45), Vector2(32, 165), ROBE_DARK, 3.0)

	# Gövde
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-68, -100), Vector2(68, -100), Vector2(56, 40), Vector2(-56, 40)]), SKIN)
	ci.draw_arc(Vector2(-26, -66), 22.0, 0.35, PI - 0.35, 12, SKIN_DARK, 2.5)
	ci.draw_arc(Vector2(26, -66), 22.0, 0.35, PI - 0.35, 12, SKIN_DARK, 2.5)
	for i in 3:
		ci.draw_line(Vector2(-12, -22 + i * 18), Vector2(12, -22 + i * 18), SKIN_DARK, 2.0)
	ci.draw_line(Vector2(0, -36), Vector2(0, 26), SKIN_DARK, 2.0)

	# Omuzdan kalçaya toga kuşağı
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-68, -100), Vector2(-40, -104), Vector2(60, 12), Vector2(56, 40), Vector2(22, 40)]), ROBE)
	ci.draw_line(Vector2(-40, -104), Vector2(60, 12), GOLD, 4.0)
	ci.draw_rect(Rect2(-58, 28, 116, 14), GOLD)
	ci.draw_rect(Rect2(-58, 28, 116, 14), GOLD_DARK, false, 2.0)

	# Mızrağı tutan kol
	var sh_l := Vector2(-64, -88)
	var el_l := Vector2(-102, -36)
	var hd_l := Vector2(-112, -96)
	for layer in 2:
		var col := SKIN_DARK if layer == 0 else SKIN
		var w := 32.0 if layer == 0 else 27.0
		ci.draw_line(sh_l, el_l, col, w)
		ci.draw_line(el_l, hd_l, col, w)
		ci.draw_circle(sh_l, w * 0.5, col)
		ci.draw_circle(el_l, w * 0.5, col)
	ci.draw_circle(hd_l, 17.0, SKIN_DARK)
	ci.draw_circle(hd_l, 15.0, SKIN)

	# Topu tutan kol
	var sh_r := Vector2(64, -88)
	var el_r := Vector2(112, -46 - arm_raise * 0.4)
	var hd_r := HAND_LOCAL + Vector2(0, -arm_raise)
	for layer in 2:
		var col := SKIN_DARK if layer == 0 else SKIN
		var w := 32.0 if layer == 0 else 27.0
		ci.draw_line(sh_r, el_r, col, w)
		ci.draw_line(el_r, hd_r, col, w)
		ci.draw_circle(sh_r, w * 0.5, col)
		ci.draw_circle(el_r, w * 0.5, col)
	ci.draw_line(el_r.lerp(hd_r, 0.25) + Vector2(-6, -12), el_r.lerp(hd_r, 0.25) + Vector2(6, 12), GOLD, 7.0)
	# Avuç ve parmaklar (dünya görünümü)
	var palm_pts := PackedVector2Array([
		hd_r + Vector2(-16, 6), hd_r + Vector2(-22, -10), hd_r + Vector2(-14, -22),
		hd_r + Vector2(14, -20), hd_r + Vector2(20, -6), hd_r + Vector2(12, 8)
	])
	ci.draw_colored_polygon(palm_pts, SKIN)
	ci.draw_polyline(_closed(palm_pts), SKIN_DARK, 2.5)
	# Başparmak (sol) ve 4 parmak (sağ)
	ci.draw_line(hd_r + Vector2(-14, -6), hd_r + Vector2(-20, -24), SKIN_DARK, 8.5)
	ci.draw_line(hd_r + Vector2(-14, -6), hd_r + Vector2(-20, -24), SKIN, 6.0)
	for fi in 4:
		var fy := -12.0 - fi * 5.0
		ci.draw_line(hd_r + Vector2(14, fy + 6.0), hd_r + Vector2(19 - fi * 1.5, fy - 8.0), SKIN_DARK, 6.5)
		ci.draw_line(hd_r + Vector2(14, fy + 6.0), hd_r + Vector2(19 - fi * 1.5, fy - 8.0), SKIN, 4.5)

	# Boyun ve baş
	ci.draw_rect(Rect2(-16, -124, 32, 30), SKIN)
	_draw_head(ci, o + Vector2(0, -160) * s, s * 0.95, expr)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_sad_face(ci: CanvasItem, c: Vector2, f: float):
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * 38.0, -14.0) * f
		var eye := _ell(e, 21.0 * f, 25.0 * f)
		ci.draw_colored_polygon(eye, Color.WHITE)
		ci.draw_polyline(_closed(eye), INK, 3.0 * f)
		ci.draw_circle(e + Vector2(0, 9) * f, 10.0 * f, INK)
		ci.draw_circle(e + Vector2(-3, 5) * f, 3.5 * f, Color.WHITE)
		# Üzgün kaşlar (iç uçlar yukarıda)
		ci.draw_line(c + Vector2(side * 62.0, -44.0) * f, c + Vector2(side * 18.0, -60.0) * f, INK, 7.0 * f)
	ci.draw_arc(c + Vector2(0, 64) * f, 30.0 * f, PI + 0.55, TAU - 0.55, 20, INK, 6.0 * f)
	# Akan gözyaşı
	var ty := fmod(_t * 38.0, 55.0)
	var tp := c + Vector2(-50.0, 20.0 + ty) * f
	var tear_col := Color(0.55, 0.85, 1.0, 1.0 - ty / 70.0)
	ci.draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -15) * f, tp + Vector2(-7, 0) * f, tp + Vector2(7, 0) * f]), tear_col)
	ci.draw_circle(tp, 7.0 * f, tear_col)

func _draw_ball(ci: CanvasItem, c: Vector2, r: float):
	ci.draw_texture_rect(BALL_TEX, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)

## Eklemli parmak poligonu üretir (Chaikin yumuşatması + yuvarlak uçlar)
func _build_finger_poly(pts: Array, radii: Array, expand: float = 0.0, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var c_pts: Array[Vector2] = []
	var c_rad: Array[float] = []
	for i in pts.size():
		c_pts.append((pts[i] as Vector2) + offset)
		c_rad.append(maxf(1.0, float(radii[i]) + expand))

	for _iter in 2:
		var n_pts: Array[Vector2] = [c_pts[0]]
		var n_rad: Array[float] = [c_rad[0]]
		for i in range(c_pts.size() - 1):
			n_pts.append(c_pts[i].lerp(c_pts[i + 1], 0.25))
			n_pts.append(c_pts[i].lerp(c_pts[i + 1], 0.75))
			n_rad.append(lerpf(c_rad[i], c_rad[i + 1], 0.25))
			n_rad.append(lerpf(c_rad[i], c_rad[i + 1], 0.75))
		n_pts.append(c_pts[c_pts.size() - 1])
		n_rad.append(c_rad[c_rad.size() - 1])
		c_pts = n_pts
		c_rad = n_rad

	var k_count := c_pts.size()
	var norms: Array[Vector2] = []
	for k in k_count:
		var p_prev := c_pts[max(0, k - 1)]
		var p_next := c_pts[min(k_count - 1, k + 1)]
		var dir := (p_next - p_prev).normalized()
		if dir.length_squared() < 0.001:
			dir = Vector2.RIGHT
		norms.append(Vector2(-dir.y, dir.x))

	var poly := PackedVector2Array()
	# Başlangıç yuvarlak kapak
	var start_a := norms[0].angle()
	for s in range(1, 6):
		var a := start_a + PI + float(s) / 6.0 * PI
		poly.append(c_pts[0] + Vector2(cos(a), sin(a)) * c_rad[0])
	# Üst kenar
	for k in k_count:
		poly.append(c_pts[k] + norms[k] * c_rad[k])
	# Parmak ucu yuvarlak kapak
	var end_a := norms[k_count - 1].angle()
	for s in range(1, 8):
		var a := end_a - float(s) / 8.0 * PI
		poly.append(c_pts[k_count - 1] + Vector2(cos(a), sin(a)) * c_rad[k_count - 1])
	# Alt kenar
	for k in range(k_count - 1, -1, -1):
		poly.append(c_pts[k] - norms[k] * c_rad[k])
	return poly

## Tek bir eklemli insan parmağı çizer (gölge, cilt tonu, boğum çizgileri ve tırnak)
func _draw_articulated_finger(ci: CanvasItem, pts: Array, radii: Array, u: float, is_thumb: bool = false):
	# Top üzerindeki parmak gölgesi
	var shadow_poly := _build_finger_poly(pts, radii, 0.5 * u, Vector2(-3.5 * u, 4.5 * u))
	ci.draw_colored_polygon(shadow_poly, Color(0.04, 0.02, 0.0, 0.22))

	# Dış kontur, alt gölge ve ana ten rengi
	var outline_poly := _build_finger_poly(pts, radii, 2.4 * u)
	var dark_poly := _build_finger_poly(pts, radii, 0.0)
	var skin_poly := _build_finger_poly(pts, radii, -1.6 * u, Vector2(0.0, -1.4 * u))
	var hi_poly := _build_finger_poly(pts, radii, -4.8 * u, Vector2(-0.8 * u, -3.0 * u))

	ci.draw_colored_polygon(outline_poly, INK)
	ci.draw_colored_polygon(dark_poly, SKIN_DARK)
	ci.draw_colored_polygon(skin_poly, SKIN)
	ci.draw_colored_polygon(hi_poly, SKIN.lightened(0.09))

	# Parmak boğum (eklem) çizgileri
	for j in range(1, pts.size() - 1):
		var pj: Vector2 = pts[j]
		var rj: float = radii[j]
		var d_prev := (pj - (pts[j - 1] as Vector2)).normalized()
		var d_next := ((pts[j + 1] as Vector2) - pj).normalized()
		var dir := (d_prev + d_next).normalized()
		var n := Vector2(-dir.y, dir.x)
		ci.draw_line(pj - n * rj * 0.48, pj + n * rj * 0.36, SKIN_DARK.darkened(0.18), maxf(1.4, 2.0 * u))
		ci.draw_line(pj - n * rj * 0.30 + dir * 2.2 * u, pj + n * rj * 0.22 + dir * 2.2 * u, SKIN_DARK.darkened(0.12), maxf(1.0, 1.4 * u))

	# Parmak ucu tırnağı
	var p_tip: Vector2 = pts[pts.size() - 1]
	var p_prev: Vector2 = pts[pts.size() - 2]
	var r_tip: float = radii[radii.size() - 1]
	var tip_dir := (p_tip - p_prev).normalized()
	var tip_n := Vector2(-tip_dir.y, tip_dir.x)
	var nail_side := 1.0 if is_thumb else -1.0
	var nail_c := p_tip - tip_dir * (r_tip * 0.14) + tip_n * (nail_side * r_tip * 0.16)
	var nl := r_tip * (0.72 if is_thumb else 0.68)
	var nw := r_tip * (0.50 if is_thumb else 0.48)

	var nail_pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		var lx := cos(a) * nl
		var ly := sin(a) * nw
		if lx < 0.0:
			lx *= 0.78 # Tırnak dibi daha düz
		nail_pts.append(nail_c + tip_dir * lx + tip_n * ly)
	ci.draw_colored_polygon(nail_pts, Color("#F6DFC9"))
	ci.draw_polyline(_closed(nail_pts), SKIN_DARK.darkened(0.18), maxf(1.2, 1.6 * u))

## Poseidon'un topu avucunda tuttuğu gerçekçi insan eli çizimi
func _draw_hand_holding_ball(ci: CanvasItem, c: Vector2, r: float, sad_scale: float):
	var u := r / 100.0

	# 1) ARKA KATMAN: Ön kol, bilek, altın bileklik ve avuç arkası
	var arm_pts := PackedVector2Array([
		c + Vector2(-102, 225) * u,
		c + Vector2(-74, 118) * u,
		c + Vector2(46, 122) * u,
		c + Vector2(26, 225) * u,
	])
	ci.draw_colored_polygon(arm_pts, SKIN)
	# Kol sağ gölgesi
	var arm_shade := PackedVector2Array([
		c + Vector2(8, 120) * u,
		c + Vector2(46, 122) * u,
		c + Vector2(26, 225) * u,
		c + Vector2(-12, 225) * u,
	])
	ci.draw_colored_polygon(arm_shade, SKIN_DARK)
	ci.draw_line(c + Vector2(-102, 225) * u, c + Vector2(-74, 118) * u, INK, maxf(2.0, 3.5 * u))
	ci.draw_line(c + Vector2(46, 122) * u, c + Vector2(26, 225) * u, INK, maxf(2.0, 3.5 * u))

	# Avuç arkası ve sağ parmak kökleri (topun arkasında kalan kısım)
	var back_palm := PackedVector2Array([
		c + Vector2(-76, 118) * u,
		c + Vector2(-96, 80) * u,
		c + Vector2(-88, 36) * u,
		c + Vector2(72, -44) * u,
		c + Vector2(106, -24) * u,
		c + Vector2(114, 12) * u,
		c + Vector2(110, 44) * u,
		c + Vector2(96, 74) * u,
		c + Vector2(74, 104) * u,
		c + Vector2(46, 122) * u,
	])
	ci.draw_colored_polygon(back_palm, SKIN_DARK)
	var back_palm_inner := PackedVector2Array([
		c + Vector2(-72, 114) * u,
		c + Vector2(-90, 78) * u,
		c + Vector2(-82, 40) * u,
		c + Vector2(68, -38) * u,
		c + Vector2(100, -20) * u,
		c + Vector2(106, 12) * u,
		c + Vector2(102, 42) * u,
		c + Vector2(88, 70) * u,
		c + Vector2(66, 98) * u,
		c + Vector2(40, 116) * u,
	])
	ci.draw_colored_polygon(back_palm_inner, SKIN)
	ci.draw_polyline(_closed(back_palm), INK, maxf(2.0, 3.5 * u))

	# Poseidon'un altın bilekliği (Atlantis işlemeli)
	var bracer := PackedVector2Array([
		c + Vector2(-80, 132) * u,
		c + Vector2(44, 138) * u,
		c + Vector2(35, 184) * u,
		c + Vector2(-91, 178) * u,
	])
	ci.draw_colored_polygon(bracer, GOLD)
	var bracer_shade := PackedVector2Array([
		c + Vector2(4, 136) * u,
		c + Vector2(44, 138) * u,
		c + Vector2(35, 184) * u,
		c + Vector2(-5, 182) * u,
	])
	ci.draw_colored_polygon(bracer_shade, GOLD_DARK)
	ci.draw_polyline(_closed(bracer), INK, maxf(2.0, 3.2 * u))
	ci.draw_line(c + Vector2(-82, 140) * u, c + Vector2(42, 146) * u, GOLD_DARK, maxf(1.5, 2.5 * u))
	ci.draw_line(c + Vector2(-89, 170) * u, c + Vector2(36, 176) * u, GOLD_DARK, maxf(1.5, 2.5 * u))
	# Bileklik üzerindeki turkuaz Atlantis taşı
	var gem_c := c + Vector2(-21, 158) * u
	ci.draw_circle(gem_c, 9.5 * u, GOLD_DARK)
	ci.draw_circle(gem_c, 7.0 * u, Color("#18B7C9"))
	ci.draw_circle(gem_c + Vector2(-2, -2) * u, 2.5 * u, Color("#A8F5FF"))

	# 2) ORTA KATMAN: Top, avuç içi temas gölgesi ve üzgün yüz
	_draw_ball(ci, c, r)
	# Topun avuç içine oturduğu alt/sağ kısımda yumuşak temas gölgesi
	ci.draw_arc(c, r * 0.94, 0.15, PI - 0.25, 28, Color(0.05, 0.02, 0.0, 0.24), 12.0 * u)
	_draw_sad_face(ci, c, sad_scale)

	# 3) ÖN KATMAN: Topun altını saran avuç içi etli kısım (thenar/hypothenar), başparmak ve 4 parmak
	var palm_cup_dark := PackedVector2Array([
		c + Vector2(-84, 70) * u,
		c + Vector2(-52, 84) * u,
		c + Vector2(-14, 92) * u,
		c + Vector2(28, 94) * u,
		c + Vector2(68, 82) * u,
		c + Vector2(88, 72) * u,
		c + Vector2(72, 104) * u,
		c + Vector2(44, 122) * u,
		c + Vector2(-18, 126) * u,
		c + Vector2(-74, 118) * u,
		c + Vector2(-94, 82) * u,
	])
	ci.draw_colored_polygon(palm_cup_dark, SKIN_DARK)

	var palm_cup_skin := PackedVector2Array([
		c + Vector2(-82, 72) * u,
		c + Vector2(-50, 86) * u,
		c + Vector2(-14, 94) * u,
		c + Vector2(26, 95) * u,
		c + Vector2(62, 84) * u,
		c + Vector2(56, 108) * u,
		c + Vector2(26, 120) * u,
		c + Vector2(-24, 122) * u,
		c + Vector2(-72, 114) * u,
		c + Vector2(-90, 82) * u,
	])
	ci.draw_colored_polygon(palm_cup_skin, SKIN)
	# Avuç içi üst kenar konturu ve yaşam çizgisi kıvrımı
	var cup_rim := PackedVector2Array([
		c + Vector2(-82, 70) * u,
		c + Vector2(-50, 84) * u,
		c + Vector2(-14, 92) * u,
		c + Vector2(28, 94) * u,
		c + Vector2(72, 80) * u,
	])
	ci.draw_polyline(cup_rim, INK, maxf(1.8, 2.8 * u))
	var palm_crease := PackedVector2Array([
		c + Vector2(-56, 86) * u,
		c + Vector2(-38, 100) * u,
		c + Vector2(-10, 108) * u,
	])
	ci.draw_polyline(palm_crease, SKIN_DARK.darkened(0.18), maxf(1.4, 2.2 * u))

	# Sol taraftan topu kavrayan Başparmak (3 boğumlu + tırnaklı)
	var thumb_pts := [
		c + Vector2(-78, 74) * u,
		c + Vector2(-104, 30) * u,
		c + Vector2(-93, -8) * u,
		c + Vector2(-68, -26) * u,
	]
	var thumb_radii := [21.0 * u, 17.5 * u, 15.0 * u, 12.5 * u]
	_draw_articulated_finger(ci, thumb_pts, thumb_radii, u, true)

	# Sağ taraftan topu saran 4 parmak (İşaret, Orta, Yüzük, Serçe)
	# 1. İşaret parmağı
	var index_pts := [
		c + Vector2(104, -22) * u,
		c + Vector2(92, -40) * u,
		c + Vector2(76, -40) * u,
		c + Vector2(64, -33) * u,
	]
	var index_radii := [13.8 * u, 12.6 * u, 11.2 * u, 9.5 * u]
	_draw_articulated_finger(ci, index_pts, index_radii, u, false)

	# 2. Orta parmak (en uzun)
	var middle_pts := [
		c + Vector2(112, 8) * u,
		c + Vector2(98, -10) * u,
		c + Vector2(78, -12) * u,
		c + Vector2(61, -5) * u,
	]
	var middle_radii := [14.8 * u, 13.4 * u, 11.8 * u, 10.2 * u]
	_draw_articulated_finger(ci, middle_pts, middle_radii, u, false)

	# 3. Yüzük parmağı
	var ring_pts := [
		c + Vector2(110, 38) * u,
		c + Vector2(96, 22) * u,
		c + Vector2(78, 20) * u,
		c + Vector2(63, 25) * u,
	]
	var ring_radii := [14.0 * u, 12.6 * u, 11.2 * u, 9.4 * u]
	_draw_articulated_finger(ci, ring_pts, ring_radii, u, false)

	# 4. Serçe parmağı (en küçük ve altta)
	var pinky_pts := [
		c + Vector2(96, 66) * u,
		c + Vector2(85, 54) * u,
		c + Vector2(71, 52) * u,
		c + Vector2(58, 56) * u,
	]
	var pinky_radii := [12.2 * u, 11.0 * u, 9.6 * u, 8.2 * u]
	_draw_articulated_finger(ci, pinky_pts, pinky_radii, u, false)

# ------------------------------------------------------------------------------
# Dünya çizimi (dalış / tutuş / fırlatma)
# ------------------------------------------------------------------------------

func _draw():
	if _state == IDLE or _state == WAIT or _state == DONE:
		return

	# Hız çizgileri
	if _state == DIVE:
		for i in 7:
			var x := (i - 3) * 30.0
			draw_line(Vector2(x, -300.0 - (i % 3) * 25.0), Vector2(x, -700.0), Color(0.85, 0.97, 1.0, 0.4), 3.0)
	elif _state == ASCEND:
		for i in 7:
			var x := (i - 3) * 30.0
			draw_line(Vector2(x, 160.0 + (i % 3) * 25.0), Vector2(x, 500.0), Color(0.85, 0.97, 1.0, 0.4), 3.0)

	_draw_body(self, Vector2.ZERO, BODY_SCALE, _expr, _arm_raise)

	if _grab_flash > 0.0:
		var hl := (HAND_LOCAL + Vector2(0, -24 - _arm_raise)) * BODY_SCALE
		draw_arc(hl, 22.0 + (1.0 - _grab_flash) * 45.0, 0.0, TAU, 32, Color(1, 1, 1, _grab_flash), 4.0)

# ------------------------------------------------------------------------------
# Çizgi roman kareleri
# ------------------------------------------------------------------------------

func _draw_panel():
	var ci := _panel
	var W := _panel.size.x
	var H := _panel.size.y
	var lt := _t - _panel_start

	# Su altı arka planı
	var steps := 14
	for i in steps:
		var col := Color("#0F6286").lerp(Color("#05203A"), float(i) / steps)
		ci.draw_rect(Rect2(0, H * i / steps, W, H / steps + 1.0), col)
	for i in 5:
		var x := W * (0.08 + i * 0.21) + sin(_t * 0.6 + i) * 20.0
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(x - 18, 0), Vector2(x + 18, 0), Vector2(x + 90, H), Vector2(x - 30, H)
		]), Color(0.7, 0.95, 1.0, 0.06))
	for i in 12:
		var bx := fmod(i * 97.0, W)
		var by := H - fmod(_t * (30.0 + i * 4.0) + i * 53.0, H + 20.0)
		ci.draw_arc(Vector2(bx, by), 3.0 + (i % 3) * 2.0, 0.0, TAU, 12, Color(0.8, 0.95, 1.0, 0.35), 1.5)

	match _panel_index:
		0:
			var shake := Vector2(sin(_t * 55.0) * 5.0, cos(_t * 47.0) * 4.0) * maxf(0.0, 1.0 - lt * 0.7)
			var hc := Vector2(W * 0.3, H * 0.6) + shake
			var burst := PackedVector2Array()
			for i in 36:
				var a := TAU * i / 36.0 + _t * 0.25
				var r := 240.0 if i % 2 == 0 else 170.0
				burst.append(hc + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(burst, Color(0.85, 0.15, 0.1, 0.5))
			_draw_trident(ci, Vector2(W * 0.06, 90) + shake, H, 1.5)
			_draw_head(ci, hc, 2.6, 0)
			_tail_target = hc + Vector2(60, 85)
		1:
			var z := _zoom
			var c := Vector2(W * 0.34, H * 0.5)
			for i in 44:
				var a := TAU * i / 44.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + d * (150.0 * z + 30.0), c + d * 700.0, Color(1, 1, 1, 0.08 + 0.07 * (i % 2)), 3.0)
			var r := 115.0 * z
			_draw_hand_holding_ball(ci, c, r, z)
			_tail_target = c + Vector2(95, 30) * z
		2:
			var hc := Vector2(W * 0.3, H * 0.6) + Vector2(0, sin(_t * 1.6) * 3.0)
			_draw_trident(ci, Vector2(W * 0.06, 90), H, 1.5)
			_draw_head(ci, hc, 2.6, 1)
			# Elinde umursamazca tuttuğu küçük, üzgün top
			var hp := Vector2(W * 0.76, H * 0.9)
			var bc := hp + Vector2(0, -58) + Vector2(sin(_t * 2.0) * 4.0, 0)
			_draw_hand_holding_ball(ci, bc, 44.0, 44.0 / 115.0)
			_tail_target = hc + Vector2(55, 80)

	# Konuşma balonu (kuyruk + gövde + metin doğrudan çiziliyor)
	if _bubble:
		var font: Font = _font if _font else ThemeDB.fallback_font
		var b := _bubble.position
		var bs := _bubble.custom_minimum_size
		var inner_w := bs.x - 40.0
		var text_size := font.get_multiline_string_size(_bubble_text, HORIZONTAL_ALIGNMENT_CENTER, inner_w, _bubble_fs)
		bs.y = maxf(bs.y, text_size.y + 32.0)
		_bubble.size = bs

		var b1 := b + Vector2(28, bs.y - 6)
		var b2 := b + Vector2(78, bs.y - 6)
		ci.draw_colored_polygon(PackedVector2Array([b1, _tail_target, b2]), Color.WHITE)
		ci.draw_line(b1, _tail_target, INK, 4.0)
		ci.draw_line(b2, _tail_target, INK, 4.0)

		if _bubble_style:
			ci.draw_style_box(_bubble_style, Rect2(b, bs))
		var ty := b.y + (bs.y - text_size.y) * 0.5 + font.get_ascent(_bubble_fs)
		ci.draw_multiline_string(font, Vector2(b.x + 20.0, ty), _bubble_text,
			HORIZONTAL_ALIGNMENT_CENTER, inner_w, _bubble_fs, -1, INK)

	# Çizgi roman çerçevesi
	ci.draw_rect(Rect2(Vector2(3, 3), _panel.size - Vector2(6, 6)), Color.WHITE, false, 4.0)
	ci.draw_rect(Rect2(Vector2.ZERO, _panel.size), INK, false, 8.0)
	# Kare numarası
	ci.draw_circle(Vector2(30, 30), 16.0, INK)
	ci.draw_circle(Vector2(30, 30), 13.0, GOLD)
	ci.draw_string(ThemeDB.fallback_font, Vector2(24, 37), str(_panel_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
