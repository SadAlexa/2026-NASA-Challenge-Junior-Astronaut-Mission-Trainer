#!/usr/bin/env python3
"""Fetch real NASA data at build time and embed it in game/data/.

Usage:
    NASA_APOD_API_KEY=... python3 tools/fetch_nasa_data.py

If NASA_APOD_API_KEY is not set, the script reads game/.env, and finally falls
back to the public science.nasa.gov APOD JSON endpoint (same APOD content).

Outputs:
    game/data/donki_events.json   curated DONKI FLR archive + provenance
    game/data/nasa_reference.json RadLab/OSDR baseline, APOD snapshot, NOAA Kp
    game/data/apod_fallback.jpg   bundled APOD image (offline fallback)

The game never makes network calls. This script is the only network step.
"""

from __future__ import annotations

import datetime as dt
import html
import json
import os
import re
import ssl
import statistics
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "game" / "data"
ENV_FILE = ROOT / "game" / ".env"

UA = "Mozilla/5.0 (X11; Linux x86_64) MissionSeleneBuild/1.0"
DONKI_START = dt.date(2025, 1, 1)
DONKI_MAX_WINDOW_DAYS = 59
RADLAB_WINDOW = ("2023-12-01", "2024-01-01")  # last quiet month with full coverage
LUNAR_SURFACE_MSV_DAY = 1.4  # GDD / literature reference (equivalent dose)
GAME_BASE_UNITS = 20.0

_ctx_insecure = ssl.create_default_context()
_ctx_insecure.check_hostname = False
_ctx_insecure.verify_mode = ssl.CERT_NONE
_ctx_verify = ssl.create_default_context()


def _ssl_ctx(insecure: bool) -> ssl.SSLContext:
    if insecure:
        return _ctx_insecure
    return _ctx_verify


def fetch(url: str, timeout: int = 45, insecure: bool = False) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=timeout, context=_ssl_ctx(insecure)) as r:
        return r.read()


def get_json(url: str, timeout: int = 45):
    raw = fetch(url, timeout=timeout)
    return json.loads(raw.decode("utf-8", "replace"))


def try_json(urls: list[str], timeout: int = 45):
    """Try each URL, return (data, url_used)."""
    last = None
    for url in urls:
        try:
            return get_json(url, timeout=timeout), url
        except Exception as exc:  # noqa: BLE001 - build tool, report and continue
            last = exc
            print(f"  ! {url.split('?')[0]} -> {exc}")
    raise RuntimeError(f"all endpoints failed: {last}")


def date_windows(start: dt.date, end: dt.date, max_days: int):
    cur = start
    while cur <= end:
        nxt = min(cur + dt.timedelta(days=max_days - 1), end)
        yield cur.isoformat(), nxt.isoformat()
        cur = nxt + dt.timedelta(days=1)


def donki_get(kind: str, start: str, end: str) -> tuple[list, str]:
    # CCMC is NASA's own DONKI service and needs no key, so it is the default.
    # If a personal NASA API key is available, try api.nasa.gov first.
    ccmc = f"https://ccmc.gsfc.nasa.gov/DONKI-API/get/{kind}?startDate={start}&endDate={end}"
    urls = [ccmc]
    key = os.environ.get("NASA_API_KEY", "").strip()
    if key:
        q = urllib.parse.urlencode({"startDate": start, "endDate": end, "api_key": key})
        urls.insert(0, f"https://api.nasa.gov/DONKI/{kind}?{q}")
    data, used = try_json(urls)
    if not isinstance(data, list):
        raise RuntimeError(f"DONKI {kind}: unexpected payload {type(data)}")
    return data, used


def flare_flux(class_type: str) -> float:
    m = re.match(r"([CMX])([0-9.]+)", str(class_type or ""))
    if not m:
        return -1.0
    num = float(m.group(2))
    # X1.0 is 10x M1.0 and 100x C1.0
    return num * {"C": 1.0, "M": 10.0, "X": 100.0}[m.group(1)]


