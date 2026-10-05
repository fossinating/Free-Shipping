"""Generates scenes/levels/warehouse.tscn: the warehouse as far as the
vertical slice goes. One interconnected level: the maintenance bay you wake
up in, Fulfillment (your work route, Electronics and Hardware), and
Receiving behind a level 1 scanner.

Layout (top-down, -Z is north):

                 x -12            x 17      x 28              x 60
  z -40   +---------------------------------+
          | office | racks       conveyor   | SORTING PIT     |
          | (vent) |  RackA/B    -> ramp -> |  [island: coil] |
          |              HARDWARE           |                 |
  z -14   +-----+   (wide opening)    +-----+-----------------+
  bay     |     |                     | ELECTRONICS | RECEIVING      |
  x -28   | door|   Station C ... Chute C          [scanner]  office  |
  ..-12   +-----+-----------------------------------+  conveyor/docks |
  z 14                                               +----------------+

- The bay (x -28..-12): repair table, M-7, your dock.
- Fulfillment's main floor (x -12..28, z -14..14): Station C, Chute C,
  Electronics in the north-east with Elle's radio on the returns rack.
- Hardware (x -12..28, z -40..-14): tool racks, the floor supervisor (a
  guard carrying the level 1 card), his office in the north-west corner
  (badge door, level 1 spare card inside, a low air vent at the back), and
  a conveyor and ramp that launch a robot on wheels over the sorting pit
  onto an island holding the electromagnet coil.
- Receiving (x 28..60, z -14..14), through a scanner checkpoint: pallets
  of unopened stock (tape, straps), the wheel motor on the inbound parts
  pallet, metal racking with overstock on top (magnetic hands), the
  unload conveyor and truck docks, the dock boss (a guard carrying the
  level 2 card), the roofless receiving office with a spare card, and
  the holding cage by the entrance where confiscated items wait in the
  evidence locker (badge level 2, so going in is suspicious).
- Walking into the bay saves the game.
"""

import math

from blockout import Scene

CHUTE = "res://scenes/work/chute.tscn"
PACKAGE = "res://scenes/work/package.tscn"
SPAWNER = "res://scripts/work/package_spawner.gd"
CAMERA = "res://scenes/suspicion/security_camera.tscn"
COWORKER = "res://scenes/robot/coworker.tscn"
GUARD = "res://scenes/robot/guard.tscn"
ROBOT = "res://scenes/robot/robot.tscn"
ZONE = "res://scripts/suspicion/zone.gd"
DOCK = "res://scenes/items/charging_dock.tscn"
LOCKER = "res://scenes/items/evidence_locker.tscn"
RADIO = "res://scenes/story/radio.tscn"
ITEM = "res://scenes/items/item.tscn"
ITEM_SPOT = "res://scripts/items/item_spot.gd"
CARRIER = "res://scripts/items/keycard_carrier.gd"
DOOR = "res://scripts/world/door.gd"
CHECKPOINT = "res://scripts/world/scanner_checkpoint.gd"
CONVEYOR = "res://scripts/world/conveyor.gd"
RAMP = "res://scripts/world/launch_ramp.gd"

# The ramp in Hardware rises from (14, 0) to (17, 1.2) along +X.
RAMP_ANGLE = math.degrees(math.atan2(1.2, 3.0))
_n = (-math.sin(math.radians(RAMP_ANGLE)), math.cos(math.radians(RAMP_ANGLE)))
RAMP_CENTER = (15.5 + _n[0] * -0.2, 0.6 + _n[1] * -0.2, -32)

