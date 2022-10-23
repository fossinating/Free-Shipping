extends Action

class_name ConnectedAction

var connection

func _init(keybind, description, _connection).(keybind, description):
	self.connection = _connection


func trigger(player_ref):
	self.connection.trigger(player_ref)
