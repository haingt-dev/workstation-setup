// =============================================================================
// dev.haint.dashboard — Material 3 Expressive desktop dashboard
// =============================================================================
// Replaces the old "Reactor HUD" sci-fi widget. Desktop-only (NoBackground,
// user can still opt into ConfigurableBackground from the widget settings).
// Layout is a plain top-to-bottom column: clock (no card) → 2x2 stat grid →
// wide weather chip. Everything downstream of GameGuard.paused so the widget
// costs nothing while a game/fullscreen app owns the screen.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

import "."

PlasmoidItem {
    id: root

    // No plasma panel-strip background — the cards themselves carry Tokens.card,
    // but leave ConfigurableBackground so Hải can turn a background on from the
    // widget's own settings without us hardcoding one.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    preferredRepresentation: fullRepresentation

    implicitWidth: 480
    // fullRepresentationItem is the live instance Plasma creates from the
    // fullRepresentation component below — bind to ITS implicitHeight so the
    // containment cell always matches the column's real content height.
    implicitHeight: root.fullRepresentationItem ? root.fullRepresentationItem.implicitHeight : 400

    // Single instance shared by every child via property binding — one D-Bus/
    // TasksModel watch for the whole widget, not one per card.
    GameGuard {
        id: gameGuard
        screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
    }

    fullRepresentation: Item {
        id: fullRoot
        implicitWidth: 480
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 10

            ClockCard {
                Layout.fillWidth: true
                guard: gameGuard
            }

            StatGrid {
                Layout.fillWidth: true
                guard: gameGuard
            }

            WeatherCard {
                Layout.fillWidth: true
                guard: gameGuard
            }
        }
    }
}