# (name, center, size, material[, extras]) where extras can set "groups"
# and "roll" (tilt about the box's own Z axis, in degrees).
GEOMETRY = [
    # --- The maintenance bay (x -28..-12) ---
    ("BayFloor", (-20, -0.5, 0), (16, 1, 16), "floor"),
    ("BayWallNorth", (-20, 2.5, -8.5), (17, 5, 1), "wall"),
    ("BayWallSouth", (-20, 2.5, 8.5), (17, 5, 1), "wall"),
    ("BayWallWest", (-28.5, 2.5, 0), (1, 5, 18), "wall"),
    # The wall between the bay and the floor, with a doorway at z -1.5..1.5.
    ("DividerNorth", (-12, 4, -7.75), (0.6, 8, 12.5), "wall"),
    ("DividerSouth", (-12, 4, 7.75), (0.6, 8, 12.5), "wall"),
    ("DividerLintel", (-12, 5.6, 0), (0.6, 4.8, 3), "wall"),
    ("RepairTable", (-22, 0.4, 0), (2.2, 0.8, 3), "crate"),

    # --- Fulfillment's main floor (x -12..28, z -14..14) ---
    ("FloorMain", (8, -0.5, 0), (40, 1, 28), "floor"),
    ("WallSouth", (8, 4, 14.5), (41, 8, 1), "wall"),
    # North wall, with a wide opening into Hardware at x -8..10.
    ("WallNorthWest", (-10.25, 4, -14.5), (4.5, 8, 1), "wall"),
    ("WallNorthEast", (19.25, 4, -14.5), (18.5, 8, 1), "wall"),
    ("WallNorthLintel", (1, 6.5, -14.5), (18, 3, 1), "wall"),
    # East wall, with the Receiving door at z 5.5..8.5.
    ("WallEastNorth", (28.5, 4, -4.75), (1, 8, 20.5), "wall"),
    ("WallEastSouth", (28.5, 4, 11.75), (1, 8, 6.5), "wall"),
    ("WallEastLintel", (28.5, 5.6, 7), (1, 4.8, 3), "wall"),
    # The scanner arch in front of the Receiving door.
    ("ScannerPostNorth", (26.8, 1.6, 5.25), (0.4, 3.2, 0.5), "scanner"),
    ("ScannerPostSouth", (26.8, 1.6, 8.75), (0.4, 3.2, 0.5), "scanner"),
    ("ScannerBar", (26.8, 3.35, 7), (0.4, 0.3, 4), "scanner"),
    # Electronics: two aisle shelves and the returns rack.
    ("ShelfA", (15, 1.5, -8.5), (1.2, 3, 8), "shelf"),
    ("ShelfB", (19.5, 1.5, -8.5), (1.2, 3, 8), "shelf"),
    ("ReturnsRack", (26.6, 1.4, -10), (1.6, 2.8, 4), "shelf"),
    # Cover on the main floor.
    ("CrateA", (2, 0.75, -6), (2, 1.5, 2), "crate"),
    ("CrateB", (8, 0.6, 1), (1.4, 1.2, 1.4), "crate"),
    ("CrateC", (22, 0.75, 3), (2, 1.5, 2), "crate"),

    # --- Hardware (x -12..28, z -40..-14) ---
    # The floor is 6 m deep so the sorting pit (x 17..28, z -40..-25) has walls.
    ("HardwareFloor", (2.5, -3, -27), (29, 6, 26), "floor"),
    ("HardwareFloorEast", (22.5, -3, -19.5), (11, 6, 11), "floor"),
    ("PitFloor", (22.5, -5.5, -32.5), (11, 1, 15), "floor"),
    ("HardwareWallNorth", (8, 1, -40.5), (41, 14, 1), "wall"),
    ("HardwareWallWest", (-12.5, 4, -27), (1, 8, 27), "wall"),
    ("HardwareWallEast", (28.5, 1, -27.5), (1, 14, 27), "wall"),
    # Tool racks, with an aisle between them.
    ("RackA", (3, 1.5, -21), (12, 3, 1.2), "shelf"),
    ("RackB", (3, 1.5, -26), (12, 3, 1.2), "shelf"),
    ("ToolBench", (8, 0.5, -17), (2, 1, 1), "crate"),
    ("HardwareCrate", (-8, 0.5, -20), (1.4, 1, 1.4), "crate"),
    # The supervisor's office: roofed, a badge door on the south side and
    # an air vent (1.6 m high) at the back of the east wall.
    ("OfficeEastNorth", (-3, 1.75, -39.6), (0.4, 3.5, 0.8), "office"),
    ("OfficeEastSouth", (-3, 1.75, -34.8), (0.4, 3.5, 5.6), "office"),
    ("OfficeVentTop", (-3, 2.55, -38.4), (0.4, 1.9, 1.6), "office"),
    ("OfficeSouthWest", (-10.25, 1.75, -32), (3.5, 3.5, 0.4), "office"),
    ("OfficeSouthEast", (-4.85, 1.75, -32), (3.3, 3.5, 0.4), "office"),
    ("OfficeLintel", (-7.5, 3.25, -32), (2, 0.5, 0.4), "office"),
    ("OfficeRoof", (-7.4, 3.65, -35.9), (9.2, 0.3, 8.2), "office"),
    ("OfficeDesk", (-8.5, 0.5, -37.5), (2.4, 1, 1.2), "crate"),
    # Lumber rack hiding the vent from the floor.
    ("LumberRack", (0.6, 1.5, -36.5), (1.2, 3, 7), "shelf"),
    # The conveyor, flush with the floor, then the ramp up to the pit's edge.
    ("ConveyorBelt", (9.5, -0.09, -32), (9, 0.2, 2.5), "conveyor"),
    ("Ramp", RAMP_CENTER, (3.6, 0.4, 2.5), "hazard", {"roll": RAMP_ANGLE}),
    # The island in the pit: 7.5 m above the pit floor, too tall to climb.
    ("Island", (24.25, -1.25, -32.5), (7.5, 7.5, 7), "crate"),

    # --- Receiving (x 28..60, z -14..14) ---
    ("ReceivingFloor", (44.25, -0.5, 0), (32.5, 1, 28), "floor"),
    ("ReceivingWallNorth", (44.5, 4, -14.5), (33, 8, 1), "wall"),
    ("ReceivingWallSouth", (44.5, 4, 14.5), (33, 8, 1), "wall"),
    ("ReceivingWallEast", (60.5, 4, 0), (1, 8, 30), "wall"),
    # Pallets of unopened stock.
    ("PalletA", (33, 0.6, -11), (1.6, 1.2, 1.6), "crate"),
    ("PalletB", (37, 0.6, -11), (1.6, 1.2, 1.6), "crate"),
    ("PalletC", (41, 1.2, -11), (1.6, 2.4, 1.6), "crate"),
    ("PalletD", (45, 0.6, -11), (1.6, 1.2, 1.6), "crate"),
    ("PalletE", (33, 1.2, -7), (1.6, 2.4, 1.6), "crate"),
    ("PalletF", (37, 0.6, -7), (1.6, 1.2, 1.6), "crate"),
    ("PalletG", (41, 0.6, -7), (1.6, 1.2, 1.6), "crate"),
    ("PalletH", (45, 0.6, -7), (1.6, 1.2, 1.6), "crate"),
    ("PartsPallet", (54, 0.6, -10), (2, 1.2, 2), "crate"),
    # Metal racking, too tall to climb without magnetic hands.
    ("MetalRack", (38, 3.75, 1), (5, 7.5, 1.5), "metal", {"groups": ["metal"]}),
    # The receiving office: no roof, a badge door on the west side.
    ("RecOfficeNorth", (55, 1.5, -2), (10, 3, 0.4), "office"),
    ("RecOfficeSouth", (55, 1.5, 6), (10, 3, 0.4), "office"),
    ("RecOfficeWestNorth", (50, 1.5, -0.5), (0.4, 3, 3), "office"),
    ("RecOfficeWestSouth", (50, 1.5, 4.5), (0.4, 3, 3), "office"),
    ("RecOfficeDesk", (56, 0.5, 2), (1.2, 1, 2.4), "crate"),
    # The unload conveyor from the truck docks, and its end stop.
    ("UnloadBelt", (47, -0.09, 10.5), (22, 0.2, 2), "conveyor"),
    ("UnloadStop", (35.8, 0.4, 10.5), (0.4, 0.8, 2), "crate"),
    ("DockDoor1", (40, 2, 13.95), (3, 4, 0.1), "door"),
    ("DockDoor2", (48, 2, 13.95), (3, 4, 0.1), "door"),
    ("DockDoor3", (56, 2, 13.95), (3, 4, 0.1), "door"),
    # The holding cage against the west wall, open at the north end of
    # its east side. Low enough to climb over, too.
    ("HoldingNorth", (30.45, 1, -4.5), (3.1, 2, 0.2), "office"),
    ("HoldingSouth", (30.45, 1, 1.5), (3.1, 2, 0.2), "office"),
    ("HoldingEast", (32, 1, -0.75), (0.2, 2, 4.5), "office"),
]

