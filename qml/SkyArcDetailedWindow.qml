import QtQuick
import QtQuick.Controls

Window {
    id: skyArcDetailedWindow
    title: "Sky Arc Detailed"
    width:  1100
    height: 800
    minimumWidth:  800
    minimumHeight: 600

    SystemPalette { id: pal; colorGroup: SystemPalette.Active }
    color: pal.window

    property real latitude:  0.0
    property real longitude: 0.0
    property int  nightOffset: 0
    readonly property bool hasLocation: (latitude !== 0.0 || longitude !== 0.0)

    Rectangle {
        id: headerBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 52
        color: pal.alternateBase

        Row {
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 12

            Text {
                text: "Sky Arc — Detailed View"
                font.pixelSize: 17; font.bold: true; color: pal.windowText
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle { width: 1; height: 28; color: pal.mid; anchors.verticalCenter: parent.verticalCenter }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: skyArcDetailedWindow.hasLocation
                      ? ("Lat " + skyArcDetailedWindow.latitude.toFixed(4)
                         + "°  ·  Lon " + skyArcDetailedWindow.longitude.toFixed(4) + "°")
                      : "No location set"
                font.pixelSize: 13
                color: skyArcDetailedWindow.hasLocation ? pal.windowText : pal.placeholderText
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 6

            Button { text: "Zoom In";    flat: true; enabled: false; implicitHeight: 28 }
            Button { text: "Zoom Out";   flat: true; enabled: false; implicitHeight: 28 }
            Button { text: "Reset View"; flat: true; enabled: false; implicitHeight: 28 }
            Button { text: "Grid";       flat: true; enabled: false; implicitHeight: 28; checkable: true }
        }
    }

    Item {
        id: domeArea
        anchors { top: headerBar.bottom; left: parent.left; right: featurePanel.left; bottom: parent.bottom }

        Canvas {
            id: domePlaceholder
            anchors.fill: parent
            anchors.margins: 24

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var cx = width / 2
                var cy = height / 2
                var radius = Math.max(10, Math.min(width, height) / 2 - 30)

                ctx.strokeStyle = pal.mid.toString()
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
                ctx.stroke()

                ctx.setLineDash([2, 6])
                for (var f = 1; f <= 2; f++) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, radius * f / 3, 0, 2 * Math.PI)
                    ctx.stroke()
                }
                ctx.setLineDash([])

                ctx.beginPath()
                ctx.moveTo(cx - radius, cy); ctx.lineTo(cx + radius, cy)
                ctx.moveTo(cx, cy - radius); ctx.lineTo(cx, cy + radius)
                ctx.stroke()

                ctx.fillStyle = pal.placeholderText.toString()
                ctx.font = "13px sans-serif"
                ctx.textAlign = "center"
                ctx.fillText("N", cx, cy - radius - 10)
                ctx.fillText("S", cx, cy + radius + 18)
                ctx.textAlign = "left"
                ctx.fillText("E", cx + radius + 8, cy + 4)
                ctx.textAlign = "right"
                ctx.fillText("W", cx - radius - 8, cy + 4)

                ctx.textAlign = "center"
                ctx.fillStyle = pal.windowText.toString()
                ctx.font = "16px sans-serif"
                ctx.fillText("360° Sky Dome", cx, cy - 8)
                ctx.fillStyle = pal.placeholderText.toString()
                ctx.font = "12px sans-serif"
                ctx.fillText("Interactive view — coming soon", cx, cy + 14)
            }

            Connections {
                target: skyArcDetailedWindow
                function onWidthChanged()  { domePlaceholder.requestPaint() }
                function onHeightChanged() { domePlaceholder.requestPaint() }
            }
        }
    }

    Rectangle {
        id: featurePanel
        anchors { top: headerBar.bottom; right: parent.right; bottom: parent.bottom }
        width: 320
        color: Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.04)

        Rectangle {
            anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
            width: 1; color: pal.mid
        }

        Column {
            anchors { fill: parent; margins: 20 }
            spacing: 14

            Text {
                text: "Upcoming Feature"
                font.pixelSize: 11; font.bold: true; color: pal.placeholderText
            }

            Text {
                width: parent.width
                text: "A full 360° interactive sky dome, in the style of KStars and other planetarium tools."
                font.pixelSize: 14; font.bold: true; color: pal.windowText
                wrapMode: Text.WordWrap
            }

            Rectangle { width: parent.width; height: 1; color: pal.mid }

            Text {
                text: "Planned capabilities"
                font.pixelSize: 11; font.bold: true; color: pal.placeholderText
            }

            Column {
                width: parent.width
                spacing: 8

                Repeater {
                    model: [
                        "Pan and zoom across the whole sky dome",
                        "Live positions from your location and timezone",
                        "Horizon, altitude and azimuth grid overlays",
                        "Cardinal directions and meridian reference",
                        "Overlay of previously collected target data",
                        "Selectable objects linked back to the planner"
                    ]
                    delegate: Row {
                        required property string modelData
                        width: featurePanel.width - 40
                        spacing: 8

                        Text { text: "•"; font.pixelSize: 13; color: pal.highlight }
                        Text {
                            width: parent.width - 18
                            text: modelData
                            font.pixelSize: 12; color: pal.windowText
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
