"""Package the built place for import into an existing Studio Test session."""
import copy
import hashlib
import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'places/SlimeSalvage-Import.rbxmx'


def build():
    source = ROOT / 'places/SlimeSalvage-Test.rbxlx'
    place = ET.parse(source).getroot()
    root = ET.Element('roblox', version='4')
    for value in ('null', 'nil'):
        ET.SubElement(root, 'External').text = value

    def item(parent, cls, name):
        obj = ET.SubElement(parent, 'Item', {'class': cls, 'referent': 'DEPLOY_' + name})
        props = ET.SubElement(obj, 'Properties')
        ET.SubElement(props, 'string', name='Name').text = name
        return obj

    def service(name):
        return place.find(f'Item[@class="{name}"]')

    stage = item(root, 'Folder', 'SlimeSalvageImport')
    world = item(stage, 'Folder', 'World')
    for obj in service('Workspace').findall('Item'):
        world.append(copy.deepcopy(obj))
    stage.append(copy.deepcopy(service('ReplicatedStorage').find('Item')))
    for name, original in [('Server', service('ServerScriptService')),
                           ('Client', service('StarterPlayer').find('Item')),
                           ('Effects', service('Lighting'))]:
        folder = item(stage, 'Folder', name)
        for obj in original.findall('Item'):
            folder.append(copy.deepcopy(obj))
    for obj in stage.findall('.//Item'):
        if obj.get('class') in ('Script', 'LocalScript'):
            ET.SubElement(obj.find('Properties'), 'bool', name='Disabled').text = 'true'

    lighting = {}
    for prop in service('Lighting').find('Properties'):
        name = prop.get('name')
        if name in ('Name', 'Technology'):
            continue
        if prop.tag == 'Color3':
            value = [float(prop.findtext(axis)) for axis in ('R', 'G', 'B')]
        elif prop.tag == 'bool':
            value = prop.text == 'true'
        else:
            value = float(prop.text)
        lighting[name] = value
    shore = next(obj for obj in service('Workspace').findall('Item')
                 if obj.findtext('Properties/string[@name="Name"]') == 'shore')
    anchor = next(obj for obj in shore.findall('Item')
                  if obj.findtext('Properties/string[@name="Name"]') == 'Garden')
    anchor_frame = anchor.find('Properties/CoordinateFrame[@name="CFrame"]')
    anchor_values = [float(anchor_frame.findtext(key)) for key in
                     ('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22')]
    settings = {'environment': 'Test', 'monetizationEnabled': False,
                'worldAnchor': anchor_values,
                'sourceHash': hashlib.sha256(source.read_bytes()).hexdigest(),
                'lighting': lighting, 'workspace': {'StreamingEnabled': True, 'FallenPartsDestroyHeight': -80}}
    config = item(stage, 'ModuleScript', 'Settings')
    ET.SubElement(config.find('Properties'), 'ProtectedString', name='Source').text = (
        'return game:GetService("HttpService"):JSONDecode([==[' + json.dumps(settings) + ']==])')
    installer = item(stage, 'ModuleScript', 'Installer')
    ET.SubElement(installer.find('Properties'), 'ProtectedString', name='Source').text = (
        ROOT / 'tools/studio_import.luau').read_text(encoding='utf-8')
    ET.indent(root)
    OUTPUT.write_bytes(ET.tostring(root, encoding='utf-8', xml_declaration=True))
    return OUTPUT


if __name__ == '__main__':
    print(build())
