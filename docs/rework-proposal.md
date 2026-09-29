# Free Shipping: Rework Proposal

**Pitch:** a 3D puzzle-platformer about climbing a corporate warehouse with a robot body you can reshape. Drop the combat focus and build around the moment players loved.

## Background: jam results

2022 NC Game Jam (11 entries, 4 ratings):

| Criterion | Rank | Raw score |
|---|---|---|
| Creativity | #3 | 4.25 |
| Enjoyment | #5 | 4.00 |
| Overall | #5 | 3.83 |
| Presentation | #9 | 3.25 |

The 4.25 for creativity was the highest single raw score across all of fossinating's jam entries. One player called climbing by growing and shrinking a "lightbulb moment." Complaints were practical: extending and retracting was slow, the pickup radius was too small, the dialogue broke if you moved on too fast, and dying sent you back to the main menu.

## What to keep

- Climbing by growing and shrinking (Q/E) and extending your arms. It's the one mechanic in the jam version that's truly this game's own.
- The satire: Amaze, the B.E.Z.O.S. control room, the hacktivist Elle, and the 1-hour maintenance break.
- The maintenance floor where you save and repair.

## Genre change

It's currently listed as "Action" with two boss rooms. The rework shifts it to about 70% puzzle-platforming and 30% set pieces. The body mechanics are what players liked. The combat, where you bump boxes away before you can grab them, is where the frustration was.

## Body mechanics, expanded

You unlock body parts from other robots as the story goes on:

| Part | What it does |
|---|---|
| Telescoping torso *(start)* | Grow and shrink. Reach ledges, fit through vents, press elevator buttons |
| Extending arms *(start)* | Grab, carry and throw packages. Hang from shelves |
| Magnetic hands | Climb metal shelving and pull crates toward you |
| Wheel base | Ride conveyors quickly and get launched off ramps |
| Detachable head | Send your camera or sensor off separately to scout or trip sensors, as in Portal's co-op or Cogmind |

Every floor's puzzles are built around combining parts you already have with one new part.

## Structure: climbing the tower

Each floor is a department and adds one twist:

1. **Receiving:** conveyors, and the rule that everything gets scanned.
2. **Toys:** the existing "Kids" warehouse, with bouncy goods and physics chaos.
3. **Office:** the existing "Office" boss floor, which becomes a stealth puzzle about avoiding managers' "productivity cameras."
4. **Fulfillment AI:** the algorithm rearranges the shelves in real time.
5. **B.E.Z.O.S. control room.**

## Stealth instead of health

Getting caught doesn't kill you. It sends you back to the last maintenance station, where your robot is "re-imaged." Elle's help restores your memory, and the dialogue changes with how often you've been wiped. This fixes the jam version's "dying sends you to the main menu" problem, and it fits the theme.

## Bosses become puzzles

Each department head is beaten using the environment. For example, you redirect a conveyor so it buries a manager bot in returns.

## Freeing the robots

Throughout each floor, other robots can be freed if you solve an optional puzzle. Freed robots help later, for example by forming a bridge or holding a button. The ending changes based on how many you freed. This is the player's reason to explore.

## Fixes from jam feedback

- Faster grow/shrink and arm extension, with a smooth ease so it's still precise.
- A larger magnetic pickup radius, and a preview of the throw arc.
- The dialogue system shouldn't break when the player skips ahead. Queue lines and allow interrupts.
- Show a prompt for the two things that had to be explained in the jam comments: grow to reach elevator buttons, and return to the maintenance floor to save.

## Technical

The project is on Godot 3 (`config_version=4` in `project.godot`), so this should be a fresh Godot 4 project. You can reuse the art, the MeshLibraries and the story, but not the code. A clean rebuild should also fix the broken web build.

## Shared world (optional)

Free Shipping and A Flowering Apocalypse both involve Amaze. If Free Shipping's ending is "the robots escape the warehouse," both games can share a small setting.

## Scope

Larger than the Disruptive Dungeons rework, because it's level-designed rather than generated. Ship a vertical slice first: Receiving plus Toys, 3 body parts and 1 puzzle boss.
