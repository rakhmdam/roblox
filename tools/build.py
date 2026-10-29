"""Build a local Test place using only Python's standard library.

Art source: assets/shore.json. Generated output: places/SlimeSalvage-Test.rbxlx.
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
        _, props = item(scene, part.get('class', 'Part'), part['name'])
        prop(props, 'bool', 'Anchored', 'true')
        prop(props, 'bool', 'CanCollide', str(part.get('collide', True)).lower())
        vector(props, 'size', part['size'])
        cf = ET.SubElement(props, 'CoordinateFrame', name='CFrame')
        for key, value in zip(('X', 'Y', 'Z'), part['position']):
            ET.SubElement(cf, key).text = str(value)
        for row in range(3):
            for col in range(3):
                ET.SubElement(cf, f'R{row}{col}').text = str(int(row == col))
        red, green, blue = part['color']
        prop(props, 'Color3uint8', 'Color3uint8', (red << 16) | (green << 8) | blue)
        prop(props, 'token', 'TopSurface', 0)
        prop(props, 'token', 'BottomSurface', 0)
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
