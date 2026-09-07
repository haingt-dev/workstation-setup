#!/usr/bin/env python3
"""
claude-quota.py — reads Claude Code's own OAuth token and asks Anthropic how
much of Hải's Max subscription quota is used, for the dev.haint.claudequota
plasmoid.

Landmines this file works around (verified live against the real API,
2026-09):
  - The 'limits' array (not five_hour/seven_day) carries the per-model weekly
    window ("weekly_scoped") — that's the one Hải actually hits, and it does
    not exist anywhere else in the response. Prefer it; fall back only when
    it's absent/empty.
  - The token must never touch argv/logs/output — stdlib urllib only, header
    set in-process, never shelled out to curl.
  - Claude Code owns the token lifecycle. We never write .credentials.json and
    never refresh; we just retry once on 401 in case it rotated mid-read.
  - Self-throttled + cached so a 60s-interval QML timer never hammers the API
    or spawns python needlessly; a stale cache is still better than a blank
    widget, so failures still print the last good payload (marked stale).
"""
import json
import os
import sys
import tempfile
import time
import urllib.request
import urllib.error

CONFIG_DIR = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
CREDENTIALS_PATH = os.path.join(CONFIG_DIR, ".credentials.json")
CACHE_DIR = os.path.expanduser("~/.cache/workstation-setup")
CACHE_PATH = os.path.join(CACHE_DIR, "claude-quota.json")
USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
STALE_THROTTLE_SEC = 55
CACHE_MAX_AGE_SEC = 6 * 3600

KIND_LABELS = {
    "session": ("Phiên 5 giờ", "5h"),
    "weekly_all": ("Tuần, tất cả", "wk"),
}


