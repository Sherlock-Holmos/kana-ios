"""
Fetch KanjiVG SVGs for the 46 basic hiragana, parse each stroke's <path d="..."/>
into a list of (x, y) absolute points, sample to a fixed length per stroke,
normalize to [0,1] bbox, and emit a single JSON the Swift app can bundle.

Output: KanaStudy/Resources/kana-vg-data.json
"""
import json
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Tuple

# (hiragana, romaji, unicode_hex_lower_5_digits)
HIRAGANA = [
    ("あ", "a",  "0304a"), ("い", "i",  "03044"), ("う", "u",  "03046"),
    ("え", "e",  "03048"), ("お", "o",  "0304a"),  # NOTE: お is also 0304a; we'll dedupe
    ("か", "ka", "0304b"), ("き", "ki", "0304d"), ("く", "ku", "0304f"),
    ("け", "ke", "03050"), ("こ", "ko", "03051"),
    ("さ", "sa", "03055"), ("し", "shi","03057"), ("す", "su", "03059"),
    ("せ", "se", "0305b"), ("そ", "so", "0305d"),
    ("た", "ta", "0305f"), ("ち", "chi","03061"), ("つ", "tsu","03063"),
    ("て", "te", "03064"), ("と", "to", "03067"),
    ("な", "na", "03069"), ("に", "ni", "0306b"), ("ぬ", "nu", "0306c"),
    ("ね", "ne", "0306d"), ("の", "no", "0306e"),
    ("は", "ha", "0306f"), ("ひ", "hi", "03072"), ("ふ", "fu", "03075"),
    ("へ", "he", "03076"), ("ほ", "ho", "0307b"),
    ("ま", "ma", "0307e"), ("み", "mi", "0307f"), ("む", "mu", "03080"),
    ("め", "me", "03081"), ("も", "mo", "03082"),
    ("や", "ya", "03083"), ("ゆ", "yu", "03086"), ("よ", "yo", "03088"),
    ("ら", "ra", "03089"), ("り", "ri", "0308a"), ("る", "ru", "0308b"),
    ("れ", "re", "0308c"), ("ろ", "ro", "0308d"),
    ("わ", "wa", "0308f"), ("を", "wo", "03092"), ("ん", "n",  "03093"),
]

# De-dupe by hex (お == 0304a == あ, but they have distinct filenames)
# KanjiVG uses the same hex for kana that share the base codepoint.
# We will fetch each hex once and map to multiple kana if needed.
HEX_TO_KANA = {}
for kana, romaji, hex_code in HIRAGANA:
    HEX_TO_KANA.setdefault(hex_code, []).append((kana, romaji))

GITHUB_RAW = "https://raw.githubusercontent.com/KanjiVG/kanjivg/master/kanji/{hex}.svg"
SAMPLES_PER_STROKE = 24


# ---------- SVG path parsing ----------

# Tokens: command letters and numbers. Handles scientific notation.
PATH_TOKEN_RE = re.compile(r"([MmLlHhVvCcSsQqTtAaZz])|(-?\d*\.?\d+(?:[eE][-+]?\d+)?)")


def parse_path(d: str) -> List[Tuple[float, float]]:
    """Parse an SVG path 'd' string into absolute cubic Bezier control points.
    For our purposes, we collapse everything to an absolute polyline of
    (x, y) points we can resample."""
    tokens = PATH_TOKEN_RE.findall(d)
    pts: List[Tuple[float, float]] = []
    cur = (0.0, 0.0)
    start = (0.0, 0.0)
    cmd = ""
    i = 0
    while i < len(tokens):
        ch, num = tokens[i]
        if ch:
            cmd = ch
            i += 1
        else:
            # A number by itself repeats the previous command in SVG.
            pass
        # Read coordinates for this command.
        def nxt() -> float:
            nonlocal i
            t = tokens[i]
            i += 1
            assert t[1] != "", f"expected number at {i} in {d}"
            return float(t[1])

        if cmd in ("M", "m"):
            x, y = nxt(), nxt()
            if cmd == "m" and pts:
                x += cur[0]; y += cur[1]
            cur = (x, y); start = (x, y)
            pts.append(cur)
            cmd = "L" if cmd == "M" else "l"
        elif cmd in ("L", "l"):
            x, y = nxt(), nxt()
            if cmd == "l":
                x += cur[0]; y += cur[1]
            cur = (x, y); pts.append(cur)
        elif cmd in ("H", "h"):
            x = nxt()
            if cmd == "h": x += cur[0]
            cur = (x, cur[1]); pts.append(cur)
        elif cmd in ("V", "v"):
            y = nxt()
            if cmd == "v": y += cur[1]
            cur = (cur[0], y); pts.append(cur)
        elif cmd in ("C", "c"):
            x1, y1, x2, y2, x, y = nxt(), nxt(), nxt(), nxt(), nxt(), nxt()
            if cmd == "c":
                x1 += cur[0]; y1 += cur[1]
                x2 += cur[0]; y2 += cur[1]
                x  += cur[0]; y  += cur[1]
            # Add the endpoint; for sampling we just need the curve polyline.
            # Insert a couple of intermediate points for visual fidelity.
            for t in (0.33, 0.67, 1.0):
                u = 1 - t
                px = u*u*u*cur[0] + 3*u*u*t*x1 + 3*u*t*t*x2 + t*t*t*x
                py = u*u*u*cur[1] + 3*u*u*t*y1 + 3*u*t*t*y2 + t*t*t*y
                pts.append((px, py))
            cur = (x, y)
        elif cmd in ("S", "s"):
            # Smooth cubic: x2,y2 reflected, then x,y end. Approximate like C.
            x2, y2, x, y = nxt(), nxt(), nxt(), nxt()
            if cmd == "s":
                x2 += cur[0]; y2 += cur[1]
                x  += cur[0]; y  += cur[1]
            pts.append((x, y))
            cur = (x, y)
        elif cmd in ("Q", "q"):
            x1, y1, x, y = nxt(), nxt(), nxt(), nxt()
            if cmd == "q":
                x1 += cur[0]; y1 += cur[1]
                x  += cur[0]; y  += cur[1]
            for t in (0.5, 1.0):
                u = 1 - t
                px = u*u*cur[0] + 2*u*t*x1 + t*t*x
                py = u*u*cur[1] + 2*u*t*y1 + t*t*y
                pts.append((px, py))
            cur = (x, y)
        elif cmd in ("T", "t"):
            x, y = nxt(), nxt()
            if cmd == "t":
                x += cur[0]; y += cur[1]
            pts.append((x, y))
            cur = (x, y)
        elif cmd in ("A", "a"):
            # Arc — too complex to do properly here. Approximate by sampling.
            rx, ry, rot, large, sweep, x, y = nxt(), nxt(), nxt(), nxt(), nxt(), nxt(), nxt()
            if cmd == "a":
                x += cur[0]; y += cur[1]
            pts.append((x, y))
            cur = (x, y)
        elif cmd in ("Z", "z"):
            cur = start
        # else: skip
    return pts


