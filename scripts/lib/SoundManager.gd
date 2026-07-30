extends Node

const MAX_PLAYERS = 12

var _players: Array[AudioStreamPlayer2D] = []

func _ready():
	for i in range(MAX_PLAYERS):
		var p = AudioStreamPlayer2D.new()
		p.name = "SFXPlayer_%d" % i
		add_child(p)
		_players.append(p)

func play(name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	var path = "res://assets/sounds/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	var stream = load(path) as AudioStream
	if not stream:
		return
	var player = _find_free_player()
	if not player:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

func _find_free_player() -> AudioStreamPlayer2D:
	for p in _players:
		if not p.playing:
			return p
	return null