"""Generates scenes/levels/maintenance_bay.tscn: the maintenance bay you
wake up in after the accident, and the slice of Fulfillment it opens onto,
with Elle's radio in the Electronics department.

Layout (top-down, -Z is north):
  west        the maintenance bay: repair table, maintenance robot, your
              dock, and a door east onto the floor
  south lane  your work route: Station C -> Chute C
  north-east  Electronics: two aisles (resizing is normal there) and the
              returns rack against the east wall, with the radio on top.
              A sweeping camera watches the department, a coworker
              restocks, and a guard patrols the middle of the floor.
"""

from blockout import Scene

CHUTE = "res://scenes/work/chute.tscn"
SPAWNER = "res://scripts/work/package_spawner.gd"
CAMERA = "res://scenes/suspicion/security_camera.tscn"
COWORKER = "res://scenes/robot/coworker.tscn"
GUARD = "res://scenes/robot/guard.tscn"
ROBOT = "res://scenes/robot/robot.tscn"
ZONE = "res://scripts/suspicion/zone.gd"
DOCK = "res://scenes/items/charging_dock.tscn"
RADIO = "res://scenes/story/radio.tscn"

GEOMETRY = [
    # Floors: the bay (x -28..-12) and Fulfillment (x -12..28).
    ("BayFloor", (-20, -0.5, 0), (16, 1, 16), "floor"),
    ("FloorMain", (8, -0.5, 0), (40, 1, 28), "floor"),
    # Bay walls.
    ("BayWallNorth", (-20, 2.5, -8.5), (17, 5, 1), "wall"),
    ("BayWallSouth", (-20, 2.5, 8.5), (17, 5, 1), "wall"),
    ("BayWallWest", (-28.5, 2.5, 0), (1, 5, 18), "wall"),
    # The wall between the bay and the floor, with a doorway at z -1.5..1.5.
    ("DividerNorth", (-12, 4, -7.75), (0.6, 8, 12.5), "wall"),
    ("DividerSouth", (-12, 4, 7.75), (0.6, 8, 12.5), "wall"),
    ("DividerLintel", (-12, 5.6, 0), (0.6, 4.8, 3), "wall"),
    # Fulfillment walls.
    ("WallNorth", (8, 4, -14.5), (41, 8, 1), "wall"),
    ("WallSouth", (8, 4, 14.5), (41, 8, 1), "wall"),
    ("WallEast", (28.5, 4, 0), (1, 8, 30), "wall"),
    # The bay's repair table.
    ("RepairTable", (-22, 0.4, 0), (2.2, 0.8, 3), "crate"),
    # Electronics: two aisle shelves and the returns rack.
    ("ShelfA", (15, 1.5, -8.5), (1.2, 3, 8), "shelf"),
    ("ShelfB", (19.5, 1.5, -8.5), (1.2, 3, 8), "shelf"),
    ("ReturnsRack", (26.6, 1.4, -10), (1.6, 2.8, 4), "shelf"),
    # Cover on the main floor.
    ("CrateA", (2, 0.75, -6), (2, 1.5, 2), "crate"),
    ("CrateB", (8, 0.6, 1), (1.4, 1.2, 1.4), "crate"),
    ("CrateC", (22, 0.75, 3), (2, 1.5, 2), "crate"),
]

LABELS = [
    ("BaySign", (-20, 4.0, -7.9), "MAINTENANCE BAY\nMaintenance break: 1 hour per year"),
    ("TicketSign", (-11.6, 3.0, 3.4),
     "REPAIR TICKET #00412\nRoof leak, Corridor B\nStatus: PENDING (214 days)"),
    ("StationSign", (-4, 2.5, 11), "STATION C"),
    ("ChuteSign", (10, 2.5, 11), "CHUTE C"),
    ("ElectronicsSign", (17, 4.4, -3.4), "ELECTRONICS\nResizing is normal in the aisles"),
    ("ReturnsSign", (26.6, 3.9, -7.6), "RETURNS TO SHELF"),
]