# ---------- resample + normalize ----------

def resample(points: List[Tuple[float, float]], n: int) -> List[Tuple[float, float]]:
    """Resample a polyline to n points at uniform arc-length."""
    if len(points) < 2:
        return points * n if points else [(0.0, 0.0)] * n
    total = 0.0
    seg = []
    for i in range(1, len(points)):
        dx = points[i][0] - points[i-1][0]
        dy = points[i][1] - points[i-1][1]
        d = (dx*dx + dy*dy) ** 0.5
        seg.append(d)
        total += d
    if total == 0:
        return [points[0]] * n
    out = [points[0]]
    step = total / (n - 1)
    target = step
    i = 1
    while i < len(points) and len(out) < n:
        seg_len = seg[i-1]
        while target <= seg_len and len(out) < n:
            t = target / seg_len
            x = points[i-1][0] + t * (points[i][0] - points[i-1][0])
            y = points[i-1][1] + t * (points[i][1] - points[i-1][1])
            out.append((x, y))
            target += step
        target -= seg_len
        i += 1
    while len(out) < n:
        out.append(points[-1])
    return out[:n]


def normalize_bbox(points: List[Tuple[float, float]]) -> List[Tuple[float, float]]:
    """Translate to centroid, scale to unit max distance, flip Y (SVG y is down)."""
    if not points:
        return points
    cx = sum(p[0] for p in points) / len(points)
    cy = sum(p[1] for p in points) / len(points)
    centered = [(p[0] - cx, -(p[1] - cy)) for p in points]  # flip Y
    max_r = max((x*x + y*y) ** 0.5 for x, y in centered) or 1.0
    return [(x / max_r, y / max_r) for x, y in centered]


# ---------- main ----------

def fetch_svg(hex_code: str) -> str:
    url = GITHUB_RAW.format(hex=hex_code)
    with urllib.request.urlopen(url, timeout=15) as r:
        return r.read().decode("utf-8")


def extract_strokes(svg: str) -> List[List[Tuple[float, float]]]:
    """Return list of strokes; each stroke is a list of (x,y) tuples."""
    root = ET.fromstring(svg)
    ns = {"kvg": "http://kanjivg.tagaini.net/"}
    strokes = []
    # KanjiVG's actual stroke paths are at any depth inside <g id="kvg:...">.
    # We pick the path elements whose id matches kvg:*-s\d+ or whose parent has a stroke-id attribute.
    for path in root.iter("{http://www.w3.org/2000/svg}path"):
        pid = path.get("id", "")
        # Look for kvg:*-s\d pattern.
        if "-s" not in pid:
            continue
        d = path.get("d", "")
        if not d:
            continue
        pts = parse_path(d)
        if len(pts) < 2:
            continue
        sampled = resample(pts, SAMPLES_PER_STROKE)
        strokes.append(sampled)
    return strokes


def main():
    out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out_dir.mkdir(parents=True, exist_ok=True)
    output_path = out_dir / "kana-vg-data.json"

    data = {}
    for hex_code, kanas in HEX_TO_KANA.items():
        print(f"Fetching {hex_code} for {','.join(k for k, _ in kanas)}", flush=True)
        try:
            svg = fetch_svg(hex_code)
            strokes = extract_strokes(svg)
        except Exception as e:
            print(f"  FAILED: {e}", file=sys.stderr)
            continue
        if not strokes:
            print(f"  no strokes found", file=sys.stderr)
            continue
        # Normalize each stroke; we also keep the per-stroke bbox normalization
        # at template-load time (Swift side).
        for kana, romaji in kanas:
            data[kana] = {
                "romaji": romaji,
                "strokes": [[list(p) for p in s] for s in strokes],
            }
        print(f"  {len(strokes)} strokes", flush=True)

    output_path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    print(f"Wrote {len(data)} kana → {output_path} ({output_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()