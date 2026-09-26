import QtQuick
import QtQuick.Controls

Item {
    id: settingsView

    property var viewer
    property var culling

    readonly property color card:    "#2a2a2a"
    readonly property color divider: "#3a3a3a"
    readonly property color primary: "#e8e8e8"
    readonly property color label:   "#cfcfcf"
    readonly property color muted:   "#9a9a9a"

    Rectangle { anchors.fill: parent; color: "#1b1b1b" }

    ScrollView {
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: settingsView.width
            spacing: 16
            padding: 24

            Text { text: "Settings"; font.pixelSize: 20; font.bold: true; color: settingsView.primary }

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
                    CheckBox { text: "Star Count";        checked: settingsView.culling.mStarcount;    onToggled: settingsView.culling.mStarcount = checked;    font.pixelSize: 13 }
                    CheckBox { text: "Star Brightness";   checked: settingsView.culling.mBrightness;   onToggled: settingsView.culling.mBrightness = checked;   font.pixelSize: 13 }
                    CheckBox { text: "FWHM";              checked: settingsView.culling.mFwhm;         onToggled: settingsView.culling.mFwhm = checked;         font.pixelSize: 13 }
                    CheckBox { text: "Star Eccentricity"; checked: settingsView.culling.mEccentricity; onToggled: settingsView.culling.mEccentricity = checked; font.pixelSize: 13 }
                    CheckBox { text: "Background Noise";  checked: settingsView.culling.mNoise;        onToggled: settingsView.culling.mNoise = checked;        font.pixelSize: 13 }

                    Rectangle { width: parent.width; height: 1; color: settingsView.divider }

                    Text { text: "Default sensitivity"; color: settingsView.label; font.pixelSize: 12 }
                    Row {
                        spacing: 18
                        RadioButton { text: "Conservative"; checked: settingsView.culling.sensitivity === "conservative"; onToggled: if (checked) settingsView.culling.sensitivity = "conservative"; font.pixelSize: 13 }
                        RadioButton { text: "Balanced";     checked: settingsView.culling.sensitivity === "balanced";     onToggled: if (checked) settingsView.culling.sensitivity = "balanced"; font.pixelSize: 13 }
                        RadioButton { text: "Aggressive";   checked: settingsView.culling.sensitivity === "aggressive";   onToggled: if (checked) settingsView.culling.sensitivity = "aggressive"; font.pixelSize: 13 }
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
                            Text { id: v1; text: settingsView.viewer.stretchMin.toFixed(3); color: settingsView.primary; font.pixelSize: 12; font.family: "monospace" }
                        }
                        Slider { width: parent.width; from: 0.001; to: 0.5; stepSize: 0.001; value: settingsView.viewer.stretchMin; onMoved: settingsView.viewer.stretchMin = value }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        Row {
                            width: parent.width
                            Text { width: parent.width - v2.width; text: "Stretch (a) maximum"; color: settingsView.label; font.pixelSize: 12 }
                            Text { id: v2; text: settingsView.viewer.stretchMax.toFixed(2); color: settingsView.primary; font.pixelSize: 12; font.family: "monospace" }
                        }
                        Slider { width: parent.width; from: 0.5; to: 5.0; stepSize: 0.1; value: settingsView.viewer.stretchMax; onMoved: settingsView.viewer.stretchMax = value }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        Row {
                            width: parent.width
                            Text { width: parent.width - v3.width; text: "Clip minimum (%)"; color: settingsView.label; font.pixelSize: 12 }
                            Text { id: v3; text: settingsView.viewer.clipMin.toFixed(1); color: settingsView.primary; font.pixelSize: 12; font.family: "monospace" }
                        }
                        Slider { width: parent.width; from: 70.0; to: 99.0; stepSize: 0.5; value: settingsView.viewer.clipMin; onMoved: settingsView.viewer.clipMin = value }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        Row {
                            width: parent.width
                            Text { width: parent.width - v4.width; text: "Clip maximum (%)"; color: settingsView.label; font.pixelSize: 12 }
                            Text { id: v4; text: settingsView.viewer.clipMax.toFixed(1); color: settingsView.primary; font.pixelSize: 12; font.family: "monospace" }
                        }
                        Slider { width: parent.width; from: 95.0; to: 100.0; stepSize: 0.1; value: settingsView.viewer.clipMax; onMoved: settingsView.viewer.clipMax = value }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        Row {
                            width: parent.width
                            Text { width: parent.width - v5.width; text: "Denoise maximum radius"; color: settingsView.label; font.pixelSize: 12 }
                            Text { id: v5; text: settingsView.viewer.denoiseMax; color: settingsView.primary; font.pixelSize: 12; font.family: "monospace" }
                        }
                        Slider { width: parent.width; from: 1; to: 10; stepSize: 1; value: settingsView.viewer.denoiseMax; onMoved: settingsView.viewer.denoiseMax = Math.round(value) }
                    }
                }
            }

            Button {
                text: "Reset to defaults"
                onClicked: {
                    settingsView.viewer.stretchMin = 0.01
                    settingsView.viewer.stretchMax = 2.0
                    settingsView.viewer.clipMin = 90.0
                    settingsView.viewer.clipMax = 99.9
                    settingsView.viewer.denoiseMax = 5
                    settingsView.culling.sensitivity = "balanced"
                    settingsView.culling.mStarcount = true
                    settingsView.culling.mBrightness = true
                    settingsView.culling.mFwhm = true
                    settingsView.culling.mEccentricity = true
                    settingsView.culling.mNoise = true
                }
            }
        }
    }
}
