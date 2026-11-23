"""Repackage the user-provided Windows release with the browser controls.
Usage: python tools/build.py PATH/PCForge-0.11-Windows-x64.zip [PATH/web_nothreads_release.zip]
Omit the template to rebuild just the game, retaining the checked-in engine.
Use the official Godot 4.7.2 single-thread release template.
"""
from pathlib import Path
from hashlib import md5
from zipfile import ZipFile
from struct import unpack_from, pack
import json
import re
import gzip
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "dist"
OUT.mkdir(exist_ok=True)
with ZipFile(sys.argv[1]) as z:
    exe = z.read("PCForge.exe")
    for name in ["Godot-COPYRIGHT.txt", "Godot-LICENSE.txt"]:
        (OUT / name).write_bytes(z.read(name))
size, = unpack_from("<Q", exe, len(exe) - 12)
game = exe[-size - 12:-12]
if game[:4] != b"GDPC" or unpack_from("<4I", game, 4) != (4, 4, 7, 2):
    raise ValueError("Expected the unencrypted PCForge 0.11 Godot 4.7.2 pack")
base, index = unpack_from("<QQ", game, 24)
count, = unpack_from("<I", game, index)
cursor = index + 4
files = {}
for _ in range(count):
    n, = unpack_from("<I", game, cursor)
    name = game[cursor+4:cursor+4+n].rstrip(b"\0").decode()
    cursor += 4+n
    pos, length = unpack_from("<QQ", game, cursor)
    data = game[base+pos:base+pos+length]
    if md5(data).digest() != game[cursor+16:cursor+32]:
        raise ValueError(f"Corrupt game resource {name}")
    files[name] = data
    cursor += 36

# Release templates reject scene paths passed as command-line overrides.
# Store the adapter scene as the main scene in the web pack instead.
settings = files["project.binary"]
if settings[:4] != b"ECFG":
    raise ValueError("Invalid Godot project settings header")
entry_count, = unpack_from("<I", settings, 4)
cursor = 8
web_settings = bytearray(settings[:cursor])
scene_found = False
for _ in range(entry_count):
    name_size, = unpack_from("<I", settings, cursor)
    name_end = cursor + 4 + name_size
    name = settings[cursor + 4:name_end]
    value_size, = unpack_from("<I", settings, name_end)
    value_end = name_end + 4 + value_size
    value = settings[name_end + 4:value_end]
    if name == b"application/run/main_scene":
        variant_type, = unpack_from("<I", value)
        if variant_type != 4:
            raise ValueError("Godot main scene setting must be a String")
        scene_path = b"res://Web.tscn"
        value = pack("<II", variant_type, len(scene_path)) + scene_path
        value += b"\0" * (-len(scene_path) % 4)
        scene_found = True
    web_settings += settings[cursor:name_end] + pack("<I", len(value)) + value
    cursor = value_end
if not scene_found or cursor != len(settings):
    raise ValueError("Could not set the main scene in the web project settings")
files["project.binary"] = web_settings

# Merge the web expansion into the original catalog so saves, the shop and
# compatibility checks all resolve the same stable hardware identifiers.
catalog_dir = ROOT / "port" / "data"
parts = json.loads((catalog_dir / "used_parts.json").read_bytes())
offers = json.loads((catalog_dir / "used_offers.json").read_bytes())
if parts.keys() != offers.keys() or len(parts) < 200:
    raise ValueError("Each added model must have its own used offer")
for item_id, part in parts.items():
    if part.get("catalog_only") or offers[item_id].get("used", {}).get("cents", 0) <= 0:
        raise ValueError(f"Unpurchasable or display-only expansion part: {item_id}")

for target, extra in [("data/parts.json", parts), ("data/market_cn.json", offers)]:
    original = json.loads(files[target])
    overlap = original.keys() & extra.keys()
    if overlap:
        raise ValueError(f"Existing catalog IDs in {target}: {sorted(overlap)}")
    original.update(extra)
    files[target] = json.dumps(original, ensure_ascii=False, separators=(",", ":")).encode()

index_html = OUT / "index.html"
catalog_count = len(json.loads(files["data/parts.json"]))
page, matches = re.subn(r'(<strong id="catalogCount">)\d+(</strong>)',
                        lambda m: f"{m[1]}{catalog_count}{m[2]}",
                        index_html.read_text())
if matches != 1:
    raise ValueError("Missing catalog count in the web menu")
index_html.write_text(page)

license_file = catalog_dir / "pc-part-dataset-LICENSE.txt"
files["data/" + license_file.name] = license_file.read_bytes()

for resource in (ROOT / "port").iterdir():
    if resource.suffix in {".tscn", ".gd"}:
        files[resource.name] = resource.read_bytes()
body = bytearray()
directory = bytearray(pack("<I", len(files)))
for path, data in sorted(files.items()):
    name = path.encode()
    name += b"\0" * (-len(name) % 4)
    directory += pack("<I", len(name)) + name
    directory += pack("<QQ", len(body), len(data)) + md5(data).digest() + pack("<I", 0)
    body += data + b"\0" * (-len(data) % 16)
header = bytearray(game[:base])
header[32:40] = pack("<Q", base+len(body))
(OUT / "game.pck").write_bytes(header+body+directory)
if len(sys.argv) == 2:
    sys.exit(0)

with ZipFile(sys.argv[2]) as z:
    js = z.read("godot.js").decode()
    needle = 'preloader.loadPromise(`${loadPath}.wasm`, size, true)'
    if js.count(needle) != 1:
        raise ValueError("Unexpected Godot Web template")
    # Static hosts don't need a 39 MB file or special Content-Encoding headers.
    js = js.replace(needle, 'window.loadForgeWasm(loadPath)')
    (OUT / "engine.js").write_text(js)
    (OUT / "engine.bin").write_bytes(gzip.compress(z.read("godot.wasm"), compresslevel=9, mtime=0))
    for suffix in [".audio.worklet.js", ".audio.position.worklet.js"]:
        (OUT / ("engine"+suffix)).write_bytes(z.read("godot"+suffix))