def read_credentials():
    with open(CREDENTIALS_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    oauth = data.get("claudeAiOauth") or {}
    token = oauth.get("accessToken")
    if not token:
        raise ValueError("no accessToken in credentials file")
    return token, oauth


def fetch_usage(token):
    req = urllib.request.Request(
        USAGE_URL,
        headers={
            "Authorization": "Bearer " + token,
            "Accept": "application/json",
            "Content-Type": "application/json",
            "anthropic-beta": "oauth-2025-04-20",
            "User-Agent": "workstation-setup-claude-quota/1.0",
        },
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_usage_with_retry():
    """One 401 retry after re-reading credentials — token may have just
    rotated under us (Claude Code refreshes it independently of this script)."""
    token, oauth = read_credentials()
    try:
        return fetch_usage(token), oauth
    except urllib.error.HTTPError as e:
        if e.code != 401:
            raise
        token, oauth = read_credentials()
        return fetch_usage(token), oauth


def label_for(kind, scope):
    if kind == "weekly_scoped":
        model_name = None
        if isinstance(scope, dict):
            model = scope.get("model") or {}
            model_name = model.get("display_name")
        model_name = model_name or "?"
        return "Tuần, " + model_name, model_name[:2]
    if kind in KIND_LABELS:
        return KIND_LABELS[kind]
    # Unknown kind: prettify rather than drop, per spec.
    pretty = kind.replace("_", " ").strip().capitalize() or kind
    return pretty, pretty[:2].lower()


def limits_from_payload(payload):
    """Primary source: the 'limits' array — carries per-model weekly windows
    that exist nowhere else in the response. Falls back to five_hour/
    seven_day only when 'limits' is missing or empty."""
    raw_limits = payload.get("limits") or []
    limits = []
    if raw_limits:
        for item in raw_limits:
            kind = item.get("kind") or "unknown"
            label, short = label_for(kind, item.get("scope"))
            resets_at = parse_iso_to_epoch(item.get("resets_at"))
            limits.append({
                "id": kind,
                "label": label,
                "short": short,
                "percent": item.get("percent") or 0,
                "severity": item.get("severity") or "normal",
                "resetsAt": resets_at,
                "active": bool(item.get("is_active")),
            })
        return limits

    for key, kind in (("five_hour", "session"), ("seven_day", "weekly_all")):
        block = payload.get(key)
        if not block:
            continue
        label, short = KIND_LABELS[kind]
        limits.append({
            "id": kind,
            "label": label,
            "short": short,
            "percent": block.get("utilization") or 0,
            "severity": "normal",
            "resetsAt": parse_iso_to_epoch(block.get("resets_at")),
            "active": False,
        })
    return limits


def parse_iso_to_epoch(iso_str):
    if not iso_str:
        return 0
    try:
        # fromisoformat handles "+00:00"; a trailing "Z" needs normalising.
        s = iso_str.replace("Z", "+00:00")
        import datetime
        dt = datetime.datetime.fromisoformat(s)
        # A timestamp with NO offset would otherwise be read as local time —
        # a 7-hour error in every countdown here. The endpoint sends offsets
        # today, but it is undocumented and may not tomorrow.
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=datetime.timezone.utc)
        return int(dt.timestamp())
    except (ValueError, TypeError):
        return 0


def claude_is_running():
    """Pure-python /proc scan — no subprocess spawn just to answer this."""
    try:
        for entry in os.listdir("/proc"):
            if not entry.isdigit():
                continue
            try:
                with open("/proc/" + entry + "/comm", "r", encoding="utf-8") as f:
                    if f.read().strip() == "claude":
                        return True
            except OSError:
                continue
    except OSError:
        pass
    return False


def read_cache():
    try:
        with open(CACHE_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def write_cache(payload):
    """Atomic, and private from the moment the file exists.

    open()+chmod would leave a window where the cache is world-readable. The
    payload holds no token (plan/tier/percent/resetsAt only), but it sits in a
    directory next to files that do, so the mode is baked into the descriptor.
    """
    os.makedirs(CACHE_DIR, mode=0o700, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=CACHE_DIR, prefix=".claude-quota.", suffix=".tmp")
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(payload, f)
        os.replace(tmp_path, CACHE_PATH)
    except BaseException:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def emit(result, exit_code):
    print(json.dumps(result))
    sys.exit(exit_code)


def stale_result(error, cache, now):
    running = claude_is_running()
    if cache:
        age = int(now - cache.get("fetchedAt", now))
        if age <= CACHE_MAX_AGE_SEC:
            cache = dict(cache)
            cache["ok"] = False
            cache["stale"] = True
            cache["ageSec"] = age
            cache["error"] = error
            cache["claudeRunning"] = running
            return cache
    return {
        "ok": False, "plan": "", "tier": "", "claudeRunning": running,
        "fetchedAt": int(now), "stale": True, "ageSec": 0,
        "error": error, "limits": [],
    }


def main():
    refresh = "--refresh" in sys.argv
    now = time.time()
    cache = read_cache()

    if not refresh and cache:
        age = now - cache.get("fetchedAt", 0)
        if 0 <= age < STALE_THROTTLE_SEC:
            emit(cache, 0 if cache.get("ok") else 1)

    try:
        payload, oauth = fetch_usage_with_retry()
    except Exception as e:  # noqa: BLE001 - any failure degrades to cache, never crashes
        emit(stale_result(str(e), cache, now), 1)
        return

    result = {
        "ok": True,
        "plan": oauth.get("subscriptionType") or "",
        "tier": oauth.get("rateLimitTier") or "",
        "claudeRunning": claude_is_running(),
        "fetchedAt": int(now),
        "stale": False,
        "ageSec": 0,
        "error": "",
        "limits": limits_from_payload(payload),
    }
    # A cache write must never cost us a good answer: without this guard an
    # unwritable ~/.cache makes main() raise before emit() and the widget gets
    # empty stdout, i.e. "unavailable" while the API was actually fine.
    try:
        write_cache(result)
    except OSError:
        pass
    emit(result, 0)


if __name__ == "__main__":
    main()