def strip_html(value: str) -> str:
    text = re.sub(r"<[^>]+>", " ", str(value or ""))
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def pick_flares(events: list[dict]) -> list[dict]:
    seen = set()
    clean = []
    for ev in events:
        flr_id = str(ev.get("flrID", "")).strip()
        ctype = str(ev.get("classType", "")).strip()
        if not flr_id or not ctype or flr_id in seen:
            continue
        seen.add(flr_id)
        clean.append(ev)

    def by_flux(items):
        return sorted(items, key=lambda e: flare_flux(e.get("classType", "")), reverse=True)

    xs = by_flux([e for e in clean if e.get("classType", "").startswith("X")])[:4]
    ms = by_flux([e for e in clean if e.get("classType", "").startswith("M")])[:2]
    cs = by_flux([e for e in clean if e.get("classType", "").startswith("C")])[:2]

    selected = xs + ms + cs
    selected.sort(key=lambda e: str(e.get("beginTime", "")))

    out = []
    for ev in selected:
        ctype = str(ev.get("classType", ""))
        out.append(
            {
                "id": str(ev.get("flrID", "")),
                "kind": "FLR",
                "class": ctype[:1],
                "peak_class": ctype,
                "begin_time": str(ev.get("beginTime", "")),
                "peak_time": str(ev.get("peakTime", "")),
                "end_time": str(ev.get("endTime", "")),
                "source_location": str(ev.get("sourceLocation", "") or ""),
                "active_region": ev.get("activeRegionNum"),
                "link": str(ev.get("link", "") or ""),
            }
        )
    return out


def build_donki() -> dict:
    today = dt.date.today()
    all_flr: list[dict] = []
    all_sep: list[dict] = []
    all_cme: list[dict] = []
    used_endpoint = ""

    print("DONKI: fetching FLR/SEP/CME in 60-day windows...")
    for start, end in date_windows(DONKI_START, today, DONKI_MAX_WINDOW_DAYS):
        for kind, bucket in (("FLR", all_flr), ("SEP", all_sep), ("CME", all_cme)):
            try:
                rows, used = donki_get(kind, start, end)
                used_endpoint = used_endpoint or used
                bucket.extend(rows)
                print(f"  {kind} {start}..{end}: {len(rows)}")
            except Exception as exc:  # noqa: BLE001
                print(f"  ! {kind} {start}..{end}: {exc}")
            time.sleep(0.15)

    selected = pick_flares(all_flr)
    if not any(e["class"] == "X" for e in selected):
        print("  ! no X-class flare found in the window", file=sys.stderr)

    sep_sample = None
    if all_sep:
        sep = all_sep[-1]
        sep_sample = {
            "id": str(sep.get("sepID", "")),
            "event_time": str(sep.get("eventTime", "")),
            "link": str(sep.get("link", "") or ""),
            "instruments": [
                i.get("displayName", "")
                for i in (sep.get("instruments") or [])
                if isinstance(i, dict)
            ][:4],
        }

    cme_sample = None
    if all_cme:
        def speed(ev):
            analyses = ev.get("cmeAnalyses") or []
            if analyses and isinstance(analyses[0], dict):
                return float(analyses[0].get("speed") or 0)
            return 0.0

        cme = max(all_cme, key=speed)
        analyses = cme.get("cmeAnalyses") or []
        cme_sample = {
            "id": str(cme.get("activityID", "")),
            "start_time": str(cme.get("startTime", "")),
            "source_location": str(cme.get("sourceLocation", "") or ""),
            "speed_km_s": speed(cme),
            "type": str(analyses[0].get("type", "")) if analyses else "",
        }

    return {
        "dataset": {
            "name": "NASA DONKI - Solar Flares (FLR), Solar Energetic Particles (SEP), Coronal Mass Ejections (CME)",
            "archived": True,
            "retrieved": today.isoformat(),
            "range": f"{DONKI_START.isoformat()}..{today.isoformat()}",
            "source": "https://ccmc.gsfc.nasa.gov/tools/DONKI/",
            "api": "https://api.nasa.gov/DONKI/",
            "endpoint_used": used_endpoint,
            "counts": {
                "flr": len(all_flr),
                "sep": len(all_sep),
                "cme": len(all_cme),
            },
            "selected": {
                "X": sum(1 for e in selected if e["class"] == "X"),
                "M": sum(1 for e in selected if e["class"] == "M"),
                "C": sum(1 for e in selected if e["class"] == "C"),
            },
            "sample_sep": sep_sample,
            "sample_cme": cme_sample,
            "note": (
                "Curated real DONKI events bundled at build time. Game radiation values are "
                "simplified 0-100 units defined in game/data/constants.gd, not physical units."
            ),
        },
        "events": selected,
    }


