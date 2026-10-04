"""Generates scenes/levels/stealth_test.tscn, the suspicion sandbox.

West: storage aisles where resizing is normal. North-east: a room that
needs clearance 1, watched by a camera. A sweeping camera covers the main
floor, and two coworkers patrol.
"""

from blockout import Scene

CHUTE = "res://scenes/work/chute.tscn"
SPAWNER = "res://scripts/work/package_spawner.gd"
CAMERA = "res://scenes/suspicion/security_camera.tscn"
COWORKER = "res://scenes/robot/coworker.tscn"
ZONE = "res://scripts/suspicion/zone.gd"

GEOMETRY = [
    ("Floor", (0, -0.5, 0), (40, 1, 40), "floor"),
    ("WallNorth", (0, 4, -20.5), (42, 8, 1), "wall"),
    ("WallSouth", (0, 4, 20.5), (42, 8, 1), "wall"),
    ("WallWest", (-20.5, 4, 0), (1, 8, 40), "wall"),
    ("WallEast", (20.5, 4, 0), (1, 8, 40), "wall"),
    # Storage aisles.
    ("AisleShelfA", (-15, 2, 0), (1.5, 4, 12), "shelf"),
    ("AisleShelfB", (-10, 2, 0), (1.5, 4, 12), "shelf"),
    # Restricted room: walls with a doorway on the south side.
    ("OfficeWallWest", (6, 2.5, -12), (0.4, 5, 12), "wall"),
    ("OfficeWallSouthA", (8, 2.5, -6), (4, 5, 0.4), "wall"),
    ("OfficeWallSouthB", (16.5, 2.5, -6), (7, 5, 0.4), "wall"),
    ("OfficeDesk", (16, 0.5, -15), (3, 1, 1.5), "crate"),
    # Cover on the main floor.
    ("CrateA", (-3, 0.75, -4), (2, 1.5, 2), "crate"),
    ("CrateB", (5, 0.75, 1), (1.5, 1.5, 1.5), "crate"),
]

LABELS = [
    ("StorageSign", (-12.5, 4.8, 6.5), "STORAGE AISLES\nResizing is normal here"),
    ("OfficeSign", (11.5, 4.2, -5.6), "SECURITY OFFICE\nCLEARANCE 1"),
    ("WorkSign", (0, 2.6, 8), "Deliveries lower suspicion"),
]


def main():
    s = Scene("StealthTest")
    s.root("res://scripts/levels/stealth_test.gd", node_paths=["hud"],
           props={"hud": 'NodePath("HUD")'})
    s.environment()
    s.node("Geometry", "Node3D")
    for name, center, size, material in GEOMETRY:
        s.box(name, center, size, material, parent="Geometry")
    for name, pos, text in LABELS:
        s.label(name, pos, text, parent="Geometry")

    s.node("Zones", "Node3D")
    zones = [
        ("Fulfillment", (0, 4, 0), (40, 8, 40), {}),
        ("Storage", (-12.5, 4, 0), (9, 8, 16), {"allow_resize": "true"}),
        ("SecurityOffice", (13, 2.5, -13), (14, 5, 14),
         {"zone_name": '"Security Office"', "required_clearance": "1"}),
    ]
    for name, center, size, props in zones:
        props = {"zone_name": f'"{name}"', **props}
        s.scripted(name, "Area3D", ZONE, "Zones", props=props, pos=center)
        shape = s.sub_resource("BoxShape3D", f"Shape_{name}", {"size": f"Vector3{size}"})
        s.node("Shape", "CollisionShape3D", f"Zones/{name}", {"shape": shape})

    s.node("Security", "Node3D")
    s.instance("FloorCamera", CAMERA, "Security", pos=(0, 6, -19.6), yaw=180,
               props={"sweep_degrees": "100.0"})
    s.instance("OfficeCamera", CAMERA, "Security", pos=(18.5, 4.5, -18.5), yaw=142)

    s.node("Work", "Node3D")
    s.scripted("Station", "Marker3D", SPAWNER, "Work", pos=(-4, 0, 9))
    s.instance("Chute", CHUTE, "Work", pos=(4, 0, 9))

    s.node("Coworkers", "Node3D")
    routes = [
        ("FloorWorker", (-6, 0.05, 4), [(-6, 0, 4), (8, 0, 4)]),
        ("OfficeWorker", (9, 0.05, -3), [(9, 0, -3), (16, 0, -3), (16, 0, 2)]),
    ]
    for name, start, points in routes:
        s.node(f"{name}Route", "Node3D", "Coworkers")
        for i, point in enumerate(points):
            s.node(f"Point{i + 1}", "Marker3D", f"Coworkers/{name}Route", pos=point)
        s.instance(name, COWORKER, "Coworkers", pos=start)
        s.override("Brain", f"Coworkers/{name}",
                   {"route": f'NodePath("../../{name}Route")'}, node_paths=["route"])

    s.instance("Player", "res://scenes/player/player.tscn", pos=(0, 0.05, 15))
    s.instance("HUD", "res://scenes/ui/hud.tscn", node_paths=["controller"],
               props={"controller": 'NodePath("../Player/Controller")'})
    s.save("scenes/levels/stealth_test.tscn")


if __name__ == "__main__":
    main()