LABELS = [
    ("BaySign", (-20, 4.0, -7.9), "MAINTENANCE BAY\nMaintenance break: 1 hour per year"),
    ("TicketSign", (-11.6, 3.0, 3.4),
     "REPAIR TICKET #00412\nRoof leak, Corridor B\nStatus: PENDING (214 days)"),
    ("StationSign", (-4, 2.5, 11), "STATION C"),
    ("ChuteSign", (10, 2.5, 11), "CHUTE C"),
    ("ElectronicsSign", (17, 4.4, -3.4), "ELECTRONICS\nResizing is normal in the aisles"),
    ("ReturnsSign", (26.6, 3.9, -7.6), "RETURNS TO SHELF"),
    ("HardwareSign", (1, 4.4, -14), "HARDWARE"),
    ("OfficeSign", (-7.5, 4.3, -31.7), "FLOOR SUPERVISOR\nCLEARANCE 1"),
    ("VentSign", (-2.6, 1.9, -38.4), "AIR RETURN"),
    ("PitSign", (17.5, 2.6, -24.5), "CAUTION: SORTING PIT\nNo carts beyond this point"),
    ("IslandSign", (24, 4.2, -32.5), "LOST & FOUND"),
    ("ReceivingSign", (32, 4.4, 7), "RECEIVING"),
    ("PartsSign", (54, 2.9, -10), "INBOUND PARTS\nDelivery cart motors"),
    ("RackSign", (38, 2.6, 1.9), "OVERSTOCK\nMetal racking"),
    ("RecOfficeSign", (49.7, 3.6, 2), "RECEIVING OFFICE\nCLEARANCE 2"),
    ("HoldingSign", (32.3, 2.4, 0.9), "HOLDING\nCLEARANCE 2"),
    ("BackupSign", (-12.6, 3.6, -2.2), "M-7 BACKUP TERMINAL\nWalk in to save"),
    ("Dock1Sign", (40, 4.5, 13.6), "DOCK 1"),
    ("Dock2Sign", (48, 4.5, 13.6), "DOCK 2"),
    ("Dock3Sign", (56, 4.5, 13.6), "DOCK 3"),
]

