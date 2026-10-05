class_name SignalReceiver
extends Node
## Your fried control chip. It picks up static nobody else can hear, and
## the static gets stronger the closer you are to its source (Elle's radio).
## The HUD reads `get_static()` for the screen static and `get_bars()` for
## the signal meter; this node also plays the hiss itself.

## Bars on the HUD's signal meter.
const BARS := 5

@export var robot: RobotBody
## How fast the reading follows the real signal (per second).
@export var smoothing := 4.0
## Loudest the hiss gets, in dB.
@export var max_volume_db := -8.0

## A floor for the static, e.g. a faint hiss during the diagnostics.
var ambient := 0.0
## Whether the signal meter is on and strength counts.
var tracking := false
## Smoothed signal strength, 0 to 1.
var strength := 0.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback


func _ready() -> void:
	# No audio device to feed in headless runs.
	if DisplayServer.get_name() == "headless":
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.2
	_player = AudioStreamPlayer.new()
	_player.stream = generator
	_player.volume_db = -80.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


## Signal strength right where the robot's core is, unsmoothed.
func get_raw_strength() -> float:
	if robot == null:
		return 0.0
	return Radio.strongest_at(get_tree(), robot.get_core_position())


## How strong the static is overall (screen static and hiss), 0 to 1.
func get_static() -> float:
	return maxf(ambient, strength if tracking else 0.0)


## Signal meter bars, 0 to BARS.
func get_bars() -> int:
	return ceili(strength * BARS - 0.05) if tracking else 0


func _process(delta: float) -> void:
	var target := get_raw_strength() if tracking else 0.0
	strength = lerpf(strength, target, 1.0 - exp(-smoothing * delta))
	if _playback:
		_feed_hiss()


func _feed_hiss() -> void:
	var level := get_static()
	_player.volume_db = linear_to_db(maxf(level, 0.0001)) + max_volume_db
	var frames := mini(_playback.get_frames_available(), 2048)
	for i in frames:
		# Crackle: mostly soft noise with the odd pop.
		var sample := randf_range(-0.4, 0.4)
		if randf() < 0.002:
			sample = randf_range(-1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))
