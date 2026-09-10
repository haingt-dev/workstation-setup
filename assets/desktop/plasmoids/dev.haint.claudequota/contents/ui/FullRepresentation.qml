// Expanded popup: heading + one row per quota window (session / weekly /
// weekly-per-model), each with a progress bar and a reset countdown.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "."

PlasmaExtras.Representation {
    id: full

    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: Kirigami.Units.gridUnit * 10
    Layout.preferredWidth: Kirigami.Units.gridUnit * 18

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 4
                elide: Text.ElideRight
                text: "Claude Code" + (root.plan ? " · " + root.plan : "")
            }

            PlasmaComponents.Label {
                // "stale, 0 min ago" is what a failure with no cache behind it
                // used to read as — stale is true, but there is nothing old to
                // be stale about. Say so instead.
                text: !root.hasData
                    ? "no data yet"
                    : (root.stale
                        ? "stale, " + Math.round(root.ageSec / 60) + " min ago"
                        : (root.now - root.fetchedAt < 60 ? "live" : Math.round((root.now - root.fetchedAt) / 60) + " min ago"))
                opacity: 0.7
                font: Kirigami.Theme.smallFont
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                enabled: !root.busy
                onClicked: root.refresh(true)
                PlasmaComponents.ToolTip.text: "Refresh now"
                PlasmaComponents.ToolTip.visible: hovered
            }

            // Duplicated from Plasmoid.contextualActions on purpose: this is a
            // custom heading, not BasicPlasmoidHeading, so it has no hamburger
            // and the contextual actions are only reachable by right-clicking
            // the dock icon.
            PlasmaComponents.ToolButton {
                icon.name: "internet-web-browser"
                onClicked: Qt.openUrlExternally("https://claude.ai/settings/usage")
                PlasmaComponents.ToolTip.text: "Open usage page"
                PlasmaComponents.ToolTip.visible: hovered
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        PlasmaExtras.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.hasData
            // No network yet is the normal state for the first seconds after a
            // cold boot, so it gets a plug icon and a "will retry" line — not
            // the red X that says something is broken.
            iconName: root.errorKind === "offline" ? "network-disconnect"
                : (root.errorText ? "data-error" : "hourglass")
            text: root.errorText || "Fetching quota…"
            explanation: root.errorKind === "offline" ? "Will retry when the network is up." : ""
        }

        Repeater {
            model: root.limits
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: root.hasData
                spacing: Kirigami.Units.smallSpacing / 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: (modelData.active ? "▸ " : "  ") + modelData.label
                        font.bold: modelData.active
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.Label {
                        text: modelData.percent + "%"
                        font.bold: true
                        color: Tokens.severityColor(modelData.percent)
                    }
                }

                // Drawn by hand rather than PlasmaComponents.ProgressBar: that
                // control's groove and fill are KSvg FrameSvgItems sized from
                // the theme's own hint-bar-size, so `implicitHeight: 6` only
                // shrinks the control's box, not the bar inside it — and the
                // fill colour would be the theme highlight, not our severity
                // ramp. Two Rectangles give the exact height AND the colour
                // the compact gauge already uses.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: Tokens.surfaceContainerHigh

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, modelData.percent)) / 100
                        height: parent.height
                        radius: parent.radius
                        color: Tokens.severityColor(modelData.percent)
                    }
                }

                PlasmaComponents.Label {
                    text: "resets in " + full.formatRemaining(modelData.resetsAt)
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                }
            }
        }
    }

    // Depends on root.now (ticked by main.qml's clockTimer) so it re-renders
    // without any network activity of its own.
    function formatRemaining(resetsAtEpoch) {
        if (!resetsAtEpoch) return "?";
        const secs = Math.max(0, resetsAtEpoch - root.now);
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h + "h " + m + "m";
    }
}
