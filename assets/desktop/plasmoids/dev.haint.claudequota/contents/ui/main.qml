// dev.haint.claudequota — Claude Code Max subscription quota, for the
// 42px-thick left dock. All fetching + state lives here; the two
// representations only render `root`'s properties.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "."

PlasmoidItem {
    id: root

    // ── SHARED STATE (both representations read this) ──────────────────────
    property bool ok: false
    property bool stale: true
    property bool busy: false
    property string plan: ""
    property int ageSec: 0
    property int fetchedAt: 0
    property string errorText: ""
    property var limits: []       // [{id,label,short,percent,severity,resetsAt,active}]
    readonly property int worstPercent: {
        let w = -1;
        for (const l of limits) w = Math.max(w, l.percent);
        return w;
    }

    // What the RING shows: the 5-hour session window. Hải's call 2026-09-07 —
    // it is the limit that actually stops work mid-session, and it resets in
    // hours, so it is the one a glance can act on. The weekly windows still
    // reach the eye through the mini-bars, the tooltip and the popup, and the
    // attention state below is still driven by the WORST window, so a weekly
    // wall flags the dock icon even while the ring reads comfortable.
    readonly property var sessionLimit: {
        for (const l of limits) if (l.id === "session" || l.id === "five_hour") return l;
        return null;
    }
    // No session window on this plan/response: fall back to the worst one
    // rather than showing nothing.
    readonly property int ringPercent: sessionLimit ? sessionLimit.percent : worstPercent
    readonly property string ringLabel: sessionLimit ? sessionLimit.label : "Cao nhất"

    readonly property bool hasData: limits.length > 0

    Plasmoid.status: worstPercent >= 90 ? PlasmaCore.Types.RequiresAttentionStatus : PlasmaCore.Types.ActiveStatus

    // Lead with what the ring shows, then the worst window if it is a different
    // one — so hovering never hides a weekly wall behind a calm 5-hour number.
    toolTipMainText: {
        if (!hasData) return "Claude Code" + (plan ? " · " + plan : "");
        let head = "Claude Code · " + ringPercent + "% " + (sessionLimit ? "5h" : "");
        if (worstPercent > ringPercent) head += "  (cao nhất " + worstPercent + "%)";
        return head.trim();
    }
    toolTipSubText: {
        if (!hasData) return errorText || "Chưa có dữ liệu";
        let lines = limits.map(l => l.label + ": " + l.percent + "%" + (l.active ? " (active)" : ""));
        if (stale) lines.push("— dữ liệu cũ (" + Math.round(ageSec / 60) + " phút) —");
        if (errorText) lines.push("Lỗi: " + errorText);
        return lines.join("\n");
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Làm mới ngay"
            icon.name: "view-refresh"
            onTriggered: root.refresh(true)
        },
        PlasmaCore.Action {
            text: "Mở trang usage"
            icon.name: "internet-web-browser"
            onTriggered: Qt.openUrlExternally("https://claude.ai/settings/usage")
        }
    ]

    // ── GAME GUARD — zero cost while a game is on screen ────────────────────
    GameGuard {
        id: gameGuard
        screenGeometry: Plasmoid.containment && Plasmoid.containment.screenGeometry
            ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
    }

    // ── FETCH ────────────────────────────────────────────────────────────
    readonly property string toolPath: decodeURIComponent(Qt.resolvedUrl("../tools/claude-quota.py").toString().replace("file://", ""))

    P5Support.DataSource {
        id: source
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            watchdog.stop();
            root.busy = false;
            const stdout = (data["stdout"] || "").trim();
            if (!stdout) {
                root.errorText = "không có output từ claude-quota.py";
                return;
            }
            let parsed;
            try {
                parsed = JSON.parse(stdout);
            } catch (e) {
                root.errorText = "JSON hỏng: " + e;
                return;
            }
            root.ok = !!parsed.ok;
            root.stale = !!parsed.stale;
            root.plan = parsed.plan || "";
            root.ageSec = parsed.ageSec || 0;
            root.fetchedAt = parsed.fetchedAt || 0;
            root.errorText = parsed.error || "";
            root.limits = parsed.limits || [];
            root.claudeRunning = !!parsed.claudeRunning;
        }
    }

    // Watchdog: a hung python process (network stall etc.) must not leave the
    // widget spinning forever — disconnect and surface an error instead.
    // Not bound to `running: !gameGuard.paused` like the other timers: it's a
    // one-shot armed only from refresh(), which itself already refuses to run
    // while paused, so it never fires spuriously. (A declarative binding on a
    // repeat:false Timer's `running` is unreliable anyway — the engine writes
    // `running` back to false when it fires, which severs the binding.)
    Timer {
        id: watchdog
        // 30s, not 20: claude-quota.py's 401-retry path can legitimately take
        // two 10s urlopen calls back to back (exactly when a token has just
        // been rotated by Claude Code), and a shorter watchdog would abort it.
        interval: 30000
        repeat: false
        onTriggered: {
            if (source.connectedSources.length > 0) {
                source.disconnectSource(source.connectedSources[0]);
            }
            root.busy = false;
            root.errorText = "hết thời gian chờ claude-quota.py";
        }
    }

    function refresh(force) {
        if (root.busy) return;
        if (gameGuard.paused || !gameGuard.ready) return;   // never spawn while a
        // game is up — and never before GameGuard has actually measured that.
        root.busy = true;
        watchdog.restart();
        const cmd = "python3 '" + root.toolPath + "'" + (force ? " --refresh" : "");
        source.connectSource(cmd);
    }

    // ── ADAPTIVE POLL ────────────────────────────────────────────────────
    // Failed fetch: poll fast (60s) to recover quickly. Otherwise cadence
    // scales with how close the worst limit is, and backs way off (900s)
    // when Claude isn't even running and nothing is close to the ceiling.
    readonly property int pollInterval: {
        if (!root.ok) return 60000;
        if (root.worstPercent >= 80) return 120000;
        if (!root.claudeRunning && root.worstPercent < 30) return 900000;
        return 300000;
    }
    property bool claudeRunning: false

    Timer {
        id: pollTimer
        interval: root.pollInterval
        running: !gameGuard.paused
        repeat: true
        // No triggeredOnStart: the first fetch is fired by the ready gate below,
        // so a game that is already fullscreen at login never gets probed.
        onTriggered: root.refresh(false)
    }

    // The first fetch of the session: fired once GameGuard has actually
    // measured the screen, and skipped entirely if a game already owns it.
    Connections {
        target: gameGuard
        function onReadyChanged() {
            if (gameGuard.ready && !gameGuard.paused && root.fetchedAt === 0)
                root.refresh(true);
        }
        function onResumed() { root.refresh(true); }
    }

    // Separate from polling: just re-renders "còn Xh Ym nữa" text without
    // touching the network, so the countdown doesn't visibly freeze between
    // the (much longer) poll intervals.
    Timer {
        id: clockTimer
        interval: 60000
        running: !gameGuard.paused
        repeat: true
        onTriggered: root.now = Date.now() / 1000
    }
    property real now: Date.now() / 1000

    // `expanded` is read off root, not taken as an injected handler parameter:
    // Qt 6 deprecates parameter injection into signal handlers and warns on
    // every load otherwise.
    onExpandedChanged: {
        if (root.expanded && (Date.now() / 1000 - root.fetchedAt) > 60) root.refresh(true);
    }

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}
}