# Fixed pickups: key parts, keycards and guaranteed basics.
# (name, item id, position)
ITEMS = [
    # Hardware: something to fight with, and the spare level 1 card.
    ("ToolBenchCutter", "box_cutter", (8, 1.1, -17)),
    ("OfficeKeycard", "keycard_1", (-7.6, 1.08, -37.5)),
    # The island in the sorting pit: the key part for magnetic hands.
    ("IslandCoil", "electromagnet_coil", (25, 2.75, -32.5)),
    ("IslandWrench", "wrench", (23, 2.6, -31)),
    # Receiving: the wheel motor (always here) and what goes with it.
    ("WheelMotor", "wheel_motor", (54, 1.4, -10)),
    ("PartsStrap", "strap", (53.3, 1.3, -9.3)),
    ("PalletTape", "tape", (41, 1.3, -7)),
    ("RecOfficeKeycard", "keycard_2", (55.6, 1.08, 2)),
    # Overstock on top of the metal racking.
    ("OverstockId", "fake_id", (37, 7.6, 1)),
    ("OverstockSpoofer", "scanner_spoofer", (39, 7.6, 1)),
]

# Spots that pick from a zone's item pool. (name, pool, position)
ITEM_SPOTS = [
    ("ElectronicsSpotA", "electronics", (15, 3.2, -6)),
    ("ElectronicsSpotB", "electronics", (19.5, 3.2, -11)),
    ("ElectronicsSpotC", "electronics", (17.3, 0.3, -12.5)),
    ("HardwareSpotA", "hardware", (0, 3.2, -21)),
    ("HardwareSpotB", "hardware", (6, 3.2, -26)),
    ("HardwareSpotC", "hardware", (-8, 1.2, -20)),
    ("ReceivingSpotA", "receiving", (33, 1.3, -11)),
    ("ReceivingSpotB", "receiving", (37, 1.3, -7)),
    ("ReceivingSpotC", "receiving", (45, 1.3, -11)),
    ("ReceivingSpotD", "receiving", (41, 2.5, -11)),
]

