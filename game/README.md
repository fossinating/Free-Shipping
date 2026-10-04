# Free Shipping (Godot 4 rework)

The Godot 4.6 rebuild described in [`docs/rework-proposal.md`](../docs/rework-proposal.md).
The jam version (Godot 3.5) still lives at the repository root; its art and
story can be reused, but none of its code is.

Open this `game/` folder in Godot 4.6. The main scene is the opening
(`scenes/levels/opening.tscn`): three controlled shifts and the accident.
The sandbox for movement and packages is `scenes/world/test_room.tscn`.

## Controls

| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Look |
| E / Q | Grow / shrink |
| Shift or Right Mouse | Extend arms (hook ledges) |
| Click or F | Grab a package; tap to set it down, hold to aim and throw |
| Esc | Free the mouse |

Climbing: grow until your core is level with a ledge, extend your arms to
hook it, then shrink to pull yourself up.

## Layout

- `scripts/robot/robot_body.gd`: the robot body. Drivers (player, control
  mode, AI) only write its intent variables (`move_input`,
  `extension_input`, `arms_input`, `facing_yaw`).
- `scripts/player/`: player input and the third-person camera.
- `scripts/work/`: packages, chutes, spawners, the throw arc, and the
  `Quota` autoload that counts deliveries.
- `scripts/control/`: control mode. A `ControlProgram` runs `Shift`
  nodes whose `ShiftStep` children are the assigned tasks; while a step is
  active the player's input is filtered to what that step allows (route
  corridor, height, arms, throwing, which packages).
- Blockout scenes are generated from tables by `tools/gen_test_room.py`
  and `tools/gen_opening.py` (helpers in `tools/blockout.py`). Edit the
  table, then rerun the script. Set `debug_start_shift` on the opening's
  root to skip to a later shift.

## Tests

```sh
GODOT=/path/to/godot ./run_tests.sh            # everything (runs tests/run_tests.tscn)
GODOT=/path/to/godot ./run_tests.sh climb      # tests whose name contains "climb"
```

To check visuals without the editor:

```sh
godot --path . res://tools/screenshot.tscn -- res://scenes/world/test_room.tscn out.png 1.5
```
