"""Tiny helper for writing blockout .tscn files from Python tables.

Level geometry is easier to tweak as a list of boxes than by hand-editing
scene files. Each generator script builds a Scene and saves it.
"""

import math
from pathlib import Path

GAME_ROOT = Path(__file__).resolve().parent.parent

COLORS = {
    "floor": (0.32, 0.33, 0.35),
    "wall": (0.55, 0.58, 0.62),
    "crate": (0.62, 0.45, 0.27),
    "shelf": (0.25, 0.42, 0.7),
    "hazard": (0.9, 0.75, 0.15),
    "conveyor": (0.2, 0.22, 0.24),
    "door": (0.75, 0.3, 0.2),
    "metal": (0.5, 0.55, 0.6),
    "scanner": (0.15, 0.6, 0.65),
    "office": (0.7, 0.68, 0.6),
}


def fmt(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return repr(round(value, 4))
    return str(value)


def vec3(v):
    return f"Vector3({fmt(float(v[0]))}, {fmt(float(v[1]))}, {fmt(float(v[2]))})"


def transform(pos=(0, 0, 0), yaw_degrees=0.0, roll_degrees=0.0):
    """Yaw turns about +Y; roll tilts about the local Z axis first (a ramp
    rising toward local +X has a positive roll)."""
    c = math.cos(math.radians(yaw_degrees))
    s = math.sin(math.radians(yaw_degrees))
    cr = math.cos(math.radians(roll_degrees))
    sr = math.sin(math.radians(roll_degrees))
    yaw = [[c, 0, s], [0, 1, 0], [-s, 0, c]]
    roll = [[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]]
    rows = [[sum(yaw[i][k] * roll[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    r = lambda x: fmt(round(x, 4) + 0.0)
    basis = ", ".join(r(rows[i][j]) for i in range(3) for j in range(3))
    return (f"Transform3D({basis}, "
            f"{fmt(float(pos[0]))}, {fmt(float(pos[1]))}, {fmt(float(pos[2]))})")


def _node_paths(names):
    if not names:
        return ""
    quoted = ", ".join(f'"{n}"' for n in names)
    return f" node_paths=PackedStringArray({quoted})"


class Scene:
    def __init__(self, root_name, root_type="Node3D"):
        self.ext = []
        self.subs = []
        self.nodes = []
        self._ext_ids = {}
        self._materials = {}
        self._root = (root_name, root_type)
        self._root_props = {}
        self._root_paths = []

    def root(self, script_path=None, props=None, node_paths=None):
        """Sets the root node's script and properties."""
        if script_path:
            self._root_props["script"] = self.ext_resource("Script", script_path)
        self._root_props.update(props or {})
        self._root_paths += node_paths or []

    # --- resources ---

    def ext_resource(self, kind, path):
        if path not in self._ext_ids:
            rid = f"{len(self.ext) + 1}_{Path(path).stem}"
            self._ext_ids[path] = rid
            self.ext.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
        return f'ExtResource("{self._ext_ids[path]}")'

    def sub_resource(self, kind, rid, props):
        lines = [f'[sub_resource type="{kind}" id="{rid}"]']
        lines += [f"{k} = {v}" for k, v in props.items()]
        self.subs.append("\n".join(lines))
        return f'SubResource("{rid}")'

    def material(self, name):
        if name not in self._materials:
            r, g, b = COLORS[name]
            self._materials[name] = self.sub_resource(
                "StandardMaterial3D", f"Mat_{name}",
                {"albedo_color": f"Color({r}, {g}, {b}, 1)", "roughness": "0.85"})
        return self._materials[name]

    # --- nodes ---

    def _add_node(self, header, props):
        lines = [header] + [f"{k} = {v}" for k, v in props.items()]
        self.nodes.append("\n".join(lines))

    def node(self, name, kind, parent=".", props=None, pos=None, yaw=0.0, node_paths=None,
             groups=None, roll=0.0):
        props = dict(props or {})
        if pos is not None:
            props = {"transform": transform(pos, yaw, roll), **props}
        group_list = ""
        if groups:
            group_list = " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
        self._add_node(f'[node name="{name}" type="{kind}" parent="{parent}"'
                       f'{_node_paths(node_paths)}{group_list}]', props)

    def navigation(self, geometry_group="navigation_geometry"):
        """A region that bakes a navmesh at startup from static colliders
        under nodes in `geometry_group`."""
        mesh = self.sub_resource("NavigationMesh", "NavMesh", {
            "geometry_parsed_geometry_type": "1",
            "geometry_source_geometry_mode": "1",
            "geometry_source_group_name": f'&"{geometry_group}"',
            "agent_height": "2.0",
            "agent_radius": "0.5",
            "agent_max_climb": "0.25",
        })
        self.scripted("Navigation", "NavigationRegion3D",
                      "res://scripts/world/level_navigation.gd",
                      props={"navigation_mesh": mesh})

    def instance(self, name, scene_path, parent=".", props=None, pos=None, yaw=0.0,
                 node_paths=None):
        res = self.ext_resource("PackedScene", scene_path)
        props = dict(props or {})
        if pos is not None:
            props = {"transform": transform(pos, yaw), **props}
        self._add_node(f'[node name="{name}" parent="{parent}"{_node_paths(node_paths)} '
                       f'instance={res}]', props)

    def override(self, name, parent, props, node_paths=None):
        """Sets properties on a node that came from an instanced scene."""
        self._add_node(f'[node name="{name}" parent="{parent}"{_node_paths(node_paths)}]', props)

    def scripted(self, name, kind, script_path, parent=".", props=None, pos=None, yaw=0.0,
                 node_paths=None):
        props = {"script": self.ext_resource("Script", script_path), **(props or {})}
        self.node(name, kind, parent, props, pos, yaw, node_paths)

    def box(self, name, center, size, material, parent=".", groups=None, roll=0.0, yaw=0.0):
        self.node(name, "CSGBox3D", parent, {
            "use_collision": "true",
            "size": vec3(size),
            "material": self.material(material),
        }, pos=center, groups=groups, roll=roll, yaw=yaw)

    def label(self, name, pos, text, parent=".", size=40):
        escaped = text.replace('"', '\\"')
        self.node(name, "Label3D", parent, {
            "pixel_size": "0.01",
            "billboard": "1",
            "text": f'"{escaped}"',
            "font_size": str(size),
            "outline_size": "10",
        }, pos=pos)

    def environment(self):
        sky_mat = self.sub_resource("ProceduralSkyMaterial", "SkyMat", {
            "sky_top_color": "Color(0.35, 0.45, 0.6, 1)",
            "sky_horizon_color": "Color(0.6, 0.62, 0.66, 1)",
        })
        sky = self.sub_resource("Sky", "Sky", {"sky_material": sky_mat})
        env = self.sub_resource("Environment", "Env", {
            "background_mode": "2",
            "sky": sky,
            "ambient_light_source": "2",
            "ambient_light_color": "Color(0.55, 0.57, 0.6, 1)",
            "ambient_light_energy": "0.5",
            "tonemap_mode": "2",
        })
        self.node("Environment", "WorldEnvironment", props={"environment": env})
        self.node("Sun", "DirectionalLight3D", props={
            "transform": "Transform3D(0.866, -0.354, 0.354, 0, 0.707, 0.707, "
                         "-0.5, -0.612, 0.612, 0, 10, 0)",
            "light_energy": "0.8",
            "shadow_enabled": "true",
        })

    def save(self, relative_path):
        name, kind = self._root
        root = [f'[node name="{name}" type="{kind}"{_node_paths(self._root_paths)}]']
        root += [f"{k} = {v}" for k, v in self._root_props.items()]
        parts = [f"[gd_scene load_steps={len(self.ext) + len(self.subs) + 1} format=3]"]
        parts += self.ext + self.subs + ["\n".join(root)] + self.nodes
        path = GAME_ROOT / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n\n".join(parts) + "\n")
        print(f"wrote {relative_path}")
