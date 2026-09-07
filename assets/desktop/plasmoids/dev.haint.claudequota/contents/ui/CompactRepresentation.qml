// Ring gauge + one mini-bar per limit window, sized for a 42px vertical dock
// (the applet itself gets ~40px). Everything here is read-only rendering of
// root's properties — no fetching happens in this file.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import "."

Item {
    id: compact

    // The ring tracks the 5-hour session window (see main.qml ringPercent);
    // the mini-bars below still carry every window, each in its own severity
    // colour, so the weekly limits never drop out of sight.
    readonly property real ringPercent: root.ringPercent
    readonly property color ringColor: ringPercent >= 0 ? Tokens.severityColor(ringPercent) : Tokens.outline
    readonly property bool dim: root.stale || !root.hasData

    Layout.minimumWidth: 32
    Layout.minimumHeight: 32
    Layout.preferredWidth: 40
    Layout.preferredHeight: 40

    opacity: dim ? 0.55 : 1.0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Column {
        anchors.centerIn: parent
        spacing: 2

        Item {
            id: ringHolder
            readonly property int ringSize: Math.min(compact.width, compact.height - miniBars.height - 4, 34)
            width: ringSize
            height: ringSize
            anchors.horizontalCenter: parent.horizontalCenter

            Canvas {
                id: ring
                anchors.fill: parent

                // Repaint only when what it draws actually changed (percent or
                // colour) — no looping animation, no per-frame repaint.
                Connections {
                    target: compact
                    function onRingPercentChanged() { ring.requestPaint(); }
                    function onRingColorChanged() { ring.requestPaint(); }
                }
                onWidthChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const size = width;
                    const stroke = Math.max(2, size * 0.105);
                    const r = (size - stroke) / 2;
                    const cx = size / 2, cy = size / 2;
                    const start = -Math.PI / 2; // 12 o'clock

                    ctx.lineWidth = stroke;
                    ctx.lineCap = "round";

                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.strokeStyle = Tokens.surfaceContainerHigh;
                    ctx.stroke();

                    const pct = Math.max(0, Math.min(100, compact.ringPercent));
                    if (compact.ringPercent >= 0 && pct > 0) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, start, start + (pct / 100) * 2 * Math.PI);
                        ctx.strokeStyle = compact.ringColor;
                        ctx.stroke();
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: compact.ringPercent >= 0 ? Math.round(compact.ringPercent).toString() : "—"
                font.bold: true
                font.pixelSize: Math.max(9, ringHolder.ringSize * 0.34)
                color: Tokens.fgSurface
            }
        }

        Row {
            id: miniBars
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 1
            readonly property int barCount: Math.max(1, root.limits.length)
            // Clamp each bar so N of them always fit the applet's width.
            readonly property real barW: Math.max(3, Math.min(9, (compact.width - (barCount - 1) * spacing) / barCount))

            Repeater {
                model: root.limits
                Rectangle {
                    width: miniBars.barW
                    height: 4
                    radius: 2
                    color: Tokens.severityColor(modelData.percent)
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.refresh(true);
            } else {
                root.expanded = !root.expanded;
            }
        }
    }
}
