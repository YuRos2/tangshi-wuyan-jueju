extends Node
## Sfx —— 音效池（全部为程序生成的古意短音）

const SOUNDS := {
	"ui": "res://audio/ui.wav",
	"place": "res://audio/place.wav",
	"take": "res://audio/take.wav",
	"err": "res://audio/err.wav",
	"win": "res://audio/win.wav",
	"seal": "res://audio/seal.wav",
	"coin": "res://audio/coin.wav",
}

var enabled := true
var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func play(name: String, volume_db: float = -6.0, pitch_jitter: float = 0.03) -> void:
	if not enabled:
		return
	var stream: AudioStream = _cache.get(name)
	if stream == null:
		var path: String = SOUNDS.get(name, "")
		if path.is_empty() or not ResourceLoader.exists(path):
			return
		stream = load(path)
		_cache[name] = stream
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
