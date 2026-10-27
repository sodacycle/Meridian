import QtQuick
import QtQuick.Controls

Item {
    id: settingsView

    // The settings object these controls read and write. Defaults to the live
    // app-wide settings (the viewer's own Settings tab edits them directly); the
    // Preferences window passes a draft instead so edits are only kept on Save.
    property var model: appSettings

    property string heading: "Settings"
    property bool   showHeading: true
    property bool   showReset: true

    readonly property color card:    "#2a2a2a"
    readonly property color divider: "#3a3a3a"
    readonly property color primary: "#e8e8e8"
    readonly property color label:   "#cfcfcf"
    readonly property color muted:   "#9a9a9a"

    implicitHeight: col.implicitHeight

    Rectangle { anchors.fill: parent; color: "#1b1b1b" }

    Column {
        id: col
        width: settingsView.width
        spacing: 16
        padding: 24

            Text {
                text: settingsView.heading; font.pixelSize: 20; font.bold: true
                color: settingsView.primary; visible: settingsView.showHeading
            }

            Rectangle {
                width: parent.width - 48
                height: autoCol.height + 32
                color: settingsView.card; border.color: settingsView.divider; border.width: 1; radius: 6

                Column {
                    id: autoCol
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 10

                    Text { text: "Auto-Sort defaults"; font.pixelSize: 14; font.bold: true; color: settingsView.primary }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "The starting metrics and sensitivity used when you Analyze frames in the Culling tab."
                        color: settingsView.muted; font.pixelSize: 11
                    }

                    Text { text: "Metrics to weigh"; color: settingsView.label; font.pixelSize: 12 }
                    CheckBox { text: "Star Count";        checked: settingsView.model.cullStarCount;  onToggled: settingsView.model.cullStarCount = checked;  font.pixelSize: 13 }
                    CheckBox { text: "Star Brightness";   checked: settingsView.model.cullBrightness; onToggled: settingsView.model.cullBrightness = checked; font.pixelSize: 13 }
                    CheckBox { text: "FWHM";              checked: settingsView.model.cullFwhm;       onToggled: settingsView.model.cullFwhm = checked;       font.pixelSize: 13 }
                    CheckBox { text: "Star Eccentricity"; checked: settingsView.model.cullEcc;        onToggled: settingsView.model.cullEcc = checked;        font.pixelSize: 13 }
                    CheckBox { text: "Background Noise";  checked: settingsView.model.cullNoise;      onToggled: settingsView.model.cullNoise = checked;      font.pixelSize: 13 }

                    Rectangle { width: parent.width; height: 1; color: settingsView.divider }

                    Text { text: "Default sensitivity"; color: settingsView.label; font.pixelSize: 12 }
                    Row {
                        spacing: 18
                        RadioButton { text: "Conservative"; checked: settingsView.model.cullSensitivity === "conservative"; onToggled: if (checked) settingsView.model.cullSensitivity = "conservative"; font.pixelSize: 13 }
                        RadioButton { text: "Balanced";     checked: settingsView.model.cullSensitivity === "balanced";     onToggled: if (checked) settingsView.model.cullSensitivity = "balanced"; font.pixelSize: 13 }
                        RadioButton { text: "Aggressive";   checked: settingsView.model.cullSensitivity === "aggressive";   onToggled: if (checked) settingsView.model.cullSensitivity = "aggressive"; font.pixelSize: 13 }
                        RadioButton { text: "Custom";       checked: settingsView.model.cullSensitivity === "custom";       onToggled: if (checked) settingsView.model.cullSensitivity = "custom"; font.pixelSize: 13 }
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "Custom per-metric thresholds are edited on the Culling tab's Analyze screen."
                        color: settingsView.muted; font.pixelSize: 11
                        visible: settingsView.model.cullSensitivity === "custom"
                    }
                }
            }

            Rectangle {
                width: parent.width - 48
                height: stretchCol.height + 32
                color: settingsView.card; border.color: settingsView.divider; border.width: 1; radius: 6

                Column {
                    id: stretchCol
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 14

                    Text { text: "Image stretch limits"; font.pixelSize: 14; font.bold: true; color: settingsView.primary }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "The range of the Stretch, Clip, and Denoise sliders in the Viewer tab."
                        color: settingsView.muted; font.pixelSize: 11
                    }

                    Column {
                        width: parent.width; spacing: 2
                        Row {
                            width: parent.width
                            Text { width: parent.width - v1.width; text: "Stretch (a) minimum"; color: settingsView.label; font.pixelSize: 12 }
                            Text { id: v1; text: settingsView.model.stretchMin.toFixed(3); color: settingsView.primary; font.pixelSize: 12; font.family: "monospace" }
                        }
                        Slider { width: parent.width; from: 0.001; to: 0.5; stepSize: 0.001; value: settingsView.model.stretchMin; onMoved: settingsView.model.stretchMin = value }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        Row {
                            width: parent.width
                            Text { width: parent.width - v2.width; text: "Stretch (a) maximum"; color: settingsView.label; font.pixelSize: 12 }
                            Text { id: v2; text: settingsView.model.stretchMax.toFixed(2); color: settingsView.primary; font.pixelSize: 12; font.family: "monospace" }
                        }
                        Slider { width: parent.width; from: 0.5; to: 5.0; stepSize: 0.1; value: settingsView.model.stretchMax; onMoved: settingsView.model.stretchMax = value }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        Row {
                            width: parent.width
                            Text { width: parent.width - v3.width; text: "Clip minimum (%)"; color: settingsView.label; font.pixelSize: 12 }
                            Text { id: v3; text: settingsView.model.clipMin.toFixed(1); color: settingsView.primary; font.pixelSize: 12; font.family: "monospace" }
                        }
                        Slider { width: parent.width; from: 70.0; to: 99.0; stepSize: 0.5; value: settingsView.model.clipMin; onMoved: settingsView.model.clipMin = value }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        Row {
                            width: parent.width
                            Text { width: parent.width - v4.width; text: "Clip maximum (%)"; color: settingsView.label; font.pixelSize: 12 }
                            Text { id: v4; text: settingsView.model.clipMax.toFixed(1); color: settingsView.primary; font.pixelSize: 12; font.family: "monospace" }
                        }
                        Slider { width: parent.width; from: 95.0; to: 100.0; stepSize: 0.1; value: settingsView.model.clipMax; onMoved: settingsView.model.clipMax = value }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        Row {
                            width: parent.width
                            Text { width: parent.width - v5.width; text: "Denoise maximum radius"; color: settingsView.label; font.pixelSize: 12 }
                            Text { id: v5; text: settingsView.model.denoiseMax; color: settingsView.primary; font.pixelSize: 12; font.family: "monospace" }
                        }
                        Slider { width: parent.width; from: 1; to: 10; stepSize: 1; value: settingsView.model.denoiseMax; onMoved: settingsView.model.denoiseMax = Math.round(value) }
                    }
                }
            }

        Button {
            text: "Reset to defaults"
            visible: settingsView.showReset
            onClicked: settingsView.model.resetViewerDefaults()
        }
    }
}
