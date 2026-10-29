"""Build a local Test place using only Python's standard library.

Art source: tools/world_art.py. Generated output: places/SlimeSalvage-Test.rbxlx.
The output is disposable; never use it as the only copy of Studio art edits.
"""
from pathlib import Path
import json
import xml.etree.ElementTree as ET
import importlib.util

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'places' / 'SlimeSalvage-Test.rbxlx'


def build():
    root = ET.Element('roblox', version='4')
    ET.SubElement(root, 'External').text = 'null'
    ET.SubElement(root, 'External').text = 'nil'
    sequence = 0

    def item(parent, cls, name):
        nonlocal sequence
        sequence += 1
        obj = ET.SubElement(parent, 'Item', {'class': cls, 'referent': f'RBX{sequence}'})
        props = ET.SubElement(obj, 'Properties')
        ET.SubElement(props, 'string', name='Name').text = name
        return obj, props

    def prop(props, kind, name, value):
        ET.SubElement(props, kind, name=name).text = str(value)

    def vector(props, name, values):
        el = ET.SubElement(props, 'Vector3', name=name)
        for key, value in zip(('X', 'Y', 'Z'), values):
            ET.SubElement(el, key).text = str(value)

    def color(props, name, rgb):
        el = ET.SubElement(props, 'Color3', name=name)
        for key, value in zip(('R', 'G', 'B'), rgb):
            ET.SubElement(el, key).text = str(value)

    lighting, light_props = item(root, 'Lighting', 'Lighting')
    prop(light_props, 'float', 'ClockTime', 15.2)
    prop(light_props, 'float', 'Brightness', 2)
    prop(light_props, 'bool', 'GlobalShadows', 'true')
    color(light_props, 'Ambient', [.33, .36, .43])
    color(light_props, 'OutdoorAmbient', [.55, .59, .63])
    prop(light_props, 'float', 'EnvironmentDiffuseScale', .6)
    prop(light_props, 'float', 'EnvironmentSpecularScale', .55)
    _, atmosphere = item(lighting, 'Atmosphere', 'OceanAir')
    prop(atmosphere, 'float', 'Density', .18)
    prop(atmosphere, 'float', 'Haze', 1)
    color(atmosphere, 'Color', [.79, .88, .91])
    color(atmosphere, 'Decay', [.48, .62, .69])
    _, grade = item(lighting, 'ColorCorrectionEffect', 'IslandPalette')
    prop(grade, 'float', 'Saturation', .08)
    prop(grade, 'float', 'Contrast', .04)
    color(grade, 'TintColor', [1, .98, .94])

    workspace, props = item(root, 'Workspace', 'Workspace')
    prop(props, 'bool', 'StreamingEnabled', 'true')
    prop(props, 'float', 'FallenPartsDestroyHeight', -80)
    scene_spec = importlib.util.spec_from_file_location('world_art', ROOT / 'tools/world_art.py')
    world_art = importlib.util.module_from_spec(scene_spec)
    scene_spec.loader.exec_module(world_art)
    art = world_art.parts()
    groups = {}
    for part in art:
        group = part.get('group', 'shore')
        if group not in groups:
            groups[group], _ = item(workspace, 'Model', group)
        scene = groups[group]
        scene_part, props = item(scene, part.get('class', 'Part'), part['name'])
        prop(props, 'bool', 'Anchored', 'true')
        prop(props, 'bool', 'CanCollide', str(part.get('collide', True)).lower())
        prop(props, 'bool', 'CanTouch', 'false')
        prop(props, 'bool', 'CanQuery', str(part.get('query', True)).lower())
        if part.get('shape'):
            prop(props, 'token', 'shape', {'Ball': 0, 'Block': 1, 'Cylinder': 2}[part['shape']])
        vector(props, 'size', part['size'])
        cf = ET.SubElement(props, 'CoordinateFrame', name='CFrame')
        for key, value in zip(('X', 'Y', 'Z'), part['position']):
            ET.SubElement(cf, key).text = str(value)
        rotation = world_art.rotation_matrix(part.get('rotation'))
        for row in range(3):
            for col in range(3):
                ET.SubElement(cf, f'R{row}{col}').text = str(rotation[row][col])
        prop(props, 'token', 'Material', {'SmoothPlastic': 272, 'Neon': 288,
                                        'Wood': 512, 'Metal': 1088}.get(part.get('material'), 272))
        red, green, blue = part['color']
        prop(props, 'Color3uint8', 'Color3uint8', (red << 16) | (green << 8) | blue)
        prop(props, 'token', 'TopSurface', 0)
        prop(props, 'token', 'BottomSurface', 0)
        if part.get('label'):
            board, board_props = item(scene_part, 'BillboardGui', 'StationLabel')
            prop(board_props, 'float', 'MaxDistance', 45)
            prop(board_props, 'bool', 'AlwaysOnTop', 'false')
            size = ET.SubElement(board_props, 'UDim2', name='Size')
            for key, value in [('XS', 0), ('XO', 180), ('YS', 0), ('YO', 48)]:
                ET.SubElement(size, key).text = str(value)
            vector(board_props, 'StudsOffset', [0, 1.5, 0])
            _, label_props = item(board, 'TextLabel', 'Text')
            size = ET.SubElement(label_props, 'UDim2', name='Size')
            for key, value in [('XS', 1), ('XO', 0), ('YS', 1), ('YO', 0)]:
                ET.SubElement(size, key).text = str(value)
            prop(label_props, 'string', 'Text', part['label'])
            prop(label_props, 'float', 'TextSize', 14)
            prop(label_props, 'bool', 'TextWrapped', 'true')
            prop(label_props, 'float', 'BackgroundTransparency', 0.15)
            for name, rgb in [('TextColor3', [1, 1, 0.9]), ('BackgroundColor3', [0.1, 0.2, 0.21])]:
                color_el = ET.SubElement(label_props, 'Color3', name=name)
                for key, value in zip(('R', 'G', 'B'), rgb):
                    ET.SubElement(color_el, key).text = str(value)
        if part.get('class') == 'SpawnLocation':
            prop(props, 'bool', 'Neutral', 'true')
            prop(props, 'float', 'Duration', 0)

    replicated, _ = item(root, 'ReplicatedStorage', 'ReplicatedStorage')
    shared, _ = item(replicated, 'Folder', 'Shared')
    server, _ = item(root, 'ServerScriptService', 'ServerScriptService')
    starter, _ = item(root, 'StarterPlayer', 'StarterPlayer')
    client, _ = item(starter, 'StarterPlayerScripts', 'StarterPlayerScripts')
    for folder, destination, cls in [('shared', shared, 'ModuleScript'),
                                      ('server', server, 'Script'),
                                      ('client', client, 'LocalScript')]:
        for path in sorted((ROOT / 'src' / folder).glob('*.luau')):
            is_entry = path.stem == 'Bootstrap'
            _, props = item(destination, cls if is_entry or folder == 'shared' else 'ModuleScript', path.stem)
            prop(props, 'ProtectedString', 'Source', path.read_text(encoding='utf-8'))
    OUTPUT.parent.mkdir(exist_ok=True)
    ET.indent(root)
    OUTPUT.write_bytes(ET.tostring(root, encoding='utf-8', xml_declaration=True))
    return OUTPUT


if __name__ == '__main__':
    print(build())
