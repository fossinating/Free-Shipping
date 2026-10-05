"""Generates scenes/levels/item_test.tscn, the items sandbox.

South-west: your charging dock. Middle: workbenches with tools, tape,
magnets, a scanner spoofer and a fake ID. North-east: a records room that
needs clearance 1 (the fake ID gets you in unseen). The electromagnet coil,
the key part for magnetic hands, sits on top of a tall shelf in the
north-west. A guard patrols the floor, a coworker works the chute, and a
camera watches the benches.
"""

from blockout import Scene

CHUTE = "res://scenes/work/chute.tscn"
SPAWNER = "res://scripts/work/package_spawner.gd"
CAMERA = "res://scenes/suspicion/security_camera.tscn"
COWORKER = "res://scenes/robot/coworker.tscn"
ZONE = "res://scripts/suspicion/zone.gd"
GUARD = "res://scenes/robot/guard.tscn"
ITEM = "res://scenes/items/item.tscn"
DOCK = "res://scenes/items/charging_dock.tscn"

GEOMETRY = [
    ("Floor", (0, -0.5, 0), (32, 1, 28), "floor"),
    ("WallNorth", (0, 4, -14.5), (34, 8, 1), "wall"),
    ("WallSouth", (0, 4, 14.5), (34, 8, 1), "wall"),
    ("WallWest", (-16.5, 4, 0), (1, 8, 28), "wall"),
    ("WallEast", (16.5, 4, 0), (1, 8, 28), "wall"),
    # Workbenches.
    ("BenchWest", (-4, 0.5, 0), (4, 1, 1.2), "crate"),
    ("BenchEast", (3, 0.5, 0), (4, 1, 1.2), "crate"),
    # Tall shelf with the key part on top.
    ("TallShelf", (-13, 1.5, -11), (3, 3, 2), "shelf"),
    # Records room: walls with a doorway on the south side.
    ("RecordsWallWest", (7, 2.5, -9), (0.4, 5, 10), "wall"),
    ("RecordsWallSouthA", (9, 2.5, -4), (4, 5, 0.4), "wall"),
    ("RecordsWallSouthB", (14.5, 2.5, -4), (3, 5, 0.4), "wall"),
    ("RecordsDesk", (12, 0.5, -11), (3, 1, 1.2), "crate"),
]

LABELS = [
    ("BenchSign", (-0.5, 2.4, 0), "WORKBENCHES\nGrab with F, stow with R"),
    ("RecordsSign", (11.5, 4.2, -3.6), "RECORDS\nCLEARANCE 1"),
    ("ShelfSign", (-13, 4.2, -9.8), "Key part up top"),
    ("ChuteSign", (8, 2.6, 9), "Deliveries lower suspicion"),
]

# (node name, item id, position)
ITEMS = [
    ("Tape1", "tape", (-5.5, 1.1, 0)),
    ("Tape2", "tape", (-4.8, 1.1, 0)),
    ("Tape3", "tape", (-4.1, 1.1, 0)),
    ("BoxCutter", "box_cutter", (-3.0, 1.1, 0)),
    ("Magnet1", "magnet", (1.5, 1.1, 0)),
    ("Magnet2", "magnet", (2.2, 1.1, 0)),
    ("ScrapCircuit", "scrap_circuit", (3.0, 1.1, 0)),
    ("Spoofer", "scanner_spoofer", (3.8, 1.1, 0)),
    ("FakeId", "fake_id", (4.6, 1.1, 0)),
    ("Coil", "electromagnet_coil", (-13, 3.2, -11)),
    ("RecordsCutter", "box_cutter", (12, 1.1, -11)),
]


def main():
    s = Scene("ItemTest")
    s.root("res://scripts/levels/stealth_test.gd", node_paths=["hud", "player", "respawn"],
           props={"hud": 'NodePath("HUD")', "player": 'NodePath("Player")',
                  "respawn": 'NodePath("Respawn")'})
    s.environment()
    s.navigation()
    s.node("Geometry", "Node3D", groups=["navigation_geometry"])
    for name, center, size, material in GEOMETRY:
        s.box(name, center, size, material, parent="Geometry")
    for name, pos, text in LABELS:
        s.label(name, pos, text, parent="Geometry")

    s.node("Zones", "Node3D")
    zones = [
        ("Fulfillment", (0, 4, 0), (32, 8, 28), {}),
        ("Storage", (-13, 4, -10), (6, 8, 8), {"allow_resize": "true"}),
        ("Records", (11.5, 2.5, -9), (9, 5, 10), {"required_clearance": "1"}),
    ]
    for name, center, size, props in zones:
        props = {"zone_name": f'"{name}"', **props}
        s.scripted(name, "Area3D", ZONE, "Zones", props=props, pos=center)
        shape = s.sub_resource("BoxShape3D", f"Shape_{name}", {"size": f"Vector3{size}"})
        s.node("Shape", "CollisionShape3D", f"Zones/{name}", {"shape": shape})

    s.node("Security", "Node3D")
    s.instance("BenchCamera", CAMERA, "Security", pos=(0, 6, -13.6), yaw=180,
               props={"sweep_degrees": "70.0"})

    s.node("Items", "Node3D")
    for name, item_id, pos in ITEMS:
        s.instance(name, ITEM, "Items", pos=pos, props={"item_id": f'&"{item_id}"'})
    s.instance("Dock", DOCK, pos=(-12, 0, 10))

    s.node("Work", "Node3D")
    s.scripted("Station", "Marker3D", SPAWNER, "Work", pos=(4, 0, 9))
    s.instance("Chute", CHUTE, "Work", pos=(11, 0, 9))

    s.node("Coworkers", "Node3D")
    s.node("WorkerRoute", "Node3D", "Coworkers")
    for i, point in enumerate([(5, 0, 6), (11, 0, 6)]):
        s.node(f"Point{i + 1}", "Marker3D", "Coworkers/WorkerRoute", pos=point)
    s.instance("Worker", COWORKER, "Coworkers", pos=(5, 0.05, 6))
    s.override("Brain", "Coworkers/Worker", {"route": 'NodePath("../../WorkerRoute")'},
               node_paths=["route"])

    s.node("Guards", "Node3D")
    s.node("FloorGuardRoute", "Node3D", "Guards")
    for i, point in enumerate([(-8, 0, -6), (4, 0, -6), (4, 0, 4), (-8, 0, 4)]):
        s.node(f"Point{i + 1}", "Marker3D", "Guards/FloorGuardRoute", pos=point)
    s.instance("FloorGuard", GUARD, "Guards", pos=(-8, 0.05, -6))
    s.override("Brain", "Guards/FloorGuard", {"route": 'NodePath("../../FloorGuardRoute")'},
               node_paths=["route"])

    s.node("Respawn", "Marker3D", pos=(-12, 0.05, 8))
    s.instance("Player", "res://scenes/player/player.tscn", pos=(-12, 0.05, 8))
    s.instance("HUD", "res://scenes/ui/hud.tscn", node_paths=["controller"],
               props={"controller": 'NodePath("../Player/Controller")'})
    s.save("scenes/levels/item_test.tscn")


if __name__ == "__main__":
    main()
