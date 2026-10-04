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

No humans appear on screen. The warehouse is run entirely by robots, and Elle is only a voice or a signal.

## The opening

The goal is to teach the controls and make the player *feel* controlled, without dragging. It's three short shifts, about 3 to 4 minutes each.

**Under control:** the player can't step outside the assigned task. Inputs only work in ways the company allows, so there's no wandering off. This keeps players on track and makes the loss of free will tangible, which makes the freedom afterward hit harder.

| Shift | Teaches |
|---|---|
| 1 | Move, grab, carry, deliver. The quota counter is introduced |
| 2 | Grow and shrink to reach high shelves and elevator buttons |
| 3 | Extend arms and throw packages into sorting chutes across a gap (an "efficiency" policy). Something feels off. Then the accident |

### The accident

A leaking roof drips onto exposed wiring next to a "repair ticket pending" sign that's clearly months old. Your task route goes straight through the puddle. You can't refuse, so you walk in, and the shock fries your control chip. The company's own negligence frees you.

### The maintenance bay

You wake on the repair table, able to move freely for the first time. A maintenance robot, still under control, runs diagnostics. You have to fake normal responses or your suspicion rises. This is the scripted, safe introduction to the suspicion meter. During diagnostics, your fried chip picks up faint static that nobody else can hear.

### Back on the floor

The maintenance robot sends you back to work. The static is faint in certain spots, so following it means straying from your route. That's your first real risk, and your first goal: find the source of the signal (Elle).

The source is a radio on a shelf in **Fulfillment's Electronics department**, just off your normal work route. It's a short first sneak of about 5 to 10 minutes. That keeps the "alone" stretch without stalling the early game.

## The world: one interconnected warehouse

Instead of separate levels, the game takes place in a single warehouse you can explore freely, Metroidvania-style. Areas are gated by **keycards** (access levels) and by **body upgrades** (for example, you need magnetic hands to climb a certain shelf). Coming back to old areas with new abilities turns up new items.

The zones follow how goods actually move through a warehouse, which keeps it feeling organized. Item variety comes from that organization: each zone, and each Fulfillment department, has its own item pool.

| Zone | What it is | Typical items |
|---|---|---|
| **Receiving** | Pallets of unopened stock arriving | Bulk basics: tape, straps, packing materials |
| **Fulfillment** | The largest zone, split into departments by product type (e.g. Hardware, Electronics, Home, Toys) | Varies by department |
| **Outgoing** | Packed boxes, labels, scanners, loading docks | Disguise items: fake labels, scanner spoofers |
| **Security** | Cameras, guard bots, the keycard office | High-value gear, high risk |
| **Returns** | The one messy zone: broken and random goods | Crafting scraps, oddities |
| **Management** | Offices and server rooms above the warehouse floor, ending in the B.E.Z.O.S. control room | Endgame |

Returns being chaotic in an otherwise orderly building is a deliberate contrast.

### Progression

1. **Early:** Receiving and Fulfillment.
2. **Mid:** Returns and Outgoing.
3. **Late:** Security, where you get the top keycard.
4. **Finale:** Management.

**Target length:** 3 to 5 hours, from the zones and departments, revisiting areas with new upgrades, and optional robot freeing. The jam version was a week of work. This one should feel like a full game.

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

### Crafting

- Recipes take **2 items, 3 at most**. You never need 5+ items for one result.
- Results can be ingredients themselves, so recipes form a **nested tree** you climb step by step. Example: tape + box cutter → taped blade; taped blade + magnet → magnetic grabber blade.
- **No blueprints to find.** A recipe is revealed once you've held one of its ingredients.

### Durability

Tools and weapons wear down with use. You can repair them at your charging dock with materials like tape, which gives common junk lasting value.

### Your charging dock

Your dock is where you stash items. Guards only search it once your suspicion is **high**, so careful players keep a safe stash and sloppy ones risk losing it. Hidden stash spots around the warehouse are another option.

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

You can free other robots along the way, but you don't have to. Freed robots help later, for example by forming a bridge or holding a button. The ending changes based on how many you freed.

**Risk and reward:** each freed robot adds a little to your overall suspicion, since more odd behavior draws more attention. But freed robots can also create **local distractions** that pull security away from you. More freed robots means more pressure and more help.

## Achievements

Both names are placeholders:

- **Low Profile:** finish the game without ever triggering a lockdown.
- **Ghost:** finish with no lockdowns and no combat at all.

For Ghost to be possible, **every fight, bosses included, needs a non-combat way through.**

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

## Scope

This is bigger than the original rework: it's an interconnected map with stealth AI. Ship a vertical slice first:

- The opening shifts, the accident, and the maintenance bay
- Receiving, plus one gated zone
- Suspicion, quota, and lockdown
- 2 to 3 upgrades and 1 keycard
- A few tools and disguises, with a small crafting tree
