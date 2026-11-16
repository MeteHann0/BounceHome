@tool
extends Node2D
## Bölüm 7 (Kristal Mağara) başlangıcında topun üstünde, mağara tavanına doğru
## titreyerek duran gizemli mektup. Üstüne tıklandığında zarf açılır ve içinden not çıkar.

@export_multiline var note_text_tr: String = """Sevgili oyuncu,
Buraya kadar oynadığın için sana çok teşekkür ederim. Bu benim ilk oyunum ve senin desteklerin beni çok mutlu ediyor:) Sana özel bir hediye hazırladım umarım beğenirsin."""

@export_multiline var note_text_en: String = """Dear player,
Thank you so much for playing this far. This is my very first game and your support makes me really happy:) I prepared a special gift just for you, I hope you like it."""
# ==============================================================================

const GameProgress := preload("res://scripts/game_progress.gd")
const GiftPortalScript := preload("res://scripts/gift_portal.gd")

func _get_localized_note() -> String:
	return note_text_tr if GameProgress.get_lang() == "tr" else note_text_en

var _base_pos := Vector2.ZERO
var _time := 0.0
var _state := 0 # 0: titreyerek bekliyor, 1: zarf açılıyor, 2: not ekranda açık, 3: kapandı
var _open_progress := 0.0
var _paper_slide := 0.0

var _main_node: Node2D = null
var _canvas_layer: CanvasLayer = null
var _note_overlay: ColorRect = null
var _note_card: Control = null
var _note_label: Label = null

func _ready():
	_base_pos = position
	if Engine.is_editor_hint():
		queue_redraw()
		return

	# Bölüm 7 (indeks 6) daha önce tamamlandıysa mektup ve hediye kutusu tekrar çıkmasın
	if GameProgress.is_completed(6):
		hide()
		queue_free()
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	_main_node = get_parent() as Node2D
	_build_note_ui()

func _input(event: InputEvent):
	if Engine.is_editor_hint() or _state != 0 or get_tree().paused:
		return
	if is_instance_valid(_main_node) and _main_node.get("game_over") == true:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos := get_global_mouse_position()
		if Rect2(-38.0, -28.0, 76.0, 56.0).has_point(to_local(mouse_pos)):
			get_viewport().set_input_as_handled()
			_trigger_open_letter()

func _process(delta: float):
	if Engine.is_editor_hint():
		return

	if _state == 0:
		if get_tree().paused:
			return
		_time += delta

		# Mektubun dikkat çekici şekilde titreme (shake) ve hafif süzülme hareketi
		var shake_burst := 0.4 + 0.6 * pow(maxf(0.0, sin(_time * 4.5)), 2.0)
		var shake_x := sin(_time * 48.0) * 3.2 * shake_burst
		var shake_y := cos(_time * 54.0) * 2.4 * shake_burst + sin(_time * 2.6) * 4.0
		position = _base_pos + Vector2(shake_x, shake_y)
		rotation = sin(_time * 38.0) * 0.11 * shake_burst
		queue_redraw()

	elif _state == 1:
		_time += delta
		queue_redraw()

func _trigger_open_letter():
	_state = 1
	position = _base_pos
	rotation = 0.0

	if is_instance_valid(_main_node):
		_main_node.set("is_dragging", false)
		_main_node.queue_redraw()

	get_tree().paused = true

	if _note_label:
		_note_label.text = _get_localized_note()

	# 1) Zarf kapağının açılması, 2) içinden kağıdın yükselmesi, 3) büyük not ekranının belirmesi
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "scale", Vector2(1.28, 1.28), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_open_progress", 1.0, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_paper_slide", 1.0, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_show_full_note_popup)

