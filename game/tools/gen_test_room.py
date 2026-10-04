"""Generates scenes/world/test_room.tscn, the movement and package sandbox."""

from blockout import Scene

# name, center, size, material
BOXES = [
    ("Floor", (0, -0.5, 0), (40, 1, 40), "floor"),
    ("WallNorth", (0, 4, -20.5), (42, 8, 1), "wall"),
    ("WallSouth", (0, 4, 20.5), (42, 8, 1), "wall"),
    ("WallWest", (-20.5, 4, 0), (1, 8, 40), "wall"),
    ("WallEast", (20.5, 4, 0), (1, 8, 40), "wall"),
    # Climbing ledges of increasing height.
    ("Crate", (-6, 0.5, -6), (2, 1, 2), "crate"),
    ("ShelfLow", (-1, 1.25, -8), (4, 2.5, 2), "shelf"),
    ("ShelfMid", (5, 2, -8), (4, 4, 2), "shelf"),
    ("ShelfHigh", (11, 3, -8), (4, 6, 2), "shelf"),
    # A vent you have to shrink to fit under (1.6 m gap).
    ("VentWallLeft", (-14.5, 3, 6), (5, 6, 0.5), "wall"),
    ("VentWallRight", (-7.5, 3, 6), (5, 6, 0.5), "wall"),
    ("VentTop", (-11, 3.8, 6), (2, 4.4, 0.5), "wall"),
    # A pillar with a button only a fully grown robot can reach.
    ("ButtonPillar", (8, 3, 6.5), (1, 6, 1), "wall"),
    # A railing to throw packages over into the sorting chutes.
    ("Railing", (14, 0.75, 14), (8, 1.5, 0.3), "wall"),
]

LABELS = [
    ("CrateSign", (-6, 2.2, -4.9), "Extend arms (Shift) at the crate,\nthen shrink (Q) to climb"),
    ("ShelfSign", (5, 4.8, -6.9), "Grow (E) until your core\nis level with the top"),
    ("VentSign", (-11, 2.4, 5.6), "Shrink (Q) to fit"),
    ("ButtonSign", (8, 1.5, 5.9), "Grow to press the button"),
    ("ChuteSign", (14, 2.5, 4), "Grab a package (Click / F)\nand set it in the chute"),
    ("SortSign", (14, 2.5, 13.6), "Hold Click / F to aim, release to throw.\nMatch the chute color"),
]

CHUTE = "res://scenes/work/chute.tscn"
SPAWNER = "res://scripts/work/package_spawner.gd"


def main():
    scene = Scene("TestRoom")
    scene.environment()
    scene.node("Geometry", "Node3D")
    for name, center, size, material in BOXES:
        scene.box(name, center, size, material, parent="Geometry")
    for name, pos, text in LABELS:
        scene.label(name, pos, text, parent="Geometry")
    # Button on the pillar's -Z face, at a height only a tall robot reaches.
    scene.instance("HighButton", "res://scenes/world/push_button.tscn", "Geometry",
                   pos=(8, 5, 6), yaw=180)
    scene.node("Work", "Node3D")
    scene.scripted("Incoming", "Marker3D", SPAWNER, "Work", pos=(12, 0, 4))
    scene.instance("AnyChute", CHUTE, "Work", pos=(16, 0, 4))
    scene.scripted("SortingIncoming", "Marker3D", SPAWNER, "Work", pos=(14, 0, 10),
                   props={"destinations": 'Array[StringName]([&"red", &"blue"])'})
    scene.instance("RedChute", CHUTE, "Work", pos=(12, 0, 17), props={"accepts": '&"red"'})
    scene.instance("BlueChute", CHUTE, "Work", pos=(16, 0, 17), props={"accepts": '&"blue"'})
    scene.instance("Player", "res://scenes/player/player.tscn", pos=(0, 0.05, 2))
    scene.instance("HUD", "res://scenes/ui/hud.tscn", node_paths=["controller"],
                   props={"controller": 'NodePath("../Player/Controller")'})
    scene.save("scenes/world/test_room.tscn")


if __name__ == "__main__":
    main()
