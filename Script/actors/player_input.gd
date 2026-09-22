extends ActorController
## 输入只提交意图，不设置速度、血量或战斗状态。

var source: ActorInputSource = ActionInputSource.new()

func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	source.sample(command)
	submit()