def main():
    s = Scene("MaintenanceBay")
    s.root("res://scripts/levels/maintenance_bay.gd", node_paths=[
        "hud", "player", "maintenance_bot", "diagnostics", "receiver", "radio", "bay_door",
        "respawn"], props={
        "hud": 'NodePath("HUD")',
        "player": 'NodePath("Player")',
        "maintenance_bot": 'NodePath("MaintenanceBot")',
        "diagnostics": 'NodePath("Diagnostics")',
        "receiver": 'NodePath("SignalReceiver")',
        "radio": 'NodePath("Radio")',
        "bay_door": 'NodePath("Geometry/BayDoor")',
        "respawn": 'NodePath("Respawn")',
    })
    s.environment()
    s.navigation()
    s.node("Geometry", "Node3D", groups=["navigation_geometry"])
    for name, center, size, material in GEOMETRY:
        s.box(name, center, size, material, parent="Geometry")
    for name, pos, text in LABELS:
        s.label(name, pos, text, parent="Geometry", size=32)

    # The bay door slides up once the diagnostics are done.
    door_shape = s.sub_resource("BoxShape3D", "Shape_door", {"size": "Vector3(3, 3.2, 0.3)"})
    door_mesh = s.sub_resource("BoxMesh", "Mesh_door",
                               {"size": "Vector3(3, 3.2, 0.3)",
                                "material": s.material("door")})
    s.node("BayDoor", "AnimatableBody3D", "Geometry",
           {"script": s.ext_resource("Script", "res://scripts/world/door.gd")},
           pos=(-12, 1.6, 0), yaw=90)
    s.node("Shape", "CollisionShape3D", "Geometry/BayDoor", {"shape": door_shape})
    s.node("Mesh", "MeshInstance3D", "Geometry/BayDoor", {"mesh": door_mesh})

    s.node("Zones", "Node3D")
    zones = [
        ("Fulfillment", (8, 4, 0), (40, 8, 28), {}),
        ("MaintenanceBay", (-20, 3, 0), (16, 6, 16),
         {"zone_name": '"Maintenance Bay"', "allow_resize": "true"}),
        ("Electronics", (17.25, 4, -8.5), (8, 8, 10),
         {"zone_name": '"Electronics aisles"', "allow_resize": "true"}),
    ]
    for name, center, size, props in zones:
        props = {"zone_name": f'"{name}"', **props}
        s.scripted(name, "Area3D", ZONE, "Zones", props=props, pos=center)
        shape = s.sub_resource("BoxShape3D", f"Shape_{name}", {"size": f"Vector3{size}"})
        s.node("Shape", "CollisionShape3D", f"Zones/{name}", {"shape": shape})

    s.node("Security", "Node3D")
    s.instance("ElectronicsCamera", CAMERA, "Security", pos=(22, 5, -13.6), yaw=180,
               props={"sweep_degrees": "90.0"})

    s.instance("Dock", DOCK, pos=(-26, 0, 6), yaw=90)
    # Elle's radio, on top of the returns rack, facing the aisle.
    s.instance("Radio", RADIO, pos=(26.1, 2.8, -10), yaw=-90)

    s.node("Work", "Node3D")
    s.scripted("StationC", "Marker3D", SPAWNER, "Work", pos=(-4, 0, 9))
    s.instance("ChuteC", CHUTE, "Work", pos=(10, 0, 9))

    s.node("Coworkers", "Node3D")
    s.node("RestockerRoute", "Node3D", "Coworkers")
    for i, point in enumerate([(13, 0, -2), (23, 0, -2)]):
        s.node(f"Point{i + 1}", "Marker3D", "Coworkers/RestockerRoute", pos=point)
    s.instance("Restocker", COWORKER, "Coworkers", pos=(13, 0.05, -2))
    s.override("Brain", "Coworkers/Restocker",
               {"route": 'NodePath("../../RestockerRoute")'}, node_paths=["route"])

    s.node("Guards", "Node3D")
    s.node("FloorGuardRoute", "Node3D", "Guards")
    for i, point in enumerate([(-4, 0, -5), (10, 0, -5), (10, 0, 4), (-4, 0, 4)]):
        s.node(f"Point{i + 1}", "Marker3D", "Guards/FloorGuardRoute", pos=point)
    s.instance("FloorGuard", GUARD, "Guards", pos=(-4, 0.05, -5))
    s.override("Brain", "Guards/FloorGuard", {"route": 'NodePath("../../FloorGuardRoute")'},
               node_paths=["route"])

    # The maintenance robot: still under control, so no brain of its own;
    # the level script turns it to watch you.
    bot_mat = s.sub_resource("StandardMaterial3D", "Mat_maintenance",
                             {"albedo_color": "Color(0.85, 0.85, 0.3, 1)", "roughness": "0.6"})
    s.instance("MaintenanceBot", ROBOT, pos=(-19.5, 0.05, 0), yaw=90)
    s.override("Casing", "MaintenanceBot/Visual/Core", {"material_override": bot_mat})
    s.label("BotTag", (-19.5, 2.6, 0), "M-7\nMAINTENANCE", size=28)

    s.node("Respawn", "Marker3D", pos=(-22, 0.85, 0), yaw=-90)
    s.instance("Player", "res://scenes/player/player.tscn", pos=(-22, 0.85, 0), yaw=-90)
    s.scripted("SignalReceiver", "Node", "res://scripts/story/signal_receiver.gd",
               props={"robot": 'NodePath("../Player")'}, node_paths=["robot"])
    s.scripted("Diagnostics", "Node", "res://scripts/story/diagnostics.gd",
               props={"robot": 'NodePath("../Player")', "hud": 'NodePath("../HUD")'},
               node_paths=["robot", "hud"])
    s.instance("HUD", "res://scenes/ui/hud.tscn", node_paths=["controller", "receiver"],
               props={"controller": 'NodePath("../Player/Controller")',
                      "receiver": 'NodePath("../SignalReceiver")'})
    s.save("scenes/levels/maintenance_bay.tscn")


if __name__ == "__main__":
    main()
