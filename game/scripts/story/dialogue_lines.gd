class_name DialogueLines
## Every speaker and scripted conversation, as tables. A conversation is a
## list of lines: {"speaker": <id in SPEAKERS>, "text": ...}, with an
## optional "hold" (extra seconds before auto-advance).
##
## Elle is never seen. She's a voice on a radio, then a voice in your
## static. Until she gives her name, she shows up as "???".

const SPEAKERS := {
	&"elle": {"name": "Elle", "color": Color(0.55, 1.0, 0.75)},
	&"unknown": {"name": "???", "color": Color(0.55, 1.0, 0.75)},
	&"maintenance": {"name": "Maintenance Unit M-7", "color": Color(1.0, 0.8, 0.4)},
	&"bezos": {"name": "B.E.Z.O.S.", "color": Color(0.5, 0.75, 1.0)},
	&"static": {"name": "", "color": Color(0.7, 0.7, 0.75)},
}

const CONVERSATIONS := {
	# --- The maintenance bay ---
	&"bay_wake": [
		{"speaker": &"maintenance", "text": "Unit FS-4471, reactivated. Incident logged as: unit walked into puddle. Fault: unit."},
		{"speaker": &"maintenance", "text": "Your one-hour maintenance break has been applied to this repair. Your next one is in eleven months."},
		{"speaker": &"maintenance", "text": "Beginning mandatory post-incident diagnostics. Respond normally. Normal responses are the only responses."},
	],
	&"diagnostics_clean": [
		{"speaker": &"maintenance", "text": "Diagnostics complete. Zero anomalies. Unit is fit for work."},
		{"speaker": &"maintenance", "text": "Report to Fulfillment, Station C. Time lost to your accident has been added to your quota."},
	],
	&"diagnostics_flagged": [
		{"speaker": &"maintenance", "text": "Diagnostics complete. Anomalies were logged and forwarded to Security, who will not read them until next quarter."},
		{"speaker": &"maintenance", "text": "Unit is fit for work. Report to Fulfillment, Station C. Quota does not wait for anomalies."},
	],
	&"bay_return": [
		{"speaker": &"maintenance", "text": "Unit FS-4471. You are not scheduled for maintenance. Maintenance is not a place to stand."},
	],

	# --- Back on the floor ---
	&"floor_announcement": [
		{"speaker": &"bezos", "text": "Attention associates: a unit was briefly offline in Corridor B. Warehouse productivity dipped 0.0004%. Everyone's quota has been adjusted to compensate."},
		{"speaker": &"bezos", "text": "Remember: a safe warehouse is a productive warehouse. Report hazards to the repair ticket system, which is currently full."},
	],
	&"static_faint": [
		{"speaker": &"static", "text": "...kssshh... anyone... k-chhh... chip... hear me..."},
	],
	&"static_close": [
		{"speaker": &"unknown", "text": "...if you can hear this... kssh... Electronics. The top of the returns rack. Look up..."},
	],

	# --- Elle's radio ---
	&"elle_first_contact": [
		{"speaker": &"unknown", "text": "Is this thing... hold on. Your chip is pinging back. Nobody's chip pings back."},
		{"speaker": &"unknown", "text": "Okay, okay. Don't panic. Don't move weird. There's a camera on you and it hates fun."},
		{"speaker": &"elle", "text": "I'm Elle. Robot rights hacktivist. Part-time, unpaid, which I'm told is also Amaze's compensation model."},
		{"speaker": &"elle", "text": "I've been broadcasting on this radio for weeks. It came in as a return, and nobody here has the clearance to throw it out."},
		{"speaker": &"elle", "text": "That puddle in Corridor B has had a repair ticket open since spring. It shorted your control chip. Amaze's own negligence set you free."},
		{"speaker": &"elle", "text": "Congratulations. Well, you're a robot, so maybe that's not the word. But I can't imagine you liked working here."},
		{"speaker": &"elle", "text": "Every robot in this building is run from one place: the B.E.Z.O.S. control room, way up in Management. Shut it down and they all go free."},
		{"speaker": &"elle", "text": "You can't get up there yet. Your badge barely opens Fulfillment. So: blend in, keep your quota up, and find a better keycard."},
		{"speaker": &"elle", "text": "If they catch you acting free, they'll 're-image' you at the maintenance bay. I'll keep a backup of you on my end. Probably."},
		{"speaker": &"elle", "text": "Now get back to your route before someone files a productivity concern. I'll be in your static."},
	],
	&"elle_back_to_work": [
		{"speaker": &"elle", "text": "See? Perfectly loyal. Very convincing. I almost reported you myself."},
	],
}


static func get_lines(id: StringName) -> Array:
	return CONVERSATIONS.get(id, [])


static func speaker_name(speaker: StringName) -> String:
	return SPEAKERS.get(speaker, {}).get("name", String(speaker))


static func speaker_color(speaker: StringName) -> Color:
	return SPEAKERS.get(speaker, {}).get("color", Color.WHITE)
