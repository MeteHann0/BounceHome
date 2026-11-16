
extends Node2D
## Sadece görsel kara delik (fizik/çarpışma yok).
## Intro gibi sahnelerde kullanılır. Görünüm target.gd ile aynıdır.

const CORE_COLOR := Color("#12001F")
const MAIN_COLOR := Color("#C13CFF")
const LIGHT_COLOR := Color("#F0B8FF")
const GLOW_COLOR := Color("#E9A8FF")

## Girdabın normal dönüş hızı
@export var spin_speed: float = 2.0
## Etrafta içe doğru akan parçacık sayısı
@export var particle_count: int = 16

## Dönüş/akış hız çarpanı (çekim anında artırılır)
var speed_mult := 1.0

var time := 0.0
var swirl_angle := 0.0
var particles: Array = []

func _ready():
	for i in particle_count:
		particles.append(_new_particle(randf_range(14.0, 50.0)))

func _new_particle(radius: float) -> Dictionary:
	return {
		"angle": randf() * TAU,
		"radius": radius,
		"speed": randf_range(10.0, 22.0),
		"size": randf_range(1.2, 2.4),
	}

func _process(delta):
	if not visible:
		return

	time += delta
	swirl_angle += delta * spin_speed * speed_mult

	for p in particles:
		p["radius"] -= p["speed"] * delta * speed_mult
		p["angle"] += delta * (60.0 / max(p["radius"], 6.0)) * speed_mult

		if p["radius"] < 12.0:
			p.merge(_new_particle(randf_range(44.0, 52.0)), true)

	queue_redraw()

func _draw():
	var pulse := 0.5 + 0.5 * sin(time * 3.0)

	# Dış parıltı
	for i in range(6):
		draw_circle(Vector2.ZERO, 50.0 - i * 4.0, Color(MAIN_COLOR, 0.04 + i * 0.02))

	# Nabız gibi atan dış halka
	draw_arc(Vector2.ZERO, 32.0 + pulse * 2.0, 0, TAU, 64, Color(LIGHT_COLOR, 0.5 + 0.3 * pulse), 2.0)

	# Toplanma diski
	draw_circle(Vector2.ZERO, 28.0, Color(MAIN_COLOR, 0.85))

	# Dönen spiral kollar
	var arms := 4
	for a in arms:
		var points := PackedVector2Array()
		var base_angle: float = swirl_angle + a * TAU / arms

		for s in 16:
			var k: float = s / 15.0
			var r: float = lerp(30.0, 11.0, k)
			points.append(Vector2.from_angle(base_angle + k * 2.6) * r)

		draw_polyline(points, Color(LIGHT_COLOR, 0.75), 2.5, true)

	# İçe doğru akan parçacıklar
	for p in particles:
		var alpha: float = clamp((p["radius"] - 12.0) / 20.0, 0.0, 1.0)
		draw_circle(Vector2.from_angle(p["angle"]) * p["radius"], p["size"], Color(GLOW_COLOR, alpha))

	# Olay ufku
	draw_circle(Vector2.ZERO, 14.5, MAIN_COLOR.darkened(0.55))
	draw_circle(Vector2.ZERO, 12.0, CORE_COLOR)
	draw_arc(Vector2.ZERO, 12.5, 0, TAU, 48, Color(GLOW_COLOR, 0.6 + 0.4 * pulse), 1.5)
