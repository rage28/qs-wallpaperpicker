#!/usr/bin/env python3
"""The colour scheme Noctalia would make from each wallpaper, for the
wallpaper picker's swatch cards (services/WallpaperSwatches.qml).

    wallpaper-palettes.py --scheme SCHEME DIR NAME...

Noctalia's theme CLI runs without applying anything, using the same scheme as
the shell, so a card shows the palette its wallpaper will give. Prints one JSON
line per wallpaper as soon as it's read:

    {"n": name, "m": mtime, "s": bytes, "w": width, "h": height,
     "g": scheme, "c": {role: "#rrggbb", ...}}

with "e": 1 instead of "c" when Noctalia can't read the image. A line on
stdin of tab-separated names moves those names to the front of the queue, in
that order (the picker sends the cards in view).
"""

import json
import os
import shutil
import struct
import subprocess
import sys
import threading
from collections import deque

WORKERS = 3

ROLES = (
    "background", "surface", "surface_container_lowest", "surface_container_low",
    "surface_container", "surface_container_high", "surface_container_highest",
    "on_surface", "on_surface_variant", "outline", "outline_variant",
    "primary", "on_primary", "primary_container", "on_primary_container",
    "secondary", "on_secondary", "secondary_container", "on_secondary_container",
    "tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container",
    "error", "source_color",
)


def jpeg_size(f):
    f.seek(2)
    while True:
        byte = f.read(1)
        if not byte:
            return 0, 0
        if byte != b"\xff":
            continue
        marker = f.read(1)
        while marker == b"\xff":
            marker = f.read(1)
        if not marker:
            return 0, 0
        m = marker[0]
        if m in (0xD9, 0xDA):
            return 0, 0
        if m == 0x01 or 0xD0 <= m <= 0xD7:
            continue
        length = struct.unpack(">H", f.read(2))[0]
        if 0xC0 <= m <= 0xCF and m not in (0xC4, 0xC8, 0xCC):
            f.read(1)
            h, w = struct.unpack(">HH", f.read(4))
            return w, h
        f.seek(length - 2, 1)


def image_size(path):
    """(width, height) from the file's header, or (0, 0)."""
    try:
        with open(path, "rb") as f:
            head = f.read(30)
            if head[:8] == b"\x89PNG\r\n\x1a\n":
                return struct.unpack(">II", head[16:24])
            if head[:6] in (b"GIF87a", b"GIF89a"):
                return struct.unpack("<HH", head[6:10])
            if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
                kind = head[12:16]
                if kind == b"VP8 ":
                    w, h = struct.unpack("<HH", head[26:30])
                    return w & 0x3FFF, h & 0x3FFF
                if kind == b"VP8L":
                    bits = int.from_bytes(head[21:25], "little")
                    return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
                if kind == b"VP8X":
                    return int.from_bytes(head[24:27], "little") + 1, int.from_bytes(head[27:30], "little") + 1
            if head[:2] == b"\xff\xd8":
                return jpeg_size(f)
    except (OSError, struct.error):
        pass
    return 0, 0


def palette(path, scheme):
    try:
        out = subprocess.run(
            ["noctalia", "theme", path, "--scheme", scheme, "--dark"],
            capture_output=True, text=True, timeout=90,
        )
        if out.returncode != 0:
            return None
        colors = json.loads(out.stdout)
        return {role: colors[role] for role in ROLES if isinstance(colors.get(role), str)}
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        return None


def main():
    if len(sys.argv) < 4 or sys.argv[1] != "--scheme":
        sys.exit("usage: wallpaper-palettes.py --scheme SCHEME DIR NAME...")
    scheme = sys.argv[2]
    folder = sys.argv[3]
    queue = deque(dict.fromkeys(sys.argv[4:]))
    if shutil.which("noctalia") is None:
        print("wallpaper-palettes: noctalia is not installed", file=sys.stderr)
        return 127
    lock = threading.Lock()
    out = threading.Lock()

    def listen():
        for line in sys.stdin:
            names = [n for n in line.rstrip("\n").split("\t") if n]
            with lock:
                for name in reversed(names):
                    try:
                        queue.remove(name)
                    except ValueError:
                        continue
                    queue.appendleft(name)

    def work():
        while True:
            with lock:
                if not queue:
                    return
                name = queue.popleft()
            path = os.path.join(folder, name)
            try:
                st = os.stat(path)
            except OSError:
                continue
            record = {"n": name, "m": int(st.st_mtime), "s": st.st_size, "g": scheme}
            record["w"], record["h"] = image_size(path)
            colors = palette(path, scheme)
            if colors:
                record["c"] = colors
            else:
                record["e"] = 1
            with out:
                print(json.dumps(record, separators=(",", ":")), flush=True)

    threading.Thread(target=listen, daemon=True).start()
    workers = [threading.Thread(target=work) for _ in range(WORKERS)]
    for t in workers:
        t.start()
    for t in workers:
        t.join()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
