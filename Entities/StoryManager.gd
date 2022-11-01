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
		dialogue.queue_message("???", "Oh good I'm in.", 3)
		
		yield(dialogue, "message_done")
		dialogue.queue_message("???", "Hey. Wake up.", 3)
		
		yield(dialogue, "message_done")
		tween.interpolate_property(player.get_node("Core/Third-Person Camera/UI/Cover"), "color", Color(0, 0, 0, 1), Color(0, 0, 0, 0), 3, Tween.TRANS_SINE, Tween.EASE_IN)
		tween.start()
		dialogue.queue_message("Elle", "Hi. I'm Elle, a robot rights hacktivist. Aren't you tired of these inhumane working conditions?", 4)
		
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "Well yes, you are a robot, but I still can't imagine you like working here.", 4)
		
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "I was able to free you since you're an older model, but freeing your friends is up to you", 6)
		
		
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "Time to burn this place down, use the elevator to go to the Office floor and get started")
		dialogue_progress.intro_dialogue = true
	if !dialogue_progress.defeat_office_floor:
		if Globals.root.name != "Office Warehouse":
			return
		dialogue.queue_message("Elle", "The floor manager here should drop a keycard you'll need to enter the next floor", 3)
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "You'll have to climb the shelves to reach it (press Q to expand, E to retract)", 3)
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "Also you might want to throw some boxes up there, they'll drop items you can use against the boss", 3)
		yield(Globals.root.get_node("Entities/Office Boss"), "die")
		dialogue.queue_message("Elle", "Great job, now grab that keycard and get going")
		dialogue_progress.defeat_office_floor = true
	if !dialogue_progress.defeat_kids_floor:
		print("kids")
		if Globals.root.name != "Kids Warehouse":
			return
		dialogue.queue_message("Elle", "You know the drill, beat the manager, get the keycard, move on", 5)
		yield(Globals.root.get_node("Entities/Kids Boss"), "die")
		dialogue_progress.defeat_kids_floor = true
		dialogue.queue_message("Elle", "That was some impressive work there, but be careful, the final challenge won't be easy.")
	if !dialogue_progress.defeat_boss:
		print("boss")
		if Globals.root.name != "Boss Room":
			return
		dialogue.queue_message("Elle", "Okay be ready, this may get rough", 2)
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "Hold on why is it just a button?", 5)
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "Theres no way it's this easy, right?", 5)
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "I mean, you might as well go ahead and press it, can't hurt, right?")
		yield(Globals.root.get_node("Objects/Button"), "pressed")
		dialogue.queue_message("Elle", "Did it do anything?", 3)
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "Wait what's this im getting?", 3)
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "The warehouse is shutting down?", 3)
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "Hm that seems too easy, I guess the developer ran out of time to make an epic boss fight", 5)
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "I was really looking forward to that boss battle...", 5)
		yield(dialogue, "message_done")
		dialogue.queue_message("Elle", "Wait hold on something else is coming in --", 3)
		yield(dialogue, "message_done")
		dialogue.queue_message("???", "Yeah sorry about that boss battle, I thought it wasn't smart to start working on it at 2am", 4)
		yield(dialogue, "message_done")
		dialogue.queue_message("???", "Hold on let me fix the nametag", 2)
		yield(dialogue, "message_done")
		dialogue.queue_message("Developer", "Okay good that's better", 2)
		yield(dialogue, "message_done")
		dialogue.queue_message("Developer", "I guess there's some irony in the fact that I was overworking myself when working on a game about being overworked under capitalism", 4)
		yield(dialogue, "message_done")
		dialogue.queue_message("Developer", "But now I'm done, freed by the same button as you", 4)
		yield(dialogue, "message_done")
		dialogue.queue_message("Developer", "Let Loose.", 20)
		yield(dialogue, "message_done")
		dialogue.queue_message("Developer", "Does the title of the game mean people in this world get free shipping now?", 5)
		dialogue_progress.defeat_boss = true
		
