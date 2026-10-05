# Free Shipping (Godot 4 rework)

The Godot 4.6 rebuild described in [`docs/rework-proposal.md`](../docs/rework-proposal.md).
The jam version (Godot 3.5) still lives at the repository root; its art and
story can be reused, but none of its code is.

Open this `game/` folder in Godot 4.6. The main scene is the opening
(`scenes/levels/opening.tscn`): three controlled shifts and the accident.
The sandbox for movement and packages is `scenes/world/test_room.tscn`,
the one for suspicion (cameras, coworkers, guards, zones, hiding spots) is
`scenes/levels/stealth_test.tscn`, and the one for items (inventory, your
charging dock, fighting, crafting) is `scenes/levels/item_test.tscn`.

## Controls

| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Look |
| E / Q | Grow / shrink |
| Shift or Right Mouse | Extend arms (hook ledges) |
| Click or F | Grab a package or item; tap to set it down, hold to aim and throw |
| R | Stow the item in your hands, or take the equipped item out |
| Tab | Cycle the equipped slot (the last step holsters everything) |
| V or Middle Mouse | Use the equipped item: swing a tool, trigger a disguise, install an upgrade |
| C | Open your charging dock when standing at it (stash, repair, craft) |
| Esc | Free the mouse |

Climbing: grow until your core is level with a ledge, extend your arms to
hook it, then shrink to pull yourself up.

Items: an equipped tool shows in your hand and counts as contraband, so
holster it before walking past a camera. Tools wear down with each swing
or hit and break at 0; repair them at your dock with tape. Recipes appear
in the dock's list once you've held one of their ingredients.

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
- `scripts/suspicion/`: the `Suspicion` meter (autoload), `Offenses`
  (what counts as suspicious), `Zone`s (clearance and where resizing is
  normal), and `Watcher`s used by security cameras and coworker eyes.
  `Security` (autoload) runs lockdowns, sightings, noise and guard
  check-ins; `HidingSpot`s hide a fully shrunk robot.
- `scripts/items/`: items. `ItemCatalog` holds every item and recipe as
  tables; an `ItemState` is one item and its wear, and moves between an
  `Item` pickup (a `Package` subclass), the player's `Inventory` and a
  `ChargingDock` stash. The dock repairs and crafts. `Combat` handles
  swings and thrown hits (knockback, stun, noise, fighting). `GameState`
  remembers held items, known recipes and installed upgrades.
- `scripts/robot/guard_brain.gd`: guard bots (patrol, investigate,
  check in, chase, search), pathing on a navmesh that
  `scripts/world/level_navigation.gd` bakes at load.
- Blockout scenes are generated from tables by `tools/gen_test_room.py`,
  `tools/gen_opening.py`, `tools/gen_stealth_test.py` and
  `tools/gen_item_test.py` (helpers in `tools/blockout.py`). Edit the
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
