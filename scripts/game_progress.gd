extends RefCounted
## Oyuncu ilerlemesini ve dil tercihini saklar (intro, tamamlanan bölümler, yıldızlar, dil).

const SAVE_PATH := "user://save.cfg"
const MENU_SCENE := "res://scenes/MainMenu.tscn"
const INTRO_SCENE := "res://scenes/Intro.tscn"
const ENDING_SCENE := "res://scenes/Ending.tscn"

## Tüm bölümler. "scene" boş olan bölümler henüz yapılmamıştır ("SOON" / "YAKINDA" olarak görünür).
const LEVELS := [
	{"name_en": "Green Valley", "name_tr": "Yeşil Vadi", "scene": "res://main.tscn"},
	{"name_en": "Sandy Desert", "name_tr": "Kumlu Çöl", "scene": "res://scenes/level2.tscn"},
	{"name_en": "Glacier Hills", "name_tr": "Buzul Tepeler", "scene": "res://scenes/level3.tscn"},
	{"name_en": "Mushroom Woods", "name_tr": "Mantar Ormanı", "scene": "res://scenes/level4.tscn"},
	{"name_en": "Volcano Island", "name_tr": "Volkan Adası", "scene": "res://scenes/level5.tscn"},
	{"name_en": "Cloud City", "name_tr": "Bulut Şehri", "scene": "res://scenes/level6.tscn"},
	{"name_en": "Crystal Cave", "name_tr": "Kristal Mağara", "scene": "res://scenes/level7.tscn"},
	{"name_en": "Night Swamp", "name_tr": "Gece Bataklığı", "scene": "res://scenes/level8.tscn"},
	{"name_en": "Lost Atlantis", "name_tr": "Kayıp Atlantis", "scene": "res://scenes/level9.tscn"},
	{"name_en": "Cyber Neon City", "name_tr": "Siber Neon Şehri", "scene": "res://scenes/level10.tscn"},
	{"name_en": "Rusty Factory", "name_tr": "Paslı Fabrika", "scene": "res://scenes/level11.tscn"},
	{"name_en": "Final Horizon", "name_tr": "Son Kara Delik", "scene": "res://scenes/level12.tscn"},
]

