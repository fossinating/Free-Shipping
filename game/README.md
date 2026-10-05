# Free Shipping (Godot 4 rework)

The Godot 4.6 rebuild described in [`docs/rework-proposal.md`](../docs/rework-proposal.md).
The jam version (Godot 3.5) still lives at the repository root; its art and
story can be reused, but none of its code is.

Open this `game/` folder in Godot 4.6. The main scene is the title
screen (`scenes/ui/title.tscn`): Continue from your save, or New Game,
which starts the opening (`scenes/levels/opening.tscn`): three
controlled shifts and the accident.
After the accident you wake in the warehouse
(`scenes/levels/warehouse.tscn`): one level holding the maintenance bay,
Fulfillment (your work route, Electronics and Hardware) and Receiving.
Fake your way through the diagnostics, follow the static to Elle's radio
in Electronics, get a level 1 keycard in Hardware (knock it off the floor
supervisor, or crawl through the vent into his office), get through the
scanner into Receiving, and get the level 2 keycard (off the dock boss,
or by climbing into the roofless receiving office). That card ends the
vertical slice, and the end card shows how the achievements stand (Low
Profile: no lockdowns; Ghost: no lockdowns and no fights you started). Set `skip_intro` on the warehouse's root to start back on
the floor.
The sandbox for movement and packages is `scenes/world/test_room.tscn`,
the one for suspicion (cameras, coworkers, guards, zones, hiding spots) is
`scenes/levels/stealth_test.tscn`, and the one for items (inventory, your
charging dock, fighting, crafting) is `scenes/levels/item_test.tscn`.

## Saving, wipes and the evidence locker

Walking into the maintenance bay saves the game (not during a lockdown);
the objective reminds you. The save (`user://save.json`) holds
GameState (clearance, flags, recipes, upgrades, wipes, the evidence
locker, achievement tracking), where you stood, your inventory, your
dock's stash and the items lying around. A loaded game goes straight to
the warehouse floor.

Caught by a guard during a lockdown, you're wiped: re-imaged on the
repair table with your clearance and upgrades but nothing you carried.
Elle restores you, and what she says changes with how often it's
happened. Your dock is safe from a wipe, but if suspicion reaches 80
outside a lockdown, security searches it about 10 seconds later.
Everything confiscated goes to the holding locker in a cage by the
Receiving entrance (badge level 2, so sneak in); press C at the locker
to take your things back.

## Web build

`export_presets.cfg` has a Web preset (single-threaded, so it runs on
hosts without cross-origin isolation headers). With the Web export
templates installed:

```sh
godot --headless --path . --export-release Web ../build/web/index.html
```

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
| C | Open your charging dock when standing at it (stash, repair, craft), or take your things back from the holding locker |
| 1 / 2 / 3 | Pick an answer (diagnostics) |
| Space or Enter | Dialogue: show the whole line, then the next one |
| Backspace | Dialogue: skip the rest of the conversation |
| T | Dialogue: toggle auto-advance |
| Esc | Free the mouse |

Climbing: grow until your core is level with a ledge, extend your arms to
hook it, then shrink to pull yourself up.

Items: an equipped tool shows in your hand and counts as contraband, so
holster it before walking past a camera. Scanner checkpoints at zone
doors read your badge and everything you carry, stowed or not, so leave
tools at your dock before going through. Keycards go straight into your
badge when you pick them up. Tools wear down with each swing
or hit and break at 0; repair them at your dock with tape. Recipes appear
in the dock's list once you've held one of their ingredients.

Upgrades: the wheel base (wheel motor from Receiving + strap + tape)
makes you faster, rides conveyors fast and launches you off ramps; the
ramp in Hardware clears the sorting pit. Magnetic hands (magnet +
electromagnet coil) stick to metal shelving: extend your arms into it and
grow to climb, then shrink at the top to pull yourself up.

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
  `ItemCatalog.POOLS` holds each department's item pool, and `ItemSpot`s
  in a level pick from them. Keycards are items too; `KeycardCarrier`
  clips one to a guard, and a hit knocks it loose.
- `scripts/story/`: the story. `Dialogue` (autoload) queues
  conversations and shows one line at a time; `play()` returns a
  `Conversation` you can `await conversation.wait()` on, and queuing,
  interrupting, advancing and skipping are all safe at any moment. Lines
  and speakers live in tables in `DialogueLines`. `Diagnostics` runs the
  maintenance robot's tests (choices, staying still, a reflex check);
  abnormal answers raise suspicion, capped so it can't lock down.
  `SignalReceiver` is your fried chip (screen static, hiss and the signal
  meter); `Radio` is Elle's radio, the signal source. Story flags
  (`freed`, `diagnostics_done`, `met_elle`, `keycard_hint`,
  `slice_complete`) are in `GameState.flags`.
- `SaveGame` (`scripts/save_game.gd`): one JSON save slot. A level
  calls `SaveGame.take_pending()` / `apply_level()` in `_ready()` to
  restore itself from a loaded save. `EvidenceLocker`
  (`scripts/items/evidence_locker.gd`) gives back what's in
  `GameState.evidence`; `Security.search_docks()` and
  `Inventory.confiscate_all()` fill it.
- `scripts/ui/title_menu.gd`: the title screen.
- `scripts/world/`: doors, `ScannerCheckpoint` (badge and contraband
  scans at zone doors, or a plain badge reader), `Conveyor` belts and the
  `LaunchRamp` lip that throws a robot on wheels.
- `scripts/robot/guard_brain.gd`: guard bots (patrol, investigate,
  check in, chase, search), pathing on a navmesh that
  `scripts/world/level_navigation.gd` bakes at load.
- Blockout scenes are generated from tables by `tools/gen_test_room.py`,
  `tools/gen_opening.py`, `tools/gen_stealth_test.py` and
  `tools/gen_item_test.py` and `tools/gen_warehouse.py` (helpers in
  `tools/blockout.py`). Edit the
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