# (name, center, size, props)
ZONES = [
    ("Fulfillment", (8, 4, 0), (40, 8, 28), {}),
    ("MaintenanceBay", (-20, 3, 0), (16, 6, 16),
     {"zone_name": '"Maintenance Bay"', "allow_resize": "true"}),
    ("Electronics", (17.25, 4, -8.5), (8, 8, 10),
     {"zone_name": '"Electronics aisles"', "allow_resize": "true"}),
    ("Hardware", (8, 1, -27), (40, 14, 26), {}),
    ("HardwareAisle", (3, 4, -23.5), (12, 8, 3.8),
     {"zone_name": '"Hardware aisle"', "allow_resize": "true"}),
    ("SupervisorOffice", (-7.5, 1.75, -36), (9, 3.5, 8),
     {"zone_name": '"Supervisor\'s office"', "required_clearance": "1"}),
    ("Receiving", (44.25, 4, 0), (32, 8, 28), {"required_clearance": "1"}),
    ("ReceivingOffice", (55, 1.5, 2), (10, 3, 8),
     {"zone_name": '"Receiving office"', "required_clearance": "2"}),
    ("Holding", (30.45, 1.5, -1.5), (3.1, 3, 6),
     {"zone_name": '"Holding cage"', "required_clearance": "2"}),
]


def door(s, name, pos, yaw, width, height):
    shape = s.sub_resource("BoxShape3D", f"Shape_{name}",
                           {"size": f"Vector3({width}, {height}, 0.3)"})
    mesh = s.sub_resource("BoxMesh", f"Mesh_{name}",
                          {"size": f"Vector3({width}, {height}, 0.3)",
                           "material": s.material("door")})
    s.node(name, "AnimatableBody3D", "Geometry", {"script": s.ext_resource("Script", DOOR)},
           pos=pos, yaw=yaw)
    s.node("Shape", "CollisionShape3D", f"Geometry/{name}", {"shape": shape})
    s.node("Mesh", "MeshInstance3D", f"Geometry/{name}", {"mesh": mesh})


def area(s, name, script, parent, center, size, props, yaw=0.0, node_paths=None):
    s.scripted(name, "Area3D", script, parent, props=props, pos=center, yaw=yaw,
               node_paths=node_paths)
    shape = s.sub_resource("BoxShape3D", f"Shape_{name}",
                           {"size": f"Vector3({size[0]}, {size[1]}, {size[2]})"})
    s.node("Shape", "CollisionShape3D", f"{parent}/{name}" if parent != "." else name,
           {"shape": shape})


