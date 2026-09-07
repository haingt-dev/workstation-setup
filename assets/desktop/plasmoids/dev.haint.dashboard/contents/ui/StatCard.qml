// =============================================================================
// StatCard.qml — one Material 3 tonal card: icon chip, big value, small detail
// =============================================================================
// Presentational only — StatGrid.qml owns every Sensor/DataSource and just
// hands this component strings. Height always follows content (implicit),
// never stretched by the GridLayout cell, per the "nothing may clip/stretch"
// rule.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "."

Rectangle {
    id: root

    property string iconName: ""
    property string value: "--"
    property string secondary: ""

    radius: 22
    color: Tokens.card
    implicitWidth: 200
    implicitHeight: inner.implicitHeight + 36

    Column {
        id: inner
        anchors.centerIn: parent
        width: parent.width - 36
        spacing: 8

        Rectangle {
            width: 32; height: 32
            radius: 8
            color: Tokens.primaryContainer
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 18; height: 18
                source: root.iconName
                // isMask is what actually makes `color` apply: without it a
                // full-colour Papirus icon is drawn as-is and the card ends up
                // with a stray blue/green blob in an otherwise one-hue design.
                isMask: true
                color: Tokens.fgPrimaryContainer
            }
        }

        Text {
            width: parent.width
            text: root.value
            color: Tokens.primary
            font.family: "Manrope"
            font.weight: Font.Black
            font.pixelSize: 26
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.secondary
            color: Tokens.fgSurfaceVariant
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
