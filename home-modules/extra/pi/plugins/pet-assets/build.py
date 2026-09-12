# Build the pi pet frame assets from pi-dsh-pet's transparent WebM animations.
#
# Per animation:
#   1. Detect the character's bounding box: key the black background to alpha
#      (colorkey), extract the alpha channel, and run cropdetect over the whole
#      clip (reset=0 accumulates the union box across all frames, so animation
#      extremes like stretches and speech bubbles stay inside).
#   2. Convert: fps resample -> crop to the box -> scale to a uniform height
#      (TARGET_H, aspect preserved) -> colorkey to transparency -> quantize to
#      a per-animation palette (raw RGBA frames are ~4x larger; the palette
#      pass keeps a full animation's transmit payload at ~0.5-1 MB, which
#      matters because every animation switch retransmits over the kitty
#      graphics protocol).
#   3. Write palette PNG frames f0001.png.. plus a manifest entry.
#
# Cropping matters beyond size: the pi pet overlay renders as a fixed-size
# band that erases the transcript text underneath it (pi's overlay compositing
# pads with spaces), so the band must hug the character — uncropped frames
# would leave a large empty "hole" next to the pet.
#
# Usage: build.py <src> <out> <fps>
import json
import os
import re
import struct
import subprocess
import sys
import zlib

src, out, fps = sys.argv[1], sys.argv[2], int(sys.argv[3])
TARGET_H = 320  # output pixel height (uniform character size across animations)
MAX_FRAMES = 160
KEY = "colorkey=0x000000:0.08:0.04"


def patch_transparent_rgb(path, rgb=(25, 25, 25)):
    """Recolor the transparent palette entry of an indexed PNG in place.

    ffmpeg's paletteuse reserves pure green (0,255,0) as the transparency
    marker (tRNS alpha=0 makes it invisible on disk). But kitty scales images
    on the GPU to fit the placement cell grid, and that downscale blends RGB
    without alpha weighting — the invisible green bleeds into the character's
    edge pixels as a green fringe. Giving the entry a dark neutral RGB makes
    any bleed indistinguishable from the terminal background.
    """
    with open(path, "rb") as fh:
        d = bytearray(fh.read())
    pos = 8
    plte_off = None
    trns_idx = None
    while pos < len(d):
        ln = int.from_bytes(d[pos : pos + 4], "big")
        typ = d[pos + 4 : pos + 8]
        if typ == b"PLTE":
            plte_off = pos
        elif typ == b"tRNS" and trns_idx is None:
            for i in range(ln):
                if d[pos + 8 + i] == 0:
                    trns_idx = i
                    break
        pos += 12 + ln
    if plte_off is None or trns_idx is None:
        return
    o = plte_off + 8 + trns_idx * 3
    d[o : o + 3] = bytes(rgb)
    # PLTE chunk CRC covers type + data.
    crc = zlib.crc32(d[plte_off + 4 : plte_off + 8 + 768]) & 0xFFFFFFFF
    struct.pack_into(">I", d, plte_off + 8 + 768, crc)
    with open(path, "wb") as fh:
        fh.write(d)


def run(args):
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"command failed: {' '.join(args)}\n{p.stderr[-2000:]}")
    return p


def bbox(webm):
    """Union crop box (w h x y) of the character across all frames."""
    p = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", webm,
         "-vf", f"{KEY},format=rgba,alphaextract,cropdetect=limit=24:round=2:reset=0",
         "-f", "null", "-"],
        capture_output=True, text=True,
    )
    crops = re.findall(r"crop=(\d+):(\d+):(\d+):(\d+)", p.stderr)
    if not crops:
        return None
    return tuple(int(v) for v in crops[-1])


manifest = {}
thumbs = os.path.join(src, "assets", "thumb")
for fname in sorted(os.listdir(thumbs)):
    if not fname.endswith(".webm"):
        continue
    name = fname[:-5]
    webm = os.path.join(thumbs, fname)
    d = os.path.join(out, name)
    os.makedirs(d, exist_ok=True)

    box = bbox(webm)
    if box and box[0] > 0 and box[1] > 0:
        w, h, x, y = box
    else:
        w, h, x, y = 640, 360, 0, 0
    pre = f"fps={fps},crop={w}:{h}:{x}:{y},scale=-2:{TARGET_H}:flags=lanczos"

    run(["ffmpeg", "-hide_banner", "-v", "error", "-i", webm,
         "-vf", f"{pre},{KEY},palettegen=max_colors=255:reserve_transparent=1",
         "-update", "1", "-frames:v", "1", os.path.join(d, "palette.png"), "-y"])

    run(["ffmpeg", "-hide_banner", "-v", "error", "-i", webm, "-i", os.path.join(d, "palette.png"),
         "-filter_complex",
         f"[0:v]{pre},{KEY},format=rgba[f];[f][1:v]paletteuse=dither=none:alpha_threshold=128",
         "-frames:v", str(MAX_FRAMES), os.path.join(d, "f%04d.png"), "-y"])
    os.remove(os.path.join(d, "palette.png"))

    frames = len([f for f in os.listdir(d) if f.endswith(".png")])
    if frames == 0:
        os.rmdir(d)
        continue
    for f in os.listdir(d):
        if f.endswith(".png"):
            patch_transparent_rgb(os.path.join(d, f))
    # scale=-2:TARGET_H forces even height TARGET_H; width is derived even.
    out_w = (w * TARGET_H + h // 2) // h
    out_w += out_w % 2
    manifest[name] = {"frames": frames, "fps": fps, "width": out_w, "height": TARGET_H}

with open(os.path.join(out, "manifest.json"), "w") as fh:
    json.dump(manifest, fh, ensure_ascii=False, indent=1, sort_keys=True)
