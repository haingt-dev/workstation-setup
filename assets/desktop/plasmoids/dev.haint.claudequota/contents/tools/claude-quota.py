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
  - Failures are classified before they reach the widget. The popup prints
    `error` verbatim, and the first fetch of the day happens seconds after
    login — before NetworkManager has DNS — so the raw
    "<urlopen error [Errno -3] Temporary failure in name resolution>" used to
    greet a cold boot as a red X. `errorKind` also tells the QML how hard to
    retry: "offline" is a few-seconds-old boot race, not an outage.
"""
import errno
import json
import os
import socket
import sys
import tempfile
import time
import urllib.request
import urllib.error

CONFIG_DIR = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
CREDENTIALS_PATH = os.path.join(CONFIG_DIR, ".credentials.json")
CACHE_DIR = os.path.expanduser("~/.cache/workstation-setup")
CACHE_PATH = os.path.join(CACHE_DIR, "claude-quota.json")
HISTORY_DIR = os.path.expanduser("~/.local/share/workstation-setup")
HISTORY_PATH = os.path.join(HISTORY_DIR, "claude-quota-history.json")
HISTORY_KEEP_DAYS = 400
USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
STALE_THROTTLE_SEC = 55
CACHE_MAX_AGE_SEC = 6 * 3600

KIND_LABELS = {
    "session": ("5-hour session", "5h"),
    "weekly_all": ("Weekly, all models", "wk"),
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
        return "Weekly, " + model_name, model_name[:2]
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


# Errnos that mean "the network stack itself isn't there yet / isn't
# reachable" — as opposed to a server that answered with something we dislike.
OFFLINE_ERRNOS = frozenset((
    errno.ENETUNREACH, errno.ENETDOWN, errno.EHOSTUNREACH,
    errno.ECONNREFUSED, errno.ECONNRESET, errno.ENOTCONN,
))


def classify_error(exc):
    """(kind, human message) for anything the fetch can throw.

    The message is shown to Hải as-is, so it has to read like a status line,
    not a traceback; the kind is what the QML branches on (icon + retry
    cadence). The raw string still travels alongside as errorDetail.
    """
    if isinstance(exc, urllib.error.HTTPError):
        if exc.code == 401:
            return "auth", "Token expired — open Claude Code to sign in again"
        if exc.code == 429:
            return "rate", "API throttled (429), will retry"
        return "http", "API returned HTTP " + str(exc.code)
    if isinstance(exc, urllib.error.URLError):
        reason = exc.reason
        if isinstance(reason, socket.gaierror):
            return "offline", "No network yet (DNS is not up)"
        if isinstance(reason, (TimeoutError, socket.timeout)):
            return "timeout", "API did not answer within 10s"
        if isinstance(reason, OSError) and reason.errno in OFFLINE_ERRNOS:
            return "offline", "No network"
        return "net", "Could not reach the API: " + str(reason)
    if isinstance(exc, (TimeoutError, socket.timeout)):
        return "timeout", "API did not answer within 10s"
    if isinstance(exc, OSError) and exc.errno in OFFLINE_ERRNOS:
        return "offline", "No network"
    if isinstance(exc, FileNotFoundError):
        return "creds", "Not signed in to Claude Code"
    if isinstance(exc, ValueError):
        # json.JSONDecodeError included: credentials file or response body.
        return "creds", "Could not read Claude Code's token"
    return "unknown", str(exc) or exc.__class__.__name__


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


def record_history(result):
    """Keep a per-day MAX of each window so usage can be read as a trend.

    The endpoint only ever reports the window it is in right now, and Claude
    Code prunes its transcripts after about five weeks — so without this, any
    review more than a month apart is looking at a single sampled moment and
    calling it a quarter. This poller already runs every 60s all day, which
    makes it the one place that can see a week's true peak rather than
    whatever the number happened to be when someone opened a terminal.

    Lives under ~/.local/share (not ~/.cache): a cache sweep must not erase
    the record. Per-day maxima keep it to one small row a day, capped at
    HISTORY_KEEP_DAYS so it never grows without bound.
    """
    # Local day, so the row lines up with how Hải reads a calendar. A weekly
    # window resets mid-day (Thu 20:00 local), so that one day's row holds the
    # peak of the window that just ended — which is the number worth keeping.
    day = time.strftime("%Y-%m-%d", time.localtime(result.get("fetchedAt") or time.time()))
    try:
        with open(HISTORY_PATH, "r", encoding="utf-8") as f:
            hist = json.load(f)
    except (OSError, ValueError):
        hist = {}
    days = hist.get("days") or {}

    row = days.get(day) or {"samples": 0}
    row["samples"] = int(row.get("samples", 0)) + 1
    row["plan"] = result.get("plan", "")
    row["tier"] = result.get("tier", "")
    for lim in result.get("limits") or []:
        key = lim.get("id")
        if not key:
            continue
        pct = lim.get("percent")
        if isinstance(pct, (int, float)):
            row[key] = max(int(pct), int(row.get(key, 0)))
        if key == "weekly_scoped" and lim.get("label"):
            row["scoped_label"] = lim["label"]
    days[day] = row

    if len(days) > HISTORY_KEEP_DAYS:
        for stale in sorted(days)[: len(days) - HISTORY_KEEP_DAYS]:
            days.pop(stale, None)
    hist["days"] = days

    os.makedirs(HISTORY_DIR, mode=0o700, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=HISTORY_DIR, prefix=".claude-quota-history.", suffix=".tmp")
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(hist, f)
        os.replace(tmp_path, HISTORY_PATH)
    except BaseException:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def emit(result, exit_code):
    print(json.dumps(result))
    sys.exit(exit_code)


def stale_result(kind, message, detail, cache, now):
    running = claude_is_running()
    if cache:
        age = int(now - cache.get("fetchedAt", now))
        if age <= CACHE_MAX_AGE_SEC:
            cache = dict(cache)
            cache["ok"] = False
            cache["stale"] = True
            cache["ageSec"] = age
            cache["error"] = message
            cache["errorKind"] = kind
            cache["errorDetail"] = detail
            cache["claudeRunning"] = running
            return cache
    return {
        "ok": False, "plan": "", "tier": "", "claudeRunning": running,
        "fetchedAt": int(now), "stale": True, "ageSec": 0,
        "error": message, "errorKind": kind, "errorDetail": detail,
        "limits": [],
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
        kind, message = classify_error(e)
        emit(stale_result(kind, message, str(e), cache, now), 1)
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
        "errorKind": "",
        "errorDetail": "",
        "limits": limits_from_payload(payload),
    }
    # A cache write must never cost us a good answer: without this guard an
    # unwritable ~/.cache makes main() raise before emit() and the widget gets
    # empty stdout, i.e. "unavailable" while the API was actually fine.
    # Same guard as the cache write, and for the same reason: a broken history
    # file must dim nothing. Broader than OSError because this one parses JSON.
    # But swallowing it outright would repeat this repo's oldest bug shape —
    # "exit 0 is not success" — with a three-month fuse: nothing would look
    # wrong until a quarterly review opened an empty file. So the reason is
    # carried in the payload, where `claude-quota.py --refresh` shows it and
    # the QML simply ignores the extra key.
    try:
        record_history(result)
    except Exception as e:  # noqa: BLE001
        result["historyError"] = str(e)
    try:
        write_cache(result)
    except OSError:
        pass
    emit(result, 0)


if __name__ == "__main__":
    main()
