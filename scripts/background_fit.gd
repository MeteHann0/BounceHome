@tool
extends Sprite2D
## Arka plan görselinin tamamının (1280x720) ekrana tam oturmasını sağlar.

## İşaretlenirse görselin alt kısmının Ground (zemin) altında kalmaması için
## görselin tamamını zeminin üstündeki alana (1280x610) sığdırır.
@export var fit_above_ground: bool = false:
	set(value):
		fit_above_ground = value
		_update_fit()

func _ready():
	_update_fit()
	if not texture_changed.is_connected(_update_fit):
		texture_changed.connect(_update_fit)

func _update_fit():
	if not texture:
		return
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	if fit_above_ground:
		position = Vector2(640.0, 305.0)
		scale = Vector2(1280.0 / tex_size.x, 610.0 / tex_size.y)
	else:
		position = Vector2(640.0, 360.0)
		scale = Vector2(1280.0 / tex_size.x, 720.0 / tex_size.y)