def checkpoint(s, name, door_name, center, size, clearance, place, contraband, sign):
    area(s, name, CHECKPOINT, "Checkpoints", center, size, {
        "door": f'NodePath("../../Geometry/{door_name}")',
        "required_clearance": str(clearance),
        "place_name": f'"{place}"',
        "check_contraband": "true" if contraband else "false",
        "status_sign": f'NodePath("../../Geometry/{sign}")',
    }, node_paths=["door", "status_sign"])


def patrol(s, parent, name, points, scene):
    s.node(f"{name}Route", "Node3D", parent)
    for i, point in enumerate(points):
        s.node(f"Point{i + 1}", "Marker3D", f"{parent}/{name}Route", pos=point)
    x, y, z = points[0]
    s.instance(name, scene, parent, pos=(x, 0.05, z))
    s.override("Brain", f"{parent}/{name}", {"route": f'NodePath("../../{name}Route")'},
               node_paths=["route"])


def main():
    s = Scene("Warehouse")
    s.root("res://scripts/levels/warehouse.gd", node_paths=[
        "hud", "player", "maintenance_bot", "diagnostics", "receiver", "radio", "bay_door",
        "hardware_zone", "respawn", "dock", "bay_zone"], props={
        "hud": 'NodePath("HUD")',
        "player": 'NodePath("Player")',
        "maintenance_bot": 'NodePath("MaintenanceBot")',
        "diagnostics": 'NodePath("Diagnostics")',
        "receiver": 'NodePath("SignalReceiver")',
        "radio": 'NodePath("Radio")',
        "bay_door": 'NodePath("Geometry/BayDoor")',
        "hardware_zone": 'NodePath("Zones/Hardware")',
        "respawn": 'NodePath("Respawn")',
        "dock": 'NodePath("Dock")',
        "bay_zone": 'NodePath("Zones/MaintenanceBay")',
    })
    s.environment()
    s.navigation()
    s.node("Geometry", "Node3D", groups=["navigation_geometry"])
    for entry in GEOMETRY:
        name, center, size, material = entry[:4]
        extras = entry[4] if len(entry) > 4 else {}
        s.box(name, center, size, material, parent="Geometry", **extras)
    for name, pos, text in LABELS:
        s.label(name, pos, text, parent="Geometry", size=32)
    s.label("ScannerSign", (26.8, 4.1, 7), "SCANNER\nRECEIVING: CLEARANCE 1",
            parent="Geometry", size=32)

    # The bay door slides up once the diagnostics are done; the others are
    # opened by their scanners.
    door(s, "BayDoor", (-12, 1.6, 0), 90, 3, 3.2)
    door(s, "ReceivingGate", (28.5, 1.6, 7), 90, 3, 3.2)
    door(s, "SupervisorDoor", (-7.5, 1.5, -32), 0, 2, 3)
    door(s, "RecOfficeDoor", (50, 1.5, 2), 90, 2, 3)

    s.node("Checkpoints", "Node3D")
    checkpoint(s, "ReceivingScanner", "ReceivingGate", (28.5, 1.5, 7), (7, 3, 2.8),
               1, "Receiving", True, "ScannerSign")
    checkpoint(s, "SupervisorReader", "SupervisorDoor", (-7.5, 1.5, -32), (2, 3, 5),
               1, "The supervisor's office", False, "OfficeSign")
    checkpoint(s, "RecOfficeReader", "RecOfficeDoor", (50, 1.5, 2), (5, 3, 2),
               2, "The receiving office", False, "RecOfficeSign")

    # Conveyors move along their -Z axis: yaw -90 runs east, 90 runs west.
    s.node("Conveyors", "Node3D")
    area(s, "HardwareConveyor", CONVEYOR, "Conveyors", (9.5, 0.5, -32), (2.5, 1, 9), {},
         yaw=-90)
    area(s, "UnloadConveyor", CONVEYOR, "Conveyors", (47, 0.5, 10.5), (2, 1, 22),
         {"speed": "2.0"}, yaw=90)
    area(s, "PitRamp", RAMP, "Conveyors", (16.6, 1.6, -32), (2.5, 1.6, 1.2), {}, yaw=-90)

    s.node("Zones", "Node3D")
    for name, center, size, props in ZONES:
        props = {"zone_name": f'"{name}"', **props}
        area(s, name, ZONE, "Zones", center, size, props)

    s.node("Security", "Node3D")
    s.instance("ElectronicsCamera", CAMERA, "Security", pos=(22, 5, -13.6), yaw=180,
               props={"sweep_degrees": "90.0"})
    s.instance("HardwareCamera", CAMERA, "Security", pos=(-11.4, 5.5, -22), yaw=-90,
               props={"sweep_degrees": "90.0"})
    s.instance("ReceivingCamera", CAMERA, "Security", pos=(40, 5.5, -13.6), yaw=180,
               props={"sweep_degrees": "100.0"})

    s.instance("Dock", DOCK, pos=(-26, 0, 6), yaw=90)
    s.instance("EvidenceLocker", LOCKER, pos=(30, 0, -1.5), yaw=-90)
    # Elle's radio, on top of the returns rack, facing the aisle.
    s.instance("Radio", RADIO, pos=(26.1, 2.8, -10), yaw=-90)

    s.node("Items", "Node3D")
    for name, item_id, pos in ITEMS:
        s.instance(name, ITEM, "Items", pos=pos, props={"item_id": f'&"{item_id}"'})
    for name, pool, pos in ITEM_SPOTS:
        s.scripted(name, "Marker3D", ITEM_SPOT, "Items", props={"pool": f'&"{pool}"'},
                   pos=pos)

    s.node("Work", "Node3D")
    s.scripted("StationC", "Marker3D", SPAWNER, "Work", pos=(-4, 0, 9))
    s.instance("ChuteC", CHUTE, "Work", pos=(10, 0, 9))
    # Unopened stock riding in from the trucks.
    for i, x in enumerate([56, 52, 48]):
        s.instance(f"Inbound{i + 1}", PACKAGE, "Work", pos=(x, 0.4, 10.5))

    s.node("Coworkers", "Node3D")
    patrol(s, "Coworkers", "Restocker", [(13, 0, -2), (23, 0, -2)], COWORKER)
    patrol(s, "Coworkers", "HardwareStocker", [(-5, 0, -23.5), (10, 0, -23.5)],
           COWORKER)
    patrol(s, "Coworkers", "Unloader", [(38, 0, 8), (57, 0, 8)], COWORKER)

    s.node("Guards", "Node3D")
    patrol(s, "Guards", "FloorGuard",
           [(-4, 0, -5), (10, 0, -5), (10, 0, 4), (-4, 0, 4)], GUARD)
    # The floor supervisor and the dock boss each wear a keycard.
    patrol(s, "Guards", "Supervisor",
           [(-6, 0, -18), (12, 0, -18), (12, 0, -29), (-6, 0, -29)], GUARD)
    s.scripted("Keycard", "Node", CARRIER, "Guards/Supervisor", props={"level": "1"})
    s.label("SupervisorTag", (0, 3.0, 0), "FLOOR SUPERVISOR", parent="Guards/Supervisor",
            size=28)
    patrol(s, "Guards", "DockBoss",
           [(33, 0, -2), (46, 0, -2), (46, 0, 6), (33, 0, 6)], GUARD)
    s.scripted("Keycard", "Node", CARRIER, "Guards/DockBoss", props={"level": "2"})
    s.label("DockBossTag", (0, 3.0, 0), "DOCK BOSS", parent="Guards/DockBoss", size=28)

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
    s.save("scenes/levels/warehouse.tscn")


if __name__ == "__main__":
    main()
