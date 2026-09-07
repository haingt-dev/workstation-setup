// =============================================================================
// WeatherCard.qml — full-width chip: temp, condition, feels-like/humidity/wind,
// sunrise-sunset. Backed by contents/tools/weather.py (open-meteo, cached).
// =============================================================================
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

import "."

Rectangle {
    id: root
    property var guard   // set by main.qml; must NOT be named gameGuard (would shadow the outer id)

    radius: 22
    color: Tokens.card
    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + 32

    // NOT named `data`: Item.data is the default property holding an item's
    // CHILDREN, so `property var data` silently replaces the children list and
    // the card renders as an empty box. Plasma only whispers about it
    // ("Member data ... overrides a member of the base object").
    property var wx: ({ ok: false, text: "Đang tải...", icon: "weather-none-available" })

    // decodeURIComponent + quotes: Qt percent-encodes the URL and the
    // executable engine splits with KShell::splitArgs, so a space in $HOME
    // would otherwise arrive as a literal %20.
    readonly property string weatherCmd: "python3 '" +
        decodeURIComponent(Qt.resolvedUrl("../tools/weather.py").toString().replace("file://", "")) + "'"

    P5Support.DataSource {
        id: weatherSrc
        engine: "executable"
        connectedSources: []
        onNewData: (source, out) => {
            disconnectSource(source);
            wxWatchdog.stop();
            try {
                root.wx = JSON.parse(out["stdout"] || "{}");
            } catch (e) {
                // Keep whatever we had — weather.py itself never emits a
                // traceback, so a parse failure here means truncated stdout,
                // not a Python crash. Worth surviving quietly either way.
            }
        }
    }

    // Without this, a weather.py that never exits (DNS black-holed by a VPN
    // toggle is the realistic case — urlopen's timeout does not cover
    // getaddrinfo) leaves the source connected forever, and poll()'s
    // "already running" guard then makes every later refresh a no-op.
    Timer {
        id: wxWatchdog
        interval: 30000
        repeat: false
        onTriggered: {
            if (weatherSrc.connectedSources.length > 0)
                weatherSrc.disconnectSource(weatherSrc.connectedSources[0]);
        }
    }

    function poll() {
        if (weatherSrc.connectedSources.length > 0)
            return;
        weatherSrc.connectSource(root.weatherCmd);
        wxWatchdog.restart();
    }

    Timer {
        interval: 20 * 60 * 1000
        repeat: true
        triggeredOnStart: true
        running: !!root.guard && !root.guard.paused
        onTriggered: root.poll()
    }

    Connections {
        target: root.guard
        function onResumed() { root.poll(); }
    }

    // Plain positioners (Row/Column), NOT RowLayout/ColumnLayout. A Layout only
    // arranges its children when something gives IT a size; standalone inside a
    // Rectangle it stayed 0-high and the whole card rendered as an empty box.
    // StatCard.qml uses the same Column-in-a-Rectangle shape for the same reason.
    Row {
        id: inner
        x: 16
        y: 16
        spacing: 16

        Kirigami.Icon {
            id: icon
            width: 40
            height: 40
            source: root.wx.icon || "weather-none-available"
            // isMask makes `color` actually apply — otherwise a full-colour
            // weather icon lands in an otherwise single-hue design.
            isMask: true
            color: Tokens.tertiary
        }

        Column {
            width: root.width - 32 - icon.width - inner.spacing
            spacing: 3

            Row {
                spacing: 10

                Text {
                    text: (root.wx.ok || root.wx.stale)
                        ? Math.round(root.wx.temp) + "°"
                        : "--°"
                    color: Tokens.tertiary
                    font.family: "Manrope"
                    font.weight: Font.Black
                    font.pixelSize: 26
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.wx.text || ""
                    color: Tokens.fgSurface
                    font.pixelSize: 15
                }
            }

            Text {
                visible: text.length > 0
                width: parent.width
                elide: Text.ElideRight
                text: (root.wx.ok || root.wx.stale)
                    ? "Cảm giác như " + Math.round(root.wx.feels) + "°"
                      + " · Ẩm " + root.wx.humidity + "%"
                      + " · Gió " + Math.round(root.wx.wind) + " km/h"
                    : ""
                color: Tokens.fgSurfaceVariant
                font.pixelSize: 12
            }

            Text {
                visible: text.length > 0
                width: parent.width
                elide: Text.ElideRight
                text: (root.wx.ok || root.wx.stale)
                    ? "Mặt trời mọc " + root.wx.sunrise + " · lặn " + root.wx.sunset
                      + (root.wx.stale ? "  (dữ liệu cũ)" : "")
                    : ""
                color: Tokens.outline
                font.pixelSize: 11
            }
        }
    }
}
