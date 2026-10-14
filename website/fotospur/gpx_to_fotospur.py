#!/usr/bin/env python3
"""Erzeugt die Daten für eine Fotospur aus einer Tourspur-GPX-Datei und Fotos.

Jedes Foto wird über seine Aufnahmezeit (oder, falls vorhanden, seine
GPS-Position) an die passende Stelle der Strecke gesetzt.

Beispiele:
  # Fotos als lokale Dateien, Zeit und Ort kommen aus den EXIF-Daten
  python3 gpx_to_fotospur.py tour.gpx IMG_0001.jpeg IMG_0002.jpeg \
      --url-prefix https://rollermomente.de/wp-content/uploads/2026/10/

  # Fotos per Hand: "Adresse|Titel|Uhrzeit"
  python3 gpx_to_fotospur.py tour.gpx "https://…/hafen.jpeg|Am Hafen|19:42"

Ausgabe ist ein HTML-Schnipsel für einen WordPress-Block „Individuelles HTML“
(mit --json nur die Daten).
"""
import argparse
import json
import math
import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None

GPX_NS = {"g": "http://www.topografix.com/GPX/1/1"}


def haversine_km(a, b):
    r = 6371.0088
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def parse_time(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def read_gpx(path):
    root = ET.parse(path).getroot()
    name = root.findtext(".//g:trk/g:name", default="", namespaces=GPX_NS)
    pts = []
    for p in root.iterfind(".//g:trkpt", GPX_NS):
        ele = p.findtext("g:ele", default="0", namespaces=GPX_NS)
        t = p.findtext("g:time", default=None, namespaces=GPX_NS)
        pts.append({
            "lat": float(p.get("lat")), "lon": float(p.get("lon")),
            "ele": float(ele), "time": parse_time(t) if t else None,
        })
    if len(pts) < 2:
        sys.exit("Die GPX-Datei enthält keine Strecke.")
    km = 0.0
    pts[0]["km"] = 0.0
    for a, b in zip(pts, pts[1:]):
        km += haversine_km((a["lat"], a["lon"]), (b["lat"], b["lon"]))
        b["km"] = km
    return name, pts


def stats(pts):
    # Höhenmeter mit Schwelle, damit GPS-Rauschen nicht mitzählt
    gain, ref = 0.0, pts[0]["ele"]
    for p in pts[1:]:
        if p["ele"] - ref > 3:
            gain += p["ele"] - ref
            ref = p["ele"]
        elif ref - p["ele"] > 3:
            ref = p["ele"]
    out = {"km": round(pts[-1]["km"], 1), "hm": round(gain)}
    if pts[0]["time"] and pts[-1]["time"]:
        mins = int((pts[-1]["time"] - pts[0]["time"]).total_seconds() // 60)
        out["dauer"] = "%d:%02d" % (mins // 60, mins % 60)
        out["datum"] = pts[0]["time"].astimezone().strftime("%d.%m.%Y")
    return out


def simplify(pts, max_points):
    """Gleichmäßig nach Strecke ausdünnen, Start und Ziel bleiben."""
    if len(pts) <= max_points:
        return pts
    step = pts[-1]["km"] / (max_points - 1)
    out, nxt = [pts[0]], step
    for p in pts[1:-1]:
        if p["km"] >= nxt:
            out.append(p)
            nxt += step
    out.append(pts[-1])
    return out


def exif_info(path, tz):
    """Aufnahmezeit (aware) und GPS-Position aus einer Bilddatei, soweit vorhanden."""
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Für EXIF-Daten wird Pillow gebraucht: python3 -m pip install pillow")
    img = Image.open(path)
    exif = img.getexif()
    sub = exif.get_ifd(0x8769)
    raw = sub.get(0x9003) or exif.get(0x0132)  # DateTimeOriginal, DateTime
    when = None
    if raw:
        when = datetime.strptime(raw, "%Y:%m:%d %H:%M:%S")
        offset = sub.get(0x9011)  # OffsetTimeOriginal, z. B. "+02:00"
        if offset:
            when = datetime.fromisoformat(when.isoformat() + offset)
        elif tz:
            when = when.replace(tzinfo=tz)
    gps = exif.get_ifd(0x8825)
    pos = None
    if gps.get(2) and gps.get(4):
        def deg(v):
            return float(v[0]) + float(v[1]) / 60 + float(v[2]) / 3600
        lat, lon = deg(gps[2]), deg(gps[4])
        if gps.get(1) == "S":
            lat = -lat
        if gps.get(3) == "W":
            lon = -lon
        pos = (lat, lon)
    return when, pos


def place(pts, when=None, pos=None):
    if pos:
        best = min(pts, key=lambda p: haversine_km(pos, (p["lat"], p["lon"])))
        return best
    if when and pts[0]["time"]:
        return min(pts, key=lambda p: abs((p["time"] - when).total_seconds()))
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("gpx")
    ap.add_argument("photos", nargs="*", help='Bilddatei oder "Adresse|Titel|HH:MM"')
    ap.add_argument("--url-prefix", default="", help="Adresse, unter der die Bilddateien liegen")
    ap.add_argument("--name", help="Name der Tour (sonst aus der GPX-Datei)")
    ap.add_argument("--tz", default="Europe/Berlin", help="Zeitzone der Kamera, falls EXIF keine enthält")
    ap.add_argument("--max-points", type=int, default=400)
    ap.add_argument("--json", action="store_true", help="nur die JSON-Daten ausgeben")
    args = ap.parse_args()

    tz = ZoneInfo(args.tz) if ZoneInfo and args.tz else None
    name, pts = read_gpx(args.gpx)
    day = pts[0]["time"].astimezone(tz) if pts[0]["time"] else None

    photos = []
    for spec in args.photos:
        if os.path.isfile(spec):
            when, pos = exif_info(spec, tz)
            p = place(pts, when, pos)
            title = os.path.splitext(os.path.basename(spec))[0]
            src = args.url_prefix + os.path.basename(spec)
        else:
            parts = spec.split("|")
            src, title = parts[0], parts[1] if len(parts) > 1 else ""
            when = None
            if len(parts) > 2 and day:
                hh, mm = map(int, parts[2].split(":"))
                when = day.replace(hour=hh, minute=mm, second=0)
            p = place(pts, when)
        if p is None:
            print("Übersprungen, weder Zeit noch Ort bekannt: %s" % spec, file=sys.stderr)
            continue
        t = p["time"].astimezone(tz).strftime("%H:%M") if p["time"] else ""
        photos.append({"src": src, "title": title, "time": t, "km": round(p["km"], 2)})

    data = {
        "name": args.name or name,
        "stats": stats(pts),
        "track": [[round(p["lat"], 5), round(p["lon"], 5), round(p["ele"], 1), round(p["km"], 3)]
                  for p in simplify(pts, args.max_points)],
        "photos": sorted(photos, key=lambda x: x["km"]),
    }
    js = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    if args.json:
        print(js)
    else:
        print('<div class="fotospur"><script type="application/json">%s</script></div>' % js)


if __name__ == "__main__":
    main()
