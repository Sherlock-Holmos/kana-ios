"""
Same as generate_kana_vg.py but fetches all 46 SVG files concurrently (thread
pool) — much faster than serial when network is flaky.
"""
import json
import sys
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import List, Tuple
import re

HIRAGANA = [
    ("あ", "a",  "0304a"), ("い", "i",  "03044"), ("う", "u",  "03046"),
    ("え", "e",  "03048"), ("お", "o",  "0304a"),
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

HEX_TO_KANA = {}
for kana, romaji, hex_code in HIRAGANA:
    HEX_TO_KANA.setdefault(hex_code, []).append((kana, romaji))

GITHUB_RAW = "https://raw.githubusercontent.com/KanjiVG/kanjivg/master/kanji/{hex}.svg"
SAMPLES_PER_STROKE = 24

PATH_TOKEN_RE = re.compile(r"([MmLlHhVvCcSsQqTtAaZz])|(-?\d*\.?\d+(?:[eE][-+]?\d+)?)")


def parse_path(d: str) -> List[Tuple[float, float]]:
    tokens = PATH_TOKEN_RE.findall(d)
    pts = []
    cur = (0.0, 0.0); start = (0.0, 0.0); cmd = ""; i = 0
    while i < len(tokens):
        ch, num = tokens[i]
        if ch:
            cmd = ch; i += 1
        def nxt():
            nonlocal i
            t = tokens[i]; i += 1
            return float(t[1])
        if cmd in ("M", "m"):
            x, y = nxt(), nxt()
            if cmd == "m" and pts: x += cur[0]; y += cur[1]
            cur = (x, y); start = cur; pts.append(cur); cmd = "L" if cmd == "M" else "l"
        elif cmd in ("L", "l"):
            x, y = nxt(), nxt()
            if cmd == "l": x += cur[0]; y += cur[1]
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
                x1 += cur[0]; y1 += cur[1]; x2 += cur[0]; y2 += cur[1]
                x  += cur[0]; y  += cur[1]
            for t in (0.33, 0.67, 1.0):
                u = 1 - t
                pts.append((u*u*u*cur[0] + 3*u*u*t*x1 + 3*u*t*t*x2 + t*t*t*x,
                            u*u*u*cur[1] + 3*u*u*t*y1 + 3*u*t*t*y2 + t*t*t*y))
            cur = (x, y)
        elif cmd in ("S", "s"):
            x2, y2, x, y = nxt(), nxt(), nxt(), nxt()
            if cmd == "s": x2 += cur[0]; y2 += cur[1]; x += cur[0]; y += cur[1]
            pts.append((x, y)); cur = (x, y)
        elif cmd in ("Q", "q"):
            x1, y1, x, y = nxt(), nxt(), nxt(), nxt()
            if cmd == "q": x1 += cur[0]; y1 += cur[1]; x += cur[0]; y += cur[1]
            for t in (0.5, 1.0):
                u = 1 - t
                pts.append((u*u*cur[0] + 2*u*t*x1 + t*t*x, u*u*cur[1] + 2*u*t*y1 + t*t*y))
            cur = (x, y)
        elif cmd in ("T", "t"):
            x, y = nxt(), nxt()
            if cmd == "t": x += cur[0]; y += cur[1]
            pts.append((x, y)); cur = (x, y)
        elif cmd in ("A", "a"):
            rx, ry, rot, large, sweep, x, y = nxt(), nxt(), nxt(), nxt(), nxt(), nxt(), nxt()
            if cmd == "a": x += cur[0]; y += cur[1]
            pts.append((x, y)); cur = (x, y)
        elif cmd in ("Z", "z"):
            cur = start
    return pts


def resample(points, n):
    if len(points) < 2:
        return points * n if points else [(0.0, 0.0)] * n
    total = 0.0; seg = []
    for i in range(1, len(points)):
        dx = points[i][0] - points[i-1][0]; dy = points[i][1] - points[i-1][1]
        d = (dx*dx + dy*dy) ** 0.5; seg.append(d); total += d
    if total == 0: return [points[0]] * n
    out = [points[0]]; step = total / (n - 1); target = step; i = 1
    while i < len(points) and len(out) < n:
        seg_len = seg[i-1]
        while target <= seg_len and len(out) < n:
            t = target / seg_len
            out.append((points[i-1][0] + t*(points[i][0]-points[i-1][0]),
                        points[i-1][1] + t*(points[i][1]-points[i-1][1])))
            target += step
        target -= seg_len; i += 1
    while len(out) < n: out.append(points[-1])
    return out[:n]


def extract_strokes(svg):
    root = ET.fromstring(svg)
    strokes = []
    for path in root.iter("{http://www.w3.org/2000/svg}path"):
        pid = path.get("id", "")
        if "-s" not in pid: continue
        d = path.get("d", "")
        if not d: continue
        pts = parse_path(d)
        if len(pts) < 2: continue
        strokes.append(resample(pts, SAMPLES_PER_STROKE))
    return strokes


def fetch(hex_code):
    url = GITHUB_RAW.format(hex=hex_code)
    req = urllib.request.Request(url, headers={"User-Agent": "kana-ios-script/1.0"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return hex_code, r.read().decode("utf-8")


def main():
    out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out_dir.mkdir(parents=True, exist_ok=True)
    output_path = out_dir / "kana-vg-data.json"

    data = {}
    hex_codes = list(HEX_TO_KANA.keys())
    print(f"Fetching {len(hex_codes)} files in parallel...", flush=True)
    fetched = {}
    with ThreadPoolExecutor(max_workers=10) as ex:
        futs = {ex.submit(fetch, h): h for h in hex_codes}
        for fut in as_completed(futs):
            hex_code = futs[fut]
            try:
                hc, svg = fut.result()
                fetched[hc] = svg
                print(f"  ✓ {hc}", flush=True)
            except Exception as e:
                print(f"  ✗ {hex_code}: {e}", file=sys.stderr, flush=True)

    for hex_code, kanas in HEX_TO_KANA.items():
        svg = fetched.get(hex_code)
        if not svg: continue
        strokes = extract_strokes(svg)
        if not strokes:
            print(f"  ! no strokes in {hex_code}", file=sys.stderr, flush=True)
            continue
        for kana, romaji in kanas:
            data[kana] = {
                "romaji": romaji,
                "strokes": [[[round(x, 4), round(y, 4)] for x, y in s] for s in strokes],
            }
        print(f"  {hex_code} → {len(strokes)} strokes for {','.join(k for k,_ in kanas)}", flush=True)

    output_path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    print(f"Wrote {len(data)} kana → {output_path} ({output_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()