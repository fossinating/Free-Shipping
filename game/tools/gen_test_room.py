"""Generates scenes/world/test_room.tscn. Blockout geometry is easier to
tweak as a table of boxes than by hand-editing the scene file."""

from pathlib import Path

# name, center (x, y, z), size (x, y, z), material
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

# name, scene/script key, position, extra properties
INSTANCES = [
    ("Incoming", "spawner", (12, 0, 4), {}),
    ("AnyChute", "chute", (16, 0, 4), {}),
    ("SortingIncoming", "spawner", (14, 0, 10),
     {"destinations": 'Array[StringName]([&"red", &"blue"])'}),
    ("RedChute", "chute", (12, 0, 17), {"accepts": '&"red"'}),
    ("BlueChute", "chute", (16, 0, 17), {"accepts": '&"blue"'}),
]

LABELS = [
    ("CrateSign", (-6, 2.2, -4.9), "Extend arms (Shift) at the crate,\nthen shrink (Q) to climb"),
    ("ShelfSign", (5, 4.8, -6.9), "Grow (E) until your core\nis level with the top"),
    ("VentSign", (-11, 2.4, 5.6), "Shrink (Q) to fit"),
    ("ButtonSign", (8, 1.5, 5.9), "Grow to press the button"),
    ("ChuteSign", (14, 2.5, 4), "Grab a package (Click / F)\nand set it in the chute"),
    ("SortSign", (14, 2.5, 13.6), "Hold Click / F to aim, release to throw.\nMatch the chute color"),
]

COLORS = {
    "floor": (0.32, 0.33, 0.35),
    "wall": (0.55, 0.58, 0.62),
    "crate": (0.62, 0.45, 0.27),
    "shelf": (0.25, 0.42, 0.7),
}


def main():
    out = []
    ext = [
        '[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="1_player"]',
        '[ext_resource type="PackedScene" path="res://scenes/ui/hud.tscn" id="2_hud"]',
        '[ext_resource type="PackedScene" path="res://scenes/world/push_button.tscn" id="3_button"]',
        '[ext_resource type="PackedScene" path="res://scenes/work/chute.tscn" id="4_chute"]',
        '[ext_resource type="Script" path="res://scripts/work/package_spawner.gd" id="5_spawner"]',
    ]
    subs = []
    for name, rgb in COLORS.items():
        subs.append(f'[sub_resource type="StandardMaterial3D" id="Mat_{name}"]\n'
                    f'albedo_color = Color({rgb[0]}, {rgb[1]}, {rgb[2]}, 1)\nroughness = 0.85\n')
    subs.append('[sub_resource type="ProceduralSkyMaterial" id="SkyMat"]\n'
                'sky_top_color = Color(0.35, 0.45, 0.6, 1)\n'
                'sky_horizon_color = Color(0.6, 0.62, 0.66, 1)\n')
    subs.append('[sub_resource type="Sky" id="Sky"]\nsky_material = SubResource("SkyMat")\n')
    subs.append('[sub_resource type="Environment" id="Env"]\nbackground_mode = 2\n'
                'sky = SubResource("Sky")\nambient_light_source = 2\n'
                'ambient_light_color = Color(0.55, 0.57, 0.6, 1)\n'
                'ambient_light_energy = 0.5\ntonemap_mode = 2\n')

    load_steps = len(ext) + len(subs) + 1
    out.append(f"[gd_scene load_steps={load_steps} format=3]\n")
    out.extend(e + "\n" for e in ext)
    out.extend(subs)
    out.append('[node name="TestRoom" type="Node3D"]\n')
    out.append('[node name="Environment" type="WorldEnvironment" parent="."]\n'
               'environment = SubResource("Env")\n')
    out.append('[node name="Sun" type="DirectionalLight3D" parent="."]\n'
               "transform = Transform3D(0.866, -0.354, 0.354, 0, 0.707, 0.707, -0.5, -0.612, 0.612, 0, 10, 0)\n"
               "light_energy = 0.8\nshadow_enabled = true\n")
    out.append('[node name="Geometry" type="Node3D" parent="."]\n')
    for name, (x, y, z), (sx, sy, sz), mat in BOXES:
        out.append(f'[node name="{name}" type="CSGBox3D" parent="Geometry"]\n'
                   f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})\n"
                   f"use_collision = true\nsize = Vector3({sx}, {sy}, {sz})\n"
                   f'material = SubResource("Mat_{mat}")\n')
    for name, (x, y, z), text in LABELS:
        out.append(f'[node name="{name}" type="Label3D" parent="Geometry"]\n'
                   f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})\n"
                   f'pixel_size = 0.01\nbillboard = 1\ntext = "{text}"\n'
                   "font_size = 40\noutline_size = 10\n")
    # Button on the pillar's -Z face, at a height only a tall robot reaches.
    out.append('[node name="HighButton" parent="Geometry" instance=ExtResource("3_button")]\n'
               "transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 8, 5, 6)\n")
    out.append('[node name="Work" type="Node3D" parent="."]\n')
    for name, kind, (x, y, z), props in INSTANCES:
        if kind == "chute":
            header = f'[node name="{name}" parent="Work" instance=ExtResource("4_chute")]'
        else:
            header = f'[node name="{name}" type="Marker3D" parent="Work"]'
        lines = [header, f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})"]
        if kind == "spawner":
            lines.append('script = ExtResource("5_spawner")')
        lines += [f"{key} = {value}" for key, value in props.items()]
        out.append("\n".join(lines) + "\n")
    out.append('[node name="Player" parent="." instance=ExtResource("1_player")]\n'
               "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.05, 2)\n")
    out.append('[node name="HUD" parent="." node_paths=PackedStringArray("controller") '
               'instance=ExtResource("2_hud")]\ncontroller = NodePath("../Player/Controller")\n')
    path = Path(__file__).resolve().parent.parent / "scenes/world/test_room.tscn"
    path.write_text("\n".join(out))


if __name__ == "__main__":
    main()
