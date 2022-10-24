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
		player.get_node("Core/Third-Person Camera/UI/Cover").visible = true
		dialogue.queue_message("Oh good I made it in.", 3)
		
		yield(dialogue, "message_done")
		dialogue.queue_message("Hey. Wake up.", 3)
		
		yield(dialogue, "message_done")
		tween.interpolate_property(player.get_node("Core/Third-Person Camera/UI/Cover"), "color", Color(0, 0, 0, 1), Color(0, 0, 0, 0), 3, Tween.TRANS_SINE, Tween.EASE_IN)
		tween.start()
		dialogue.queue_message("Aren't you tired of these inhumane working conditions?", 4)
		
		yield(dialogue, "message_done")
		dialogue.queue_message("Well yes, you are a robot, but I still can't imagine you like working here.", 4)
		
		yield(dialogue, "message_done")
		dialogue.queue_message("I was able to free you since you're an older model, but freeing your friends is up to you", 6)
		
		
		yield(dialogue, "message_done")
		dialogue.queue_message("Time to burn this place down, use the elevator to go to the Office floor and get started")
		dialogue_progress.intro_dialogue = true
	if !dialogue_progress.defeat_office_floor:
		if Globals.root.name != "Office Warehouse":
			return
		dialogue.queue_message("The floor manager here should drop a keycard you'll need to enter B.E.Z.O.S.'s floor", 3)
		yield(dialogue, "message_done")
		dialogue.queue_message("You'll have to climb the shelves to reach it (press Q to expand, E to retract)", 3)
		yield(dialogue, "message_done")
		dialogue.queue_message("Also you might want to throw some boxes up there, they'll drop items you can use against the boss", 3)
		yield(Globals.root.get_node("Entities/Office Boss"), "die")
		dialogue.queue_message("Great job, now grab that keycard and get going")
		dialogue_progress.defeat_office_floor = true
	if !dialogue_progress.defeat_kids_floor:
		print("kids")
		if Globals.root.name != "Kids Warehouse":
			return
		dialogue.queue_message("You know the drill, beat the manager, get the keycard, move on", 5)
		yield(Globals.root.get_node("Entities/Kids Boss"), "die")
		dialogue_progress.defeat_kids_floor = true
		dialogue.queue_message("That was some impressive work there, but be careful, the final challenge won't be easy.")
	if !dialogue_progress.defeat_boss:
		print("boss")
		if Globals.root.name != "Boss Room":
			return
		dialogue.queue_message("Okay be ready, this may get rough", 1)
		yield(dialogue, "message_done")
		dialogue.queue_message("Hold on why is it just a button?", 5)
		yield(dialogue, "message_done")
		dialogue.queue_message("Theres no way it's this easy, right?", 5)
		yield(dialogue, "message_done")
		dialogue.queue_message("I mean, you might as well go ahead and press it, can't hurt, right?")
		yield(Globals.root.get_node("Objects/Button"), "pressed")
		dialogue.queue_message("Did it do anything?", 3)
		yield(dialogue, "message_done")
		dialogue.queue_message("Wait what's this im getting?", 3)
		yield(dialogue, "message_done")
		dialogue.queue_message("The warehouse is shutting down?", 3)
		yield(dialogue, "message_done")
		dialogue.queue_message("Hm that seems too easy, I guess the developer ran out of time to make an epic boss fight", 5)
		yield(dialogue, "message_done")
		dialogue.queue_message("I guess he also ran out of time to add sounds, that'd explain why things have been so quiet and I don't have a name or face", 5)
		yield(dialogue, "message_done")
		dialogue.queue_message("I was really looking forward to that boss battle...", 5)
		yield(dialogue, "message_done")
		dialogue.queue_message("Well congrats I guess", 3)
		dialogue_progress.defeat_boss = true
		
