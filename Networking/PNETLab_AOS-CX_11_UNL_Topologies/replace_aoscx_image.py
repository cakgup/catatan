#!/usr/bin/env python3
"""
Replace the AOS-CX template/image attributes in every .unl file.

Example:
  python replace_aoscx_image.py --image arubacx-10.13.1000
  python replace_aoscx_image.py --template arubacx --image arubacx-10.13.1000
"""
from pathlib import Path
import argparse
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument("--folder", default=".", help="Folder containing .unl files")
parser.add_argument("--template", default="arubacx")
parser.add_argument("--image", required=True)
args = parser.parse_args()

folder = Path(args.folder)
changed = 0
for path in folder.glob("*.unl"):
    tree = ET.parse(path)
    root = tree.getroot()
    file_changed = False
    for node in root.findall("./topology/nodes/node"):
        if node.get("type") == "qemu":
            node.set("template", args.template)
            node.set("image", args.image)
            file_changed = True
    if file_changed:
        tree.write(path, encoding="UTF-8", xml_declaration=True)
        changed += 1
        print(f"Updated: {path.name}")

print(f"Completed. Updated {changed} file(s).")
