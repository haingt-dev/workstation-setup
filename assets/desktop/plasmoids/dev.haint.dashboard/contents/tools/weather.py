#!/usr/bin/env python3
"""weather.py — one JSON line for WeatherCard.qml, stdlib only (urllib).

Hard rule: this must NEVER print a traceback and must ALWAYS exit 0 with
valid JSON, even offline — QML's JSON.parse has no graceful path if this
prints garbage. Network failures fall back to the last good cache; only a
never-fetched-yet cold start with no network reports ok:false.
"""
import json
import os
import sys
import time
import urllib.request

URL = (
    "https://api.open-meteo.com/v1/forecast"
    "?latitude=10.82&longitude=106.63"
    "&current=temperature_2m,relative_humidity_2m,apparent_temperature,"
    "weather_code,wind_speed_10m,is_day"
    "&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset,weather_code"
    "&forecast_days=1&timezone=Asia%2FHo_Chi_Minh"
)
CACHE_DIR = os.path.expanduser("~/.cache/workstation-setup")
CACHE_PATH = os.path.join(CACHE_DIR, "weather.json")
MIN_REFETCH_SEC = 600  # 10 minutes — open-meteo's own current-weather cadence

# WMO weather_code -> (Vietnamese text, day icon, night icon)
CODE_MAP = {
    0: ("trời quang", "weather-clear", "weather-clear-night"),
    1: ("ít mây", "weather-few-clouds", "weather-few-clouds-night"),
    2: ("mây rải rác", "weather-few-clouds", "weather-few-clouds-night"),
    3: ("nhiều mây", "weather-many-clouds", "weather-many-clouds"),
    45: ("sương mù", "weather-fog", "weather-fog"),
    48: ("sương mù đóng băng", "weather-fog", "weather-fog"),
    51: ("mưa phùn nhẹ", "weather-showers-scattered", "weather-showers-scattered"),
    53: ("mưa phùn", "weather-showers-scattered", "weather-showers-scattered"),
    55: ("mưa phùn dày", "weather-showers-scattered", "weather-showers-scattered"),
    56: ("mưa phùn đóng băng", "weather-showers-scattered", "weather-showers-scattered"),
    57: ("mưa phùn đóng băng dày", "weather-showers-scattered", "weather-showers-scattered"),
    61: ("mưa nhỏ", "weather-showers", "weather-showers"),
    63: ("mưa", "weather-showers", "weather-showers"),
    65: ("mưa to", "weather-showers", "weather-showers"),
    66: ("mưa đóng băng", "weather-showers", "weather-showers"),
    67: ("mưa đóng băng to", "weather-showers", "weather-showers"),
    71: ("tuyết nhẹ", "weather-snow", "weather-snow"),
    73: ("tuyết", "weather-snow", "weather-snow"),
    75: ("tuyết dày", "weather-snow", "weather-snow"),
    77: ("hạt tuyết", "weather-snow", "weather-snow"),
    80: ("mưa rào nhẹ", "weather-showers-scattered", "weather-showers-scattered"),
    81: ("mưa rào", "weather-showers-scattered", "weather-showers-scattered"),
    82: ("mưa rào lớn", "weather-showers-scattered", "weather-showers-scattered"),
    85: ("mưa tuyết nhẹ", "weather-snow", "weather-snow"),
    86: ("mưa tuyết dày", "weather-snow", "weather-snow"),
    95: ("dông", "weather-storm", "weather-storm"),
    96: ("dông kèm mưa đá", "weather-storm", "weather-storm"),
    99: ("dông kèm mưa đá lớn", "weather-storm", "weather-storm"),
}


def code_to_text_icon(code, is_day):
    text, day_icon, night_icon = CODE_MAP.get(int(code), ("không rõ", "weather-none-available", "weather-none-available"))
    return text, (day_icon if is_day else night_icon)


def hhmm(iso):
    # open-meteo returns "2026-09-07T05:48" — just slice, no need to parse a
    # full datetime for a HH:MM display.
    try:
        return iso.split("T", 1)[1][:5]
    except Exception:
        return "--:--"


def fetch():
    req = urllib.request.Request(URL, headers={"User-Agent": "workstation-setup-dashboard/1.0"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))


def build_payload(raw, fetched_at):
    cur = raw["current"]
    day = raw["daily"]
    is_day = bool(cur.get("is_day", 1))
    text, icon = code_to_text_icon(cur["weather_code"], is_day)
    return {
        "ok": True,
        "temp": cur["temperature_2m"],
        "feels": cur["apparent_temperature"],
        "humidity": cur["relative_humidity_2m"],
        "wind": cur["wind_speed_10m"],
        "code": cur["weather_code"],
        "text": text,
        "icon": icon,
        "isDay": is_day,
        "max": day["temperature_2m_max"][0],
        "min": day["temperature_2m_min"][0],
        "sunrise": hhmm(day["sunrise"][0]),
        "sunset": hhmm(day["sunset"][0]),
        "fetchedAt": fetched_at,
        "stale": False,
        "ageSec": 0,
        "error": "",
    }


def load_cache():
    try:
        with open(CACHE_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def save_cache(payload):
    try:
        # 0600 from the moment the file exists, and a 0700 directory: this
        # cache holds nothing secret, but it shares a directory with one that
        # does, and "private here, world-readable there" is the kind of
        # inconsistency that later gets copied into the wrong file.
        os.makedirs(CACHE_DIR, mode=0o700, exist_ok=True)
        tmp = CACHE_PATH + ".tmp"
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(payload, f)
        os.replace(tmp, CACHE_PATH)  # atomic — never leaves a half-written cache
    except Exception:
        pass  # a cache write failure must not turn into a crash


def main():
    force_refresh = "--refresh" in sys.argv[1:]
    cached = load_cache()
    now = time.time()

    if cached and not force_refresh:
        age = now - cached.get("fetchedAt", 0)
        if age < MIN_REFETCH_SEC:
            cached["stale"] = False
            cached["ageSec"] = int(age)
            print(json.dumps(cached))
            return

    try:
        raw = fetch()
        payload = build_payload(raw, now)
        save_cache(payload)
        print(json.dumps(payload))
        return
    except Exception as e:
        error = str(e)

    if cached:
        cached["stale"] = True
        cached["ageSec"] = int(now - cached.get("fetchedAt", 0))
        cached["error"] = error
        print(json.dumps(cached))
    else:
        print(json.dumps({
            "ok": False, "temp": None, "feels": None, "humidity": None,
            "wind": None, "code": None, "text": "", "icon": "weather-none-available",
            "isDay": True, "max": None, "min": None, "sunrise": "", "sunset": "",
            "fetchedAt": 0, "stale": False, "ageSec": 0, "error": error,
        }))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # Absolute last resort — must still be one valid JSON line, exit 0.
        print(json.dumps({
            "ok": False, "temp": None, "feels": None, "humidity": None,
            "wind": None, "code": None, "text": "", "icon": "weather-none-available",
            "isDay": True, "max": None, "min": None, "sunrise": "", "sunset": "",
            "fetchedAt": 0, "stale": False, "ageSec": 0, "error": str(e),
        }))
    sys.exit(0)