def build_radlab() -> dict:
    start, end = RADLAB_WINDOW
    url = (
        "https://visualization.osdr.nasa.gov/radlab/api/"
        "?instrument=CRaTER-D1D2"
        f"&timestamp%3E={start}T00%3A00&timestamp%3C{end}T00%3A00"
        "&absorbed_dose_rate&format=json"
    )
    fallback = {
        "source": "NASA RadLab / OSDR - CRaTER-D1D2 (LRO)",
        "instrument": "CRaTER-D1D2",
        "period": f"{start}..{end}",
        "samples": 0,
        "raw_unit": "uGy/h",
        "median_uGy_h": 5.26,
        "mean_uGy_h": 7.64,
        "max_uGy_h": 92.0,
        "status": "fallback",
        "citation": "https://visualization.osdr.nasa.gov/radlab/gui/knowledgebase/CRaTER-D1D2",
    }
    try:
        payload = get_json(url, timeout=60)
        cols = payload.get("columns") or []
        rows = payload.get("data") or []
        idx = cols.index("absorbed_dose_rate")
        vals = [float(r[idx]) for r in rows if r[idx] is not None]
        if not vals:
            raise RuntimeError("no rows")
        median = statistics.median(vals)
        mean = statistics.mean(vals)
        absorbed_mgy_day = median * 24.0 / 1000.0
        result = {
            "source": "NASA RadLab / OSDR - CRaTER-D1D2 (LRO)",
            "instrument": "CRaTER-D1D2",
            "period": f"{start}..{end}",
            "samples": len(vals),
            "raw_unit": "uGy/h",
            "median_uGy_h": round(median, 3),
            "mean_uGy_h": round(mean, 3),
            "max_uGy_h": round(max(vals), 3),
            "absorbed_mGy_day": round(absorbed_mgy_day, 4),
            "quality_factor": 2.0,
            "equivalent_mSv_day_estimate": round(absorbed_mgy_day * 2.0, 4),
            "status": "fetched-at-build",
            "citation": "https://visualization.osdr.nasa.gov/radlab/gui/knowledgebase/CRaTER-D1D2",
            "note": (
                "Absorbed dose in silicon measured by the CRaTER D1/D2 detector pair on LRO. "
                "It is not directly a human equivalent dose; the game anchors 20/100 units to "
                "the lunar-surface reference below, not to the raw detector value."
            ),
        }
        return result
    except Exception as exc:  # noqa: BLE001
        print(f"  ! RadLab: {exc}")
        return fallback


