class_name AudioCue
extends RefCounted
## 一次性音效/BGM 播放：挂到调用方节点下自行回收，不引入全局音频单例。

static func play(parent: Node, path: String, loop: bool = false, volume_db: float = 0.0) -> AudioStreamPlayer:
	if parent == null or DisplayServer.get_name() == "headless" or not ResourceLoader.exists(path):
		return null
	var player := AudioStreamPlayer.new()
	player.stream = load(path) as AudioStream
	player.volume_db = volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	if loop and player.stream != null:
		if player.stream is AudioStreamMP3 or player.stream is AudioStreamOggVorbis or player.stream is AudioStreamWAV:
			player.stream.set_loop(loop)
	parent.add_child(player)
	player.tree_exiting.connect(player.stop, CONNECT_ONE_SHOT)
	player.play()
	if not loop:
		player.finished.connect(player.queue_free)
	return player
