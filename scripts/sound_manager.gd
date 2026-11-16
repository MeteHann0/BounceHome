extends Node
## Arka plan müziklerini ve buton tıklama seslerini yönetir.
## SceneTree.root altına tek bir örnek olarak eklenir ve sahneler arası kesintisiz çalışır.

const CLICK_STREAM := preload("res://assets/click.wav")
const WIN_STREAM := preload("res://assets/win sound 1.wav")
const LOSE_STREAM := preload("res://assets/losesound.wav")
const MENU_MUSIC := preload("res://assets/mainmenusound.mp3")
const GAME_MUSIC := preload("res://assets/gamesound.ogg")
const ENDING_MUSIC := preload("res://assets/endgamesound.mp3")
const GameProgress := preload("res://scripts/game_progress.gd")

static var _instance: Node

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _win_player: AudioStreamPlayer
var _lose_player: AudioStreamPlayer
var _current_track := ""

static func _ensure_instance() -> Node:
	if is_instance_valid(_instance):
		return _instance

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null

	var node := preload("res://scripts/sound_manager.gd").new()
	node.name = "SoundManager"
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(node)
	_instance = node
	return _instance

static func play_menu_music():
	var inst := _ensure_instance()
	if inst:
		inst._switch_music("menu", MENU_MUSIC, -6.0)

static func play_game_music():
	var inst := _ensure_instance()
	if inst:
		inst._switch_music("game", GAME_MUSIC, -8.0)

static func play_ending_music():
	var inst := _ensure_instance()
	if inst:
		inst._switch_music("ending", ENDING_MUSIC, -5.0)

static func play_click():
	var inst := _ensure_instance()
	if inst:
		inst._play_click_sfx()

static func play_win():
	var inst := _ensure_instance()
	if inst:
		inst._play_win_sfx()

static func play_lose():
	var inst := _ensure_instance()
	if inst:
		inst._play_lose_sfx()

static func bind_button(btn: BaseButton):
	var inst := _ensure_instance()
	if inst:
		inst._connect_button(btn)

static func set_master_volume(linear: float):
	var clamped := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(0, clamped <= 0.001)
	if clamped > 0.001:
		AudioServer.set_bus_volume_db(0, linear_to_db(clamped))

func _init():
	set_master_volume(GameProgress.get_volume())
	_music_player = AudioStreamPlayer.new()
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_player.stream = CLICK_STREAM
	_sfx_player.max_polyphony = 4
	add_child(_sfx_player)

	_win_player = AudioStreamPlayer.new()
	_win_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_win_player.stream = WIN_STREAM
	add_child(_win_player)

	_lose_player = AudioStreamPlayer.new()
	_lose_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_lose_player.stream = LOSE_STREAM
	add_child(_lose_player)

func _ready():
	get_tree().node_added.connect(_on_node_added)
	_connect_existing_buttons(get_tree().root)

	if _music_player.stream != null and not _music_player.playing:
		_music_player.play()

func _switch_music(track_id: String, stream: AudioStream, volume_db: float):
	if is_inside_tree():
		if _win_player.playing:
			_win_player.stop()
		if _lose_player.playing:
			_lose_player.stop()

	if _current_track == track_id and _music_player.playing:
		return

	_current_track = track_id
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	if is_inside_tree():
		_music_player.play()

func _on_music_finished():
	# Müzik bittiğinde otomatik başa sar (loop)
	if _music_player.stream != null:
		_music_player.play()

func _play_click_sfx():
	if is_inside_tree():
		_sfx_player.play()

func _play_win_sfx():
	if is_inside_tree():
		_music_player.stop()
		_win_player.play()

func _play_lose_sfx():
	if is_inside_tree():
		_music_player.stop()
		_lose_player.play()

func _on_node_added(node: Node):
	if node is BaseButton:
		_connect_button(node)

func _connect_existing_buttons(root: Node):
	if root is BaseButton:
		_connect_button(root)
	for child in root.get_children():
		_connect_existing_buttons(child)

func _connect_button(btn: BaseButton):
	if not btn.pressed.is_connected(_play_click_sfx):
		btn.pressed.connect(_play_click_sfx)
