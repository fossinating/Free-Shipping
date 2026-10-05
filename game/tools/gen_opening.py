"""Generates scenes/levels/opening.tscn: the three controlled shifts and
the accident.

Layout (top-down, -Z is north):
  south lane   Shift 1: Station A -> Chute 1
  west         Shift 2: tall shelf, low conveyor, lift door, Chute 2
  north        Shift 3: sorting conveyor, a pit, red/blue chutes
  east         Corridor B with the leaking roof (the accident)
"""

from blockout import Scene

CHUTE = "res://scenes/work/chute.tscn"
SPAWNER = "res://scripts/work/package_spawner.gd"
STEP = "res://scripts/control/shift_step.gd"
SHIFT = "res://scripts/control/shift.gd"

REACH, GRAB, DELIVER, PRESS, ACCIDENT = range(5)

GEOMETRY = [
    # Floor, with a pit (z -16..-12, x -6..12) between sorting and the chutes.
    ("FloorSouth", (0, -0.5, 9), (60, 1, 42), "floor"),
    ("FloorNorth", (0, -0.5, -23), (60, 1, 14), "floor"),
    ("FloorPitWest", (-18, -0.5, -14), (24, 1, 4), "floor"),
    ("FloorPitEast", (21, -0.5, -14), (18, 1, 4), "floor"),
    ("PitBottom", (3, -2.5, -14), (18, 1, 4), "floor"),
    ("PitEdgeStripe", (3, 0.01, -11.9), (18, 0.02, 0.2), "hazard"),
    ("WallNorth", (0, 5, -30.5), (62, 10, 1), "wall"),
    ("WallSouth", (0, 5, 30.5), (62, 10, 1), "wall"),
    ("WallWest", (-30.5, 5, 0), (1, 10, 60), "wall"),
    ("WallEast", (30.5, 5, 0), (1, 10, 60), "wall"),
    # Shift 2: a tall shelf, a low conveyor to shrink under, and the lift wall.
    ("TallShelf", (-20, 1.75, 0), (4, 3.5, 1.5), "shelf"),
    ("LowConveyor", (-21, 2.0, 8), (18, 0.8, 1.0), "conveyor"),
    ("LiftWallWest", (-25, 5, 14), (10, 10, 0.4), "wall"),
    ("LiftWallEast", (-14.5, 5, 14), (5, 10, 0.4), "wall"),
    ("LiftLintel", (-18.5, 6.6, 14), (3, 6.8, 0.4), "wall"),
    # Shift 3: a low counter in front of the sorting conveyor.
    ("SortingCounter", (3, 0.4, -8), (8, 0.8, 0.6), "wall"),
    ("SortingConveyor", (3, 0.5, -9.5), (8, 1.0, 1.4), "conveyor"),
]

LABELS = [
    ("StationASign", (-8, 2.5, 18), "STATION A"),
    ("Chute1Sign", (8, 2.5, 18), "CHUTE 1"),
    ("ShelfSign", (-20, 4.6, 0.8), "STORAGE"),
    ("LiftSign", (-18.5, 3.6, 13.6), "LIFT"),
    ("Chute2Sign", (-18.5, 2.5, 17.5), "CHUTE 2"),
    ("SortingSign", (3, 2.6, -9.5), "SORTING\nEfficiency policy: throw, don't walk"),
    ("CorridorSign", (22, 3.2, -2), "CORRIDOR B"),
]


