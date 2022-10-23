extends Node

func _ready():
	var player = get_parent()
	var tween = get_node("../Tween")
	var dialogue = $"../Core/Third-Person Camera/UI/Dialogue"
	var dialogue_progress: DialogueProgress = Globals.save.dialogue_progress
	yield(get_tree(), "idle_frame")
	if !dialogue_progress.intro_dialogue:
		if Globals.root.name != "Maintenance":
			return
		player.get_node("Core/Third-Person Camera/UI/Cover").color.a = 255
		dialogue.queue_message("Oh good I made it in.", 3)
		
		yield(dialogue, "message_done")
		dialogue.queue_message("Hey. Wake up.", 3)
		tween.interpolate_property(player.get_node("Core/Third-Person Camera/UI/Cover"), "color:a", 255, 0, 3, Tween.TRANS_SINE, Tween.EASE_IN)
		
