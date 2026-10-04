extends Node
## Progress that outlives a single level: clearance and the like.

signal clearance_changed(level: int)

## Badge clearance. 0 opens Fulfillment; each zone holds the next card.
var clearance := 0:
	set(value):
		clearance = value
		clearance_changed.emit(value)
