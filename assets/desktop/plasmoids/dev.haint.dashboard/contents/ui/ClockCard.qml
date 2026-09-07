// =============================================================================
// ClockCard.qml — big time, no card behind it (floats over the wallpaper)
// =============================================================================
// The wallpaper can be bright under a light Firewatch-dusk sky, so onSurface
// text alone can wash out. A second Text underneath, offset by a couple of px
// and inked in solid black at low opacity, fakes a soft drop shadow without
// touching a layer.effect (banned by the zero-cost-while-gaming rule — a
// layer effect keeps its own FBO alive and repaints every frame it's dirty).
// =============================================================================
import QtQuick
import QtQuick.Layouts

import "."

ColumnLayout {
    id: root
    property var guard   // set by main.qml; must NOT be named gameGuard (would shadow the outer id)

    spacing: 2

    readonly property date now: new Date()
    property string timeText: Qt.formatTime(now, "hh:mm")
    property string dateText: Qt.locale("vi_VN").toString(now, "dddd, d MMMM")

    function refresh() {
        const d = new Date();
        timeText = Qt.formatTime(d, "hh:mm");
        dateText = Qt.locale("vi_VN").toString(d, "dddd, d MMMM");
    }

    // Aligns the recurring tick to the wall-clock minute boundary, then hands
    // off to a steady 60s timer — without this the clock's minute flip drifts
    // further from :00 every time Plasma restarts the widget.
    // The offset has to be RECOMPUTED every time we re-arm: a declarative
    // `interval:` binding with no reactive dependency is evaluated once at
    // creation, so after a game exits at :47 the clock would keep flipping at
    // whatever second the widget happened to be built at.
    Timer {
        id: alignTimer
        interval: 60000
        repeat: false
        running: false
        onTriggered: {
            root.refresh();
            minuteTimer.restart();
        }
    }

    function realign() {
        const d = new Date();
        alignTimer.interval = 60000 - (d.getSeconds() * 1000 + d.getMilliseconds());
        alignTimer.restart();
    }

    Component.onCompleted: if (!!root.guard && !root.guard.paused) realign()

    Timer {
        id: minuteTimer
        interval: 60000
        repeat: true
        // Gated like every other timer per the zero-cost rule; alignTimer's
        // restart() just re-phases its countdown to the next :00 boundary
        // once gaming stops, it doesn't own whether this one runs at all.
        running: !!root.guard && !root.guard.paused
        onTriggered: root.refresh()
    }

    Connections {
        target: root.guard
        function onResumed() { root.refresh(); root.realign(); }
    }

    // Manrope's heaviest face is ExtraBold (800) — there is no Black. Asking
    // for Font.Black just makes Qt fall back to the same face, so the weight
    // that is actually shipped is the one requested.
    // The clock sits directly on the wallpaper with no card behind it, so it
    // needs its own contrast: a black copy offset by 2/3px underneath.
    // NOTE anchors.fill would copy the shadow's POSITION as well as its size
    // and stack the two glyphs exactly on top of each other — the shadow has
    // to be positioned explicitly, and the box needs room for the offset.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: timeMain.implicitHeight + 3

        Text {
            id: timeShadow
            x: 2
            y: 3
            text: root.timeText
            color: "#000000"
            opacity: 0.28
            font.family: "Manrope"
            font.weight: Font.ExtraBold
            font.pixelSize: 68
        }
        Text {
            id: timeMain
            x: 0
            y: 0
            text: root.timeText
            color: Tokens.fgSurface
            font.family: "Manrope"
            font.weight: Font.ExtraBold
            font.pixelSize: 68
        }
    }

    Text {
        Layout.fillWidth: true
        text: root.dateText
        color: Tokens.fgSurfaceVariant
        font.pixelSize: 16
        elide: Text.ElideRight
    }
}