func _show_full_note_popup():
	_state = 2
	if not _note_overlay or not _note_card:
		return
	_note_overlay.modulate.a = 0.0
	_note_overlay.show()
	_note_card.scale = Vector2(0.75, 0.75)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(_note_overlay, "modulate:a", 1.0, 0.22)
	tween.tween_property(_note_card, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_close_note_pressed():
	if _state != 2:
		return
	_state = 3

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	if _note_overlay:
		tween.tween_property(_note_overlay, "modulate:a", 0.0, 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(func():
		if _note_overlay:
			_note_overlay.hide()
		get_tree().paused = false
		if is_instance_valid(_main_node):
			var gift := Node2D.new()
			gift.name = "GiftPortal"
			gift.set_script(GiftPortalScript)
			gift.main_node = _main_node
			gift.ball = _main_node.get_node_or_null("Ball") as RigidBody2D
			_main_node.add_child(gift)
		queue_free()
	)

func _build_note_ui():
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 5
	_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas_layer)

	_note_overlay = ColorRect.new()
	_note_overlay.visible = false
	_note_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_note_overlay.color = Color(0.04, 0.07, 0.15, 0.65)
	_canvas_layer.add_child(_note_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_note_overlay.add_child(center)

	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(480, 310)
	card_panel.pivot_offset = Vector2(240, 155)
	_note_card = card_panel

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#F7EBD2")
	style.border_color = Color("#B8935E")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 18
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 26
	style.content_margin_bottom = 24
	card_panel.add_theme_stylebox_override("panel", style)
	center.add_child(card_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	card_panel.add_child(vbox)

	var header_font := SystemFont.new()
	header_font.font_names = PackedStringArray(["Georgia", "Segoe UI Semibold", "Segoe UI", "Arial"])
	header_font.font_weight = 600

	var body_font := SystemFont.new()
	body_font.font_names = PackedStringArray(["Georgia", "Segoe UI", "Calibri", "Arial"])
	body_font.font_weight = 400

	var header := Label.new()
	header.text = "✉  MEKTUP" if GameProgress.get_lang() == "tr" else "✉  LETTER"
	header.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_override("font", header_font)
	header.add_theme_color_override("font_color", Color("#5C3118"))
	header.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	header.add_theme_constant_override("outline_size", 0)
	header.add_theme_constant_override("shadow_outline_size", 0)
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color("#D4B483")
	vbox.add_child(sep)

	_note_label = Label.new()
	_note_label.text = _get_localized_note()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_note_label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	_note_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_note_label.add_theme_font_override("font", body_font)
	_note_label.add_theme_color_override("font_color", Color("#2B1B10"))
	_note_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_note_label.add_theme_constant_override("outline_size", 0)
	_note_label.add_theme_constant_override("shadow_outline_size", 0)
	_note_label.add_theme_constant_override("line_spacing", 6)
	_note_label.add_theme_font_size_override("font_size", 21)
	vbox.add_child(_note_label)

	var close_btn := Button.new()
	close_btn.text = "KAPAT" if GameProgress.get_lang() == "tr" else "CLOSE"
	close_btn.custom_minimum_size = Vector2(160, 44)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_on_close_note_pressed)
	vbox.add_child(close_btn)

func _draw():
	var ew := 56.0
	var eh := 36.0
	var hw := ew * 0.5
	var hh := eh * 0.5

	# Mektup etrafındaki sıcak parıltı (glow)
	var glow_alpha := 0.24 + 0.08 * sin(_time * 5.0)
	draw_circle(Vector2.ZERO, 38.0, Color(1.0, 0.85, 0.45, glow_alpha))

	# 1. Zarfın arka iç yüzeyi
	draw_rect(Rect2(-hw, -hh, ew, eh), Color("#C9AE7E"))

	# Zarfın üst üçgen kapağı açıldıysa (yukarı kalktıysa) kağıdın ARKASINDA kalsın
	var flap_tip_y := lerpf(5.0, -hh - 17.0, _open_progress)
	var flap_color := Color("#DEC292") if _open_progress < 0.5 else Color("#D4B582")
	var top_flap := PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(0.0, flap_tip_y),
	])
	var top_flap_outline := PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(0.0, flap_tip_y),
		Vector2(hw, -hh),
	])
	if _open_progress >= 0.45:
		draw_colored_polygon(top_flap, flap_color)
		draw_polyline(top_flap_outline, Color("#8C6A3E"), 1.8)
		draw_line(Vector2(-hw, -hh), Vector2(hw, -hh), Color("#AD8B57"), 1.4)

	# 2. Zarf açılırken yukarı doğru çıkan küçük kağıt not (açık kapağın önünde, ön cebin arkasında)
	if _paper_slide > 0.0:
		var slide_y := lerpf(0.0, -24.0, _paper_slide)
		var paper_rect := Rect2(-hw * 0.78, -hh + 4.0 + slide_y, ew * 0.78, eh * 0.85)
		draw_rect(paper_rect, Color("#FFF9EB"))
		draw_rect(paper_rect, Color("#B89868"), false, 1.5)
		# Kağıt üzerindeki küçük yazı çizgileri
		for i in range(3):
			var ly := paper_rect.position.y + 8.0 + i * 6.5
			draw_line(
				Vector2(paper_rect.position.x + 6.0, ly),
				Vector2(paper_rect.position.x + paper_rect.size.x - 6.0, ly),
				Color("#6E5236", 0.75),
				1.6
			)

	# 3. Zarfın sol, sağ ve alt ön cep katlama üçgenleri
	var left_fold := PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(0.0, 2.0),
		Vector2(-hw, hh),
	])
	draw_colored_polygon(left_fold, Color("#EAD4AC"))

	var right_fold := PackedVector2Array([
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(0.0, 2.0),
	])
	draw_colored_polygon(right_fold, Color("#E2C89B"))

	var bottom_fold := PackedVector2Array([
		Vector2(-hw, hh),
		Vector2(0.0, -2.0),
		Vector2(hw, hh),
	])
	draw_colored_polygon(bottom_fold, Color("#F5E3BE"))
	draw_line(Vector2(-hw, hh), Vector2(0.0, -2.0), Color("#C4A472"), 1.4)
	draw_line(Vector2(hw, hh), Vector2(0.0, -2.0), Color("#C4A472"), 1.4)

	# 4. Zarfın üst kapağı henüz kapalıysa ön yüzde çizilir
	if _open_progress < 0.45:
		draw_colored_polygon(top_flap, flap_color)
		draw_polyline(top_flap_outline, Color("#AD8B57"), 1.5)
		draw_rect(Rect2(-hw, -hh, ew, eh), Color("#8C6A3E"), false, 2.0)
	else:
		# Kapak açıkken üst kenar çizgisi kağıdın üstünden geçmesin; sadece sol, alt ve sağ çerçeveyi çiz
		var pocket_border := PackedVector2Array([
			Vector2(-hw, -hh),
			Vector2(-hw, hh),
			Vector2(hw, hh),
			Vector2(hw, -hh),
		])
		draw_polyline(pocket_border, Color("#8C6A3E"), 2.0)

	# 5. Kırmızı mum mühür (kapalıyken görünür)
	if _open_progress < 0.35:
		draw_circle(Vector2(0.0, 4.0), 5.5, Color("#B8252A"))
		draw_circle(Vector2(-1.2, 2.8), 2.0, Color("#E3565B"))
