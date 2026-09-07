// =============================================================================
// GameGuard.qml - "is something fullscreen / is a game running?" gate
// =============================================================================
// Shared by every plasmoid in this rice. Hải's hard requirement since round 1:
// the desktop must cost NOTHING while a game (or any fullscreen app) is on
// screen. Widgets bind their timers and sensors to `paused` and go completely
// silent — no polling, no process spawns, no repaints — instead of merely
// slowing down.
//
// Two detectors, because one is not enough:
//   1. TasksModel / IsFullScreen — catches real fullscreen windows. Idiom
//      lifted from Panel Colorizer's TasksModel.qml, which is the proven
//      working shape on Plasma 6 (data(index, role) with roles pulled off
//      AbstractTasksModel).
//   2. gamemoded -s — catches BORDERLESS-WINDOWED games, which are not
//      fullscreen windows at all. Nobara/Steam run games through gamemoderun,
//      so gamemode's own status is the honest signal there. Polled every 60 s
//      (watching D-Bus from QML would need a permanently attached listener),
//      and NOT polled at all while a fullscreen window is already up.
//
// Deliberately NOT included: "is the widget visible". Plasma does not hide
// desktop widgets behind a fullscreen window, so visibility is no signal at all.
// =============================================================================

import QtQuick
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager

Item {
    id: guard

    // Screen to watch. Pass Plasmoid.containment.screenGeometry when the
    // containment knows it; empty means "every screen counts".
    property rect screenGeometry: Qt.rect(0, 0, 0, 0)
    property bool watchGamemode: true

    readonly property bool fullscreenExists: fullscreenCount > 0
    readonly property bool paused: fullscreenExists || gamemodeActive

    // BOTH detectors are asynchronous: TasksModel populates over the event
    // loop and `gamemoded -s` is a spawned process. So at component completion
    // `paused` is structurally false — not "measured false" — and anything
    // that fires on start (a poll timer with triggeredOnStart, a first fetch)
    // would run once even when a game already owns the screen. Consumers must
    // wait for `ready` before their first shot.
    property bool ready: false

    property int fullscreenCount: 0
    property bool gamemodeActive: false

    // Something went from paused -> running again: widgets use this to refresh
    // once immediately instead of waiting out their normal interval.
    signal resumed()

    onPausedChanged: if (!paused) guard.resumed()

    readonly property var _roles: TaskManager.AbstractTasksModel

    function _update() {
        let count = 0;
        for (let i = 0; i < tasksModel.count; i++) {
            const idx = tasksModel.index(i, 0);
            if (idx === undefined || !tasksModel.data(idx, guard._roles.IsWindow))
                continue;
            if (tasksModel.data(idx, guard._roles.IsFullScreen))
                count += 1;
        }
        guard.fullscreenCount = count;
    }

    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }

    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasksModel

        sortMode: TaskManager.TasksModel.SortVirtualDesktop
        groupMode: TaskManager.TasksModel.GroupDisabled
        activity: activityInfo.currentActivity
        screenGeometry: guard.screenGeometry
        filterByScreen: guard.screenGeometry.width > 0
        filterByActivity: true
        filterMinimized: true

        onDataChanged: Qt.callLater(guard._update)
        onCountChanged: Qt.callLater(guard._update)
    }

    // --- gamemode ------------------------------------------------------------
    P5Support.DataSource {
        id: gamemodeSource
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            // "gamemode is active" / "gamemode is inactive" / "gamemode not running"
            guard.gamemodeActive = String(data["stdout"] || "").indexOf(" is active") !== -1;
            guard.ready = true;
        }
    }

    // Gated on fullscreenExists, NOT on paused: while a fullscreen window is up
    // the push-driven TasksModel signal already holds `paused`, so polling adds
    // nothing but process spawns — exactly what the rule forbids. Gating on
    // `paused` instead would strand a gamemode-only pause with nothing left
    // running to ever clear it.
    Timer {
        interval: 60000
        repeat: true
        running: guard.watchGamemode && !guard.fullscreenExists
        triggeredOnStart: true
        onTriggered: {
            if (gamemodeSource.connectedSources.length > 0)
                return;                                  // previous check still running
            gamemodeSource.connectSource("gamemoded -s 2>/dev/null");
        }
    }

    // Fallback readiness for a box with no gamemoded installed (the DataSource
    // then never returns and `ready` would stay false forever).
    Timer {
        interval: 2000
        repeat: false
        running: true
        onTriggered: guard.ready = true
    }

    Component.onCompleted: guard._update()
}