const TEXTS := {
	"en": {
		"subtitle": "A little ball's journey back home",
		"worlds_waiting": "%d worlds await you",
		"progress_short": "%d / %d levels   •   %d Stars",
		"start": "PLAY",
		"levels": "LEVELS",
		"settings": "SETTINGS",
		"quit": "QUIT",
		"back": "BACK",
		"sound_volume": "VOLUME",
		"levels_summary": "%d / %d levels completed   •   %d / %d Stars",
		"card_play": "PLAY",
		"card_soon": "SOON",
		"skip": "SKIP",
		"story_0": "In a universe far, far away lived a little ball.",
		"story_1": "One day, an unfortunate black hole swallowed it whole",
		"story_2": "and the little ball found itself in a completely unknown world.",
		"story_3": "There is only one way home: cross 12 worlds and pass through every black hole.",
		"ending_0": "Passing through the final black hole, the little ball finally reached its own universe...",
		"ending_1": "All around, thousands of balls floated joyfully in its warm and safe home.",
		"ending_2": "And at last, it held tight to the family that had been waiting for it with longing.",
		"ending_3": "It was finally home. The journey was complete!   •   THE END",
		"ending_credits": "You beat the game!\n\nThank you endlessly for not leaving me alone on this incredible adventure.\n\nI am a developer who is just stepping into the world of games, and with your support, I truly believe I can reach even greater heights.\n\nOnce again, I offer you my heartfelt thanks.\n\nIf there is anything I can improve or any topic at all, feel free to reach out to me on LinkedIn.\n\nSee you next time!",
		"moves": "MOVES: %d",
		"paused": "PAUSED",
		"resume": "RESUME",
		"restart": "RESTART",
		"main_menu": "MAIN MENU",
		"game_over": "GAME OVER",
		"out_of_bounds": "The ball went out of bounds!",
		"fell_in_lava": "The ball fell into the lava!",
		"struck_by_lightning": "Struck by lightning and turned to ash!",
		"sunk_in_swamp": "The ball sank into the swamp!",
		"shocked_by_jellyfish": "Shocked by an electric jellyfish!",
		"hit_by_laser": "The ball hit a cyber laser!",
		"crushed_by_press": "Crushed by a hydraulic press!",
		"swallowed_by_black_hole": "The ball strayed off course into another universe, mission failed!",
		"try_again": "TRY AGAIN",
		"level_complete": "LEVEL COMPLETE!",
		"finished_in_1": "Finished in 1 move",
		"finished_in_n": "Finished in %d moves",
		"retry": "RETRY",
		"menu": "MENU",
		"next": "NEXT",
		"end": "THE END",
		"lang_btn": "LANG: EN",
		"info_title": "ABOUT & GUIDE",
		"how_to_play_title": "HOW TO PLAY",
		"how_to_play_desc": "Drag from the ball to aim, release to launch, and enter the black hole!",
		"stars_title": "STAR SYSTEM",
		"stars_rules": "3 Stars :  1–2 moves\n2 Stars :  3 moves\n1 Star   :  4+ moves",
		"replay_story": "REPLAY STORY",
		"credits_dev": "Developer: Metehan Çetiner",
		"credits_ver": "Version: v2.0.0   •   Made with Godot Engine",
	},
	"tr": {
		"subtitle": "Küçük topun eve dönüş yolculuğu",
		"worlds_waiting": "%d dünya seni bekliyor",
		"progress_short": "%d / %d bölüm   •   %d Yıldız",
		"start": "BAŞLA",
		"levels": "BÖLÜMLER",
		"settings": "AYARLAR",
		"quit": "ÇIKIŞ",
		"back": "GERİ",
		"sound_volume": "SES SEVİYESİ",
		"levels_summary": "%d / %d bölüm tamamlandı   •   %d / %d Yıldız",
		"card_play": "OYNA",
		"card_soon": "YAKINDA",
		"skip": "GEÇ",
		"story_0": "Çookkk uzak bir evrende küçük bir top yaşardı.",
		"story_1": "Bir gün talihsiz bir şekilde bir kara delik onu yuttu",
		"story_2": "ve küçük top kendini hiç tanımadığı bir dünyada buldu.",
		"story_3": "Eve dönmenin tek yolu var: 12 dünyayı aş, her birindeki kara delikten geç.",
		"ending_0": "Son kara delikten geçen küçük top, nihayet kendi evrenine ulaştı...",
		"ending_1": "Etrafı binlerce topun neşeyle süzüldüğü, sıcak ve güvenli yuvasıyla çevriliydi.",
		"ending_2": "Ve en sonunda, onu özlemle bekleyen ailesine sımsıkı sarıldı.",
		"ending_3": "Artık evindeydi. Yolculuğu tamamlanmıştı!   •   SON",
		"ending_credits": "Oyunu bitirdiniz!\n\nBeni bu akılalmaz macerada yalnız bırakmadığınız için sonsuz teşekkürler.\n\nOyun dünyasına daha yeni yeni giren bir geliştiriciyim, sizin de desteklerinizle beraber daha da iyi yerlere gelebileceğime inancım tam.\n\nTekrardan sizlere teşekkürlerimi sunuyorum.\n\nEğer geliştirebileceğim bir kısım ya da herhangi bir konu varsa benimle LinkedIn platformu üzerinden iletişime geçebilirsiniz.\n\nSonra görüşmek üzere!",
		"moves": "HAMLE: %d",
		"paused": "DURAKLATILDI",
		"resume": "DEVAM ET",
		"restart": "YENİDEN BAŞLAT",
		"main_menu": "ANA MENÜ",
		"game_over": "OYUN BİTTİ",
		"out_of_bounds": "Top sahadan çıktı!",
		"fell_in_lava": "Top lava düştü!",
		"struck_by_lightning": "Şimşek çarptı ve top kül oldu!",
		"sunk_in_swamp": "Top bataklığa saplandı!",
		"shocked_by_jellyfish": "Top elektrikli denizanasından çarpıldı!",
		"hit_by_laser": "Top siber lazere değdi!",
		"crushed_by_press": "Top hidrolik prese ezildi!",
		"swallowed_by_black_hole": "Top hedefinden saptı başka bir evrene gitti, görev başarısız!",
		"try_again": "TEKRAR DENE",
		"level_complete": "BÖLÜM TAMAM!",
		"finished_in_1": "1 hamlede bitirdin",
		"finished_in_n": "%d hamlede bitirdin",
		"retry": "TEKRAR",
		"menu": "MENÜ",
		"next": "SONRAKİ",
		"end": "SON",
		"lang_btn": "DİL: TR",
		"info_title": "REHBER & HAKKINDA",
		"how_to_play_title": "NASIL OYNANIR?",
		"how_to_play_desc": "Topu tutup çekerek nişan al, bırakarak fırlat ve kara deliğe ulaş!",
		"stars_title": "YILDIZ SİSTEMİ",
		"stars_rules": "3 Yıldız :  1–2 hamle\n2 Yıldız :  3 hamle\n1 Yıldız :  4+ hamle",
		"replay_story": "HİKAYEYİ TEKRAR İZLE",
		"credits_dev": "Geliştirici: Metehan Çetiner",
		"credits_ver": "Sürüm: v2.0.0   •   Godot Engine ile yapıldı",
	},
}