def main():
    s = Scene("Opening")
    s.root("res://scripts/levels/opening.gd", node_paths=[
        "program", "hud", "controller", "accident_site"], props={
        "program": 'NodePath("Program")',
        "hud": 'NodePath("HUD")',
        "controller": 'NodePath("Player/Controller")',
        "accident_site": 'NodePath("Geometry/AccidentSite")',
    })
    s.environment()

    s.node("Geometry", "Node3D")
    for name, center, size, material in GEOMETRY:
        s.box(name, center, size, material, parent="Geometry")
    for name, pos, text in LABELS:
        s.label(name, pos, text, parent="Geometry")

    door = s.ext_resource("Script", "res://scripts/world/door.gd")
    door_mat = s.material("door")
    door_shape = s.sub_resource("BoxShape3D", "Shape_door", {"size": "Vector3(3, 3.2, 0.3)"})
    door_mesh = s.sub_resource("BoxMesh", "Mesh_door",
                               {"size": "Vector3(3, 3.2, 0.3)", "material": door_mat})
    s.node("LiftDoor", "AnimatableBody3D", "Geometry",
           {"script": door, "button": 'NodePath("../LiftButton")'},
           pos=(-18.5, 1.6, 14), node_paths=["button"])
    s.node("Shape", "CollisionShape3D", "Geometry/LiftDoor", {"shape": door_shape})
    s.node("Mesh", "MeshInstance3D", "Geometry/LiftDoor", {"mesh": door_mesh})
    # Call button on the north face of the lift wall, 3.4 m up: grow to press.
    s.instance("LiftButton", "res://scenes/world/push_button.tscn", "Geometry",
               pos=(-15.5, 3.4, 13.8), yaw=180)
    s.instance("AccidentSite", "res://scenes/world/accident_site.tscn", "Geometry",
               pos=(22, 0, -6))

    s.node("Work", "Node3D")
    s.scripted("StationA", "Marker3D", SPAWNER, "Work", pos=(-8, 0, 18), props={"stock": "3"})
    s.instance("Chute1", CHUTE, "Work", pos=(8, 0, 18))
    s.scripted("TopShelf", "Marker3D", SPAWNER, "Work", pos=(-20, 3.5, 0),
               props={"stock": "2"})
    s.instance("Chute2", CHUTE, "Work", pos=(-18.5, 0, 17.5))
    s.scripted("SortingLine", "Marker3D", SPAWNER, "Work", pos=(3, 1.0, -9.5),
               props={"stock": "3", "radius": "3.0",
                      "destinations": 'Array[StringName]([&"red", &"blue"])'})
    s.instance("RedChute", CHUTE, "Work", pos=(0, 0, -19), props={"accepts": '&"red"'})
    s.instance("BlueChute", CHUTE, "Work", pos=(6, 0, -19), props={"accepts": '&"blue"'})

    s.instance("Player", "res://scenes/player/player.tscn", pos=(0, 0.05, 26))
    s.scripted("Program", "Node", "res://scripts/control/control_program.gd",
               props={"robot": 'NodePath("../Player")'}, node_paths=["robot"])

    shifts = [
        ("Shift1", "Shift 1", 4, [
            ("Report", REACH, (-8, 0, 20.5), "Report to Station A.", {}),
            ("Pick", GRAB, (-8, 0, 19.5), "Pick up a package (Click / F).",
             {"target": "StationA", "radius": 2.5}),
            ("Deliver", DELIVER, (8, 0, 19.8),
             "Carry it to Chute 1 and set it in (tap Click / F).",
             {"target": "Chute1", "radius": 2.5}),
            ("Quota", DELIVER, (0, 0, 20),
             "Meet quota: deliver 3 more packages from Station A to Chute 1.",
             {"target": "Chute1", "source": "StationA", "count": 3, "radius": 1.0,
              "corridor_width": 4.0, "waypoints": [(-8, 0, 20), (8, 0, 20)]}),
        ]),
        ("Shift2", "Shift 2", 2, [
            ("GoToShelf", REACH, (-20, 0, 2.5), "Go to the storage shelf.",
             {"waypoints": [(0, 0, 10), (-8, 0, 3)]}),
            ("Pick", GRAB, (-20, 0, 1.5),
             "Grow (hold E) to reach the top shelf, then grab a package.",
             {"target": "TopShelf", "radius": 2.5, "max_extension": 3.0}),
            ("UnderConveyor", REACH, (-20, 0, 11),
             "Shrink (hold Q) to fit under the conveyor.",
             {"max_extension": 3.0, "radius": 1.2}),
            ("CallLift", PRESS, (-15.5, 0, 12.5),
             "Grow to press the lift call button.",
             {"target": "Geometry/LiftButton", "max_extension": 3.0, "radius": 2.5}),
            ("Deliver", DELIVER, (-18.5, 0, 16),
             "Deliver the package to Chute 2.",
             {"target": "Chute2", "max_extension": 3.0, "radius": 2.5,
              "waypoints": [(-18.5, 0, 12.5)]}),
            ("Again", DELIVER, (-18.5, 0, 16),
             "Meet quota: bring one more package from the top shelf.",
             {"target": "Chute2", "source": "TopShelf", "max_extension": 3.0,
              "radius": 2.5,
              "waypoints": [(-18.5, 0, 13), (-20, 0, 11), (-20, 0, 1.5), (-20, 0, 11),
                            (-18.5, 0, 13)]}),
        ]),
        ("Shift3", "Shift 3", 3, [
            ("Report", REACH, (3, 0, -6.5), "Report to the sorting station.",
             {"waypoints": [(-12, 0, 17), (-6, 0, 10), (-2, 0, -2)]}),
            ("Pick", GRAB, (3, 0, -6.8),
             "Packages are on the far side of the counter. "
             "Extend your arms (hold Shift) to reach one.",
             {"target": "SortingLine", "radius": 3.0, "allow_arms": True}),
            ("Sort", DELIVER, (3, 0, -6.8),
             "Efficiency policy: throw packages across the gap into the chute "
             "that matches their label. Hold Click / F to aim, release to throw.",
             {"source": "SortingLine", "count": 3, "radius": 3.0, "allow_arms": True,
              "allow_throw": True}),
            ("Reroute", ACCIDENT, (22, 0, -6),
             "Route updated. Proceed through Corridor B. Route is mandatory.",
             {"radius": 1.0, "corridor_width": 2.0, "waypoints": [(12, 0, -6.5)]}),
        ]),
    ]

    shift_script = s.ext_resource("Script", SHIFT)
    step_script = s.ext_resource("Script", STEP)
    for shift_name, title, quota, steps in shifts:
        s.node(shift_name, "Node", "Program",
               {"script": shift_script, "title": f'"{title}"', "quota": str(quota)})
        for step_name, kind, pos, text, opts in steps:
            parent = f"Program/{shift_name}"
            props = {
                "script": step_script,
                "instruction": '"' + text.replace('"', '\\"') + '"',
                "kind": str(kind),
            }
            paths = []
            for key in ("target", "source"):
                if key in opts:
                    # Bare names are under Work; paths are from the level root.
                    path = opts[key] if "/" in opts[key] else f"Work/{opts[key]}"
                    props[key] = f'NodePath("../../../{path}")'
                    paths.append(key)
            for key in ("count", "radius", "corridor_width", "max_extension"):
                if key in opts:
                    props[key] = str(opts[key])
            for key in ("allow_arms", "allow_throw"):
                if opts.get(key):
                    props[key] = "true"
            s.node(step_name, "Marker3D", parent, props, pos=pos, node_paths=paths)
            # Waypoints are children, in world space; steps sit at `pos`.
            for i, wp in enumerate(opts.get("waypoints", [])):
                local = (wp[0] - pos[0], wp[1] - pos[1], wp[2] - pos[2])
                s.node(f"Waypoint{i + 1}", "Marker3D", f"{parent}/{step_name}", pos=local)

    s.scripted("RouteGuide", "MeshInstance3D", "res://scripts/control/route_guide.gd",
               node_paths=["program"], props={"program": 'NodePath("../Program")'})
    s.instance("HUD", "res://scenes/ui/hud.tscn", node_paths=["controller", "program"],
               props={"controller": 'NodePath("../Player/Controller")',
                      "program": 'NodePath("../Program")'})
    s.save("scenes/levels/opening.tscn")


if __name__ == "__main__":
    main()
