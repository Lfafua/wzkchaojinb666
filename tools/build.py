"""Repackage the user-provided Windows release with the browser controls.
Usage: python tools/build.py PATH/PCForge-0.11-Windows-x64.zip PATH/web_nothreads_release.zip
Use the official Godot 4.7.2 single-thread release template.
"""
from pathlib import Path
from hashlib import md5
from zipfile import ZipFile
from struct import unpack_from, pack
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