def build_apod() -> dict:
    key = os.environ.get("NASA_APOD_API_KEY", "").strip()
    if not key and ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
            if line.startswith("NASA_APOD_API_KEY="):
                key = line.split("=", 1)[1].strip()
                break

    data = None
    endpoint = ""
    if key:
        try:
            data = get_json(
                f"https://api.nasa.gov/planetary/apod?api_key={key}&thumbs=true",
                timeout=30,
            )
            endpoint = "https://api.nasa.gov/planetary/apod"
        except Exception as exc:  # noqa: BLE001
            print(f"  ! official APOD: {exc}")

    if data is None:
        try:
            arr = get_json(
                "https://science.nasa.gov/wp-json/wp/v2/apod-basic?count=5",
                timeout=30,
            )
            if isinstance(arr, list):
                for item in arr:
                    if str(item.get("media_type", "image")) == "image":
                        data = item
                        break
            endpoint = "https://science.nasa.gov/wp-json/wp/v2/apod-basic"
        except Exception as exc:  # noqa: BLE001
            print(f"  ! fallback APOD: {exc}")
            return {
                "status": "missing",
                "date": "",
                "title": "NASA image unavailable",
                "explanation": "",
                "credit": "",
                "url": "https://apod.nasa.gov/",
                "image_path": "",
                "endpoint": "",
            }

    if not isinstance(data, dict):
        raise RuntimeError("unexpected APOD payload")

    image_url = str(data.get("hdurl") or data.get("url") or "")
    # Ask the NASA asset CDN for a game-sized rendition instead of the 2880px original.
    if "assets.science.nasa.gov" in image_url:
        image_url = re.sub(r"([?&])w=\d+", r"\g<1>w=1400", image_url)
        if "w=1400" not in image_url:
            image_url += ("&" if "?" in image_url else "?") + "w=1400"

    image_path = ""
    if str(data.get("media_type", "image")) == "image" and image_url:
        try:
            blob = fetch(image_url, timeout=90)
            out = DATA / "apod_fallback.jpg"
            out.write_bytes(blob)
            image_path = "res://data/apod_fallback.jpg"
            print(f"  APOD image: {len(blob) / 1024:.0f} KiB -> {out.relative_to(ROOT)}")
        except Exception as exc:  # noqa: BLE001
            print(f"  ! APOD image download: {exc}")

    return {
        "status": "fetched-at-build",
        "date": str(data.get("date", "")),
        "title": strip_html(str(data.get("title", ""))),
        "explanation": strip_html(str(data.get("explanation", "")))[:420],
        "credit": strip_html(str(data.get("copyright", data.get("credit", "")))),
        "page_url": str(data.get("url", "")),
        "image_path": image_path,
        "endpoint": endpoint,
        "source": "https://apod.nasa.gov/",
    }


def build_space_weather() -> dict:
    try:
        arr = get_json(
            "https://services.swpc.noaa.gov/json/planetary_k_index_1m.json",
            timeout=25,
        )
        latest = arr[-1] if isinstance(arr, list) and arr else {}
        return {
            "source": "NOAA SWPC (not NASA)",
            "kp_index": int(latest.get("kp_index", 0)),
            "kp_label": str(latest.get("kp", "")),
            "time_tag": str(latest.get("time_tag", "")),
            "url": "https://services.swpc.noaa.gov/json/planetary_k_index_1m.json",
        }
    except Exception as exc:  # noqa: BLE001
        print(f"  ! SWPC Kp: {exc}")
        return {"source": "NOAA SWPC (not NASA)", "kp_index": 0, "kp_label": "", "time_tag": ""}


def main() -> int:
    DATA.mkdir(parents=True, exist_ok=True)

    print("== DONKI ==")
    donki = build_donki()
    (DATA / "donki_events.json").write_text(
        json.dumps(donki, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(
        f"  wrote {len(donki['events'])} events "
        f"(X={donki['dataset']['selected']['X']}, "
        f"M={donki['dataset']['selected']['M']}, "
        f"C={donki['dataset']['selected']['C']})"
    )

    print("== RadLab/OSDR ==")
    rad = build_radlab()
    print(f"  median {rad['median_uGy_h']} uGy/h ({rad['status']})")

    print("== APOD ==")
    apod = build_apod()
    print(f"  {apod['date']} - {apod['title']}")

    print("== NOAA SWPC ==")
    swpc = build_space_weather()
    print(f"  Kp {swpc['kp_index']} @ {swpc['time_tag']}")

    reference = {
        "retrieved": dt.date.today().isoformat(),
        "archived": True,
        "radiation": {
            **rad,
            "lunar_surface_reference_mSv_day": LUNAR_SURFACE_MSV_DAY,
            "game_base_units": GAME_BASE_UNITS,
            "game_unit_mSv_day": round(LUNAR_SURFACE_MSV_DAY / GAME_BASE_UNITS, 4),
        },
        "apod": apod,
        "space_weather": swpc,
    }
    (DATA / "nasa_reference.json").write_text(
        json.dumps(reference, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    print("\nDone. Embedded data is now in game/data/.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