## Şu an oynanan bölümün indeksi (0'dan başlar)
static var current_level := 0

static var _config: ConfigFile

static func _get_config() -> ConfigFile:
	if _config == null:
		_config = ConfigFile.new()
		_config.load(SAVE_PATH)
	return _config

static func _save():
	_get_config().save(SAVE_PATH)

# ------------------------------------------------------------
# Dil (Varsayılan: İngilizce "en")
# ------------------------------------------------------------

static func get_lang() -> String:
	var lang: String = _get_config().get_value("settings", "lang", "en")
	return lang if TEXTS.has(lang) else "en"

static func set_lang(lang: String):
	if not TEXTS.has(lang):
		return
	_get_config().set_value("settings", "lang", lang)
	_save()

static func toggle_lang() -> String:
	var next_lang := "tr" if get_lang() == "en" else "en"
	set_lang(next_lang)
	return next_lang

static func t(key: String) -> String:
	var lang := get_lang()
	return TEXTS[lang].get(key, key)

# ------------------------------------------------------------
# Ses seviyesi (0.0 - 1.0, Varsayılan: 1.0)
# ------------------------------------------------------------

static func get_volume() -> float:
	return clampf(_get_config().get_value("settings", "volume", 1.0), 0.0, 1.0)

static func set_volume(value: float):
	_get_config().set_value("settings", "volume", clampf(value, 0.0, 1.0))
	_save()

# ------------------------------------------------------------
# Intro
# ------------------------------------------------------------

static func is_intro_seen() -> bool:
	return _get_config().get_value("progress", "intro_v3_seen", false)

static func mark_intro_seen():
	_get_config().set_value("progress", "intro_v3_seen", true)
	_save()

static func is_tutorial_video_seen() -> bool:
	return _get_config().get_value("progress", "tutorial_video_seen", false)

static func mark_tutorial_video_seen():
	_get_config().set_value("progress", "tutorial_video_seen", true)
	_save()

# ------------------------------------------------------------
# Bölüm bilgileri
# ------------------------------------------------------------

static func level_count() -> int:
	return LEVELS.size()

static func get_level_name(index: int) -> String:
	var key := "name_tr" if get_lang() == "tr" else "name_en"
	return LEVELS[index][key]

static func has_scene(index: int) -> bool:
	if index < 0 or index >= LEVELS.size():
		return false
	var path: String = LEVELS[index]["scene"]
	return path != "" and ResourceLoader.exists(path)

static func get_stars(index: int) -> int:
	return _get_config().get_value("levels", "level_%d" % (index + 1), 0)

static func is_completed(index: int) -> bool:
	return get_stars(index) > 0

static func is_unlocked(index: int) -> bool:
	return index == 0 or is_completed(index - 1)

static func is_playable(index: int) -> bool:
	return is_unlocked(index) and has_scene(index)

static func completed_count() -> int:
	var count := 0
	for i in LEVELS.size():
		if is_completed(i):
			count += 1
	return count

static func total_stars() -> int:
	var total := 0
	for i in LEVELS.size():
		total += get_stars(i)
	return total

## PLAY / BAŞLA butonunun açacağı bölüm: ilk tamamlanmamış oynanabilir bölüm,
## yoksa oynanabilir son bölüm.
static func get_continue_level() -> int:
	var last_playable := 0
	for i in LEVELS.size():
		if not is_playable(i):
			continue
		if not is_completed(i):
			return i
		last_playable = i
	return last_playable

## Bölümü tamamlandı olarak kaydeder (sadece en iyi yıldız sayısı saklanır).
static func complete_level(index: int, stars: int):
	if stars > get_stars(index):
		_get_config().set_value("levels", "level_%d" % (index + 1), stars)
		_save()

# ------------------------------------------------------------
# Sahne geçişleri
# ------------------------------------------------------------

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

static func start_level(index: int) -> bool:
	if not is_playable(index):
		return false
	current_level = index
	_tree().change_scene_to_file(LEVELS[index]["scene"])
	return true

static func has_next_level() -> bool:
	return is_playable(current_level + 1)

static func start_next_level() -> bool:
	return start_level(current_level + 1)

static func go_to_menu():
	_tree().change_scene_to_file(MENU_SCENE)

static func go_to_ending():
	_tree().change_scene_to_file(ENDING_SCENE)

static func replay_intro():
	_get_config().set_value("progress", "intro_v3_seen", false)
	_get_config().set_value("progress", "tutorial_video_seen", false)
	_save()
	_tree().change_scene_to_file(INTRO_SCENE)
