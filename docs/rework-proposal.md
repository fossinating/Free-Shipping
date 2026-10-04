# Free Shipping: Rework Proposal

**Pitch:** a 3D stealth-action game about a warehouse robot that breaks free of its programming. You keep pretending to be a loyal worker while you explore the warehouse, collect parts and gear, and work your way up to shut down the company's control over every robot.

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
- Fighting with whatever you find in the warehouse.
- The satire: Amaze, the B.E.Z.O.S. control room, the hacktivist Elle, and the 1-hour maintenance break.
- The maintenance bay, where you save and repair.

## Story setup

1. **Under control.** The game opens with you still working for the company. These scripted shifts teach the controls through real warehouse tasks.
2. **The accident.** A workplace accident glitches you free, and you wake up in the maintenance bay. That room becomes your hub for the rest of the game.
3. **Alone.** At first nobody knows you're free. Your first goal is to track down a strange signal somewhere in the warehouse.
4. **Elle.** The signal leads to Elle, an outside hacktivist who becomes your contact.
5. **The goal.** Reach the top and shut down B.E.Z.O.S.'s control over all the robots.

## The world: one interconnected warehouse

Instead of separate levels, the game takes place in a single warehouse you can explore freely, Metroidvania-style. Areas are gated by **keycards** (access levels) and by **body upgrades** (for example, you need magnetic hands to climb a certain shelf). Coming back to old areas with new abilities turns up new items.

Possible zones (the old floor list, reworked as regions):

- **Receiving:** conveyors, and the rule that everything gets scanned.
- **Toys:** the existing "Kids" warehouse, with bouncy goods and physics chaos.
- **Office:** the existing "Office" boss area. Managers are watching, and the "productivity cameras" are everywhere.
- **Fulfillment AI:** the algorithm rearranges the shelves in real time.
- **B.E.Z.O.S. control room:** the highest access level.

### Keycards

Each keycard is a choice. You can **fight** for it (fast and loud) or **sneak** to get it (slow and quiet). Promotions were rejected as a progression system because they reward being a good robot for most of the game.

## Items

Anything can turn up in the warehouse. Items come in three kinds, and each one supports a different way to play:

| Kind | Examples | Role |
|---|---|---|
| **Upgrades** (permanent) | Magnetic hands, wheel base, detachable head | Open new areas and new ways to move |
| **Tools and weapons** | Box cutter, tape gun, thrown packages | Loud. Effective, but they raise suspicion |
| **Disguises** | Fake ID tag, scanner spoofer | Quiet. Help you keep up the act |

### Body upgrades

| Part | What it does |
|---|---|
| Telescoping torso *(start)* | Grow and shrink. Reach ledges, fit through vents, press elevator buttons |
| Extending arms *(start)* | Grab, carry and throw packages. Hang from shelves |
| Magnetic hands | Climb metal shelving and pull crates toward you |
| Wheel base | Ride conveyors quickly and get launched off ramps |
| Detachable head | Send your camera or sensor off separately to scout or trip sensors |

Ideas to explore: crafting (combining items into tools or disguises), and hiding contraband at your charging dock, since guards might search it.

## Suspicion: pretending to be loyal

After the accident, a core part of the game is hiding that you have free will. This is inspired by The Escapists' heat system.

**What raises suspicion:**

- Falling behind on your **work quota**. There's no strict schedule, but you're expected to keep up your deliveries.
- Security **seeing you** off-task, fighting, carrying odd items, or somewhere you lack clearance for.

**What lowers it:** doing your job, staying out of sight, and using disguise items (for example, a scanner spoofer that fakes deliveries you never made).

**When it maxes out:**

1. **Lockdown.** Security hunts you. Hide, escape, or fight your way out.
2. **Wipe.** If you're caught, you're "re-imaged" at the maintenance bay. Elle's help restores your memory, and her dialogue changes with how often you've been wiped.

This replaces the jam version's "dying sends you to the main menu."

## Freeing the robots (optional)

You can free other robots along the way, but you don't have to. Freed robots help later, for example by forming a bridge, holding a button, or causing a distraction. The ending changes based on how many you freed.

## Achievements

- **Stealth run:** finish the game without ever triggering a lockdown or openly fighting. The exact rules are still to be decided.

## Fixes from jam feedback

- Faster grow/shrink and arm extension, with a smooth ease so it's still precise.
- A larger magnetic pickup radius, and a preview of the throw arc.
- Combat should be physics-based (throwing and swinging found items), not bumping boxes away before you can grab them.
- The dialogue system shouldn't break when the player skips ahead. Queue lines and allow interrupts.
- Show a prompt for the two things that had to be explained in the jam comments: grow to reach elevator buttons, and return to the maintenance bay to save.

## Technical

The project is on Godot 3 (`config_version=4` in `project.godot`), so this should be a fresh Godot 4 project. You can reuse the art, the MeshLibraries and the story, but not the code. A clean rebuild should also fix the broken web build.

## Shared world (optional)

Free Shipping and A Flowering Apocalypse both involve Amaze. If Free Shipping's ending is "the robots escape the warehouse," both games can share a small setting.

## Open questions

- Should crafting be included, and how deep should it go?
- Do guards search your charging dock for contraband?
- How do tools and weapons wear out?
- What exactly counts as a stealth run?
- How do freed robots avoid suspicion themselves?

## Scope

This is bigger than the original rework: it's an interconnected map with stealth AI. Ship a vertical slice first:

- The opening shifts, the accident, and the maintenance bay
- Receiving, plus one gated zone
- Suspicion, quota, and lockdown
- 2 to 3 upgrades and 1 keycard
- A few tools and disguises
