import QtQuick
import QtQuick.Controls

Window {
    id: autoSortWindow
    title: "Meridian — Auto-Sort"
    width:  620
    height: 560
    minimumWidth:  520
    minimumHeight: 460

    SystemPalette { id: pal; colorGroup: SystemPalette.Active }
    color: pal.window

    function formatMetric(value, digits) {
        return value.toFixed(digits === undefined ? 2 : digits)
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: autoSortWindow.width
            spacing: 14
            topPadding: 20
            bottomPadding: 20
            leftPadding: 20
            rightPadding: 20

            Text {
                text: "Auto-Sort"
                font.pixelSize: 24; font.bold: true
                color: pal.windowText
            }
            Text {
                width: parent.width - 40
                wrapMode: Text.WordWrap
                color: pal.placeholderText
                font.pixelSize: 13
                text: "Automatic frame culling identifies frames measurably worse than a good " +
                      "control image you choose. Nothing is rejected automatically — this screen " +
                      "currently analyzes a single control image; batch comparison against the " +
                      "rest of your frames comes next."
            }

            Rectangle {
                width: parent.width - 40
                height: 1
                color: pal.mid
            }

            Text {
                text: "1. Select Control Image"
                font.pixelSize: 16; font.bold: true
                color: pal.windowText
            }

            Row {
                spacing: 10
                Button {
                    text: "Choose Control Image…"
                    enabled: !cullingService.analyzing
                    onClicked: {
                        var path = cullingService.selectControlImage()
                        if (path !== "")
                            cullingService.analyzeControl(path)
                    }
                }
                BusyIndicator {
                    implicitWidth: 24
                    implicitHeight: 24
                    running: cullingService.analyzing
                    visible: running
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Analyzing…"
                    visible: cullingService.analyzing
                    color: pal.placeholderText
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                visible: cullingService.controlPath !== ""
                width: parent.width - 40
                wrapMode: Text.WrapAnywhere
                color: pal.placeholderText
                font.pixelSize: 11
                text: cullingService.controlPath
            }

            Rectangle {
                visible: cullingService.controlWarning !== ""
                width: parent.width - 40
                height: warningText.implicitHeight + 20
                color: "#3a2f14"
                border.color: "#8a6d1f"
                border.width: 1
                radius: 6

                Text {
                    id: warningText
                    anchors.fill: parent
                    anchors.margins: 10
                    wrapMode: Text.WordWrap
                    color: "#e5ad4f"
                    font.pixelSize: 13
                    text: "⚠ " + cullingService.controlWarning
                }
            }

            Rectangle {
                visible: cullingService.controlValid
                width: parent.width - 40
                height: metricsCol.height + 24
                color: pal.alternateBase
                border.color: pal.mid
                border.width: 1
                radius: 6

                Column {
                    id: metricsCol
                    anchors.top:  parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        text: "Control Baseline"
                        font.pixelSize: 14; font.bold: true
                        color: pal.windowText
                    }

                    Repeater {
                        model: [
                            { label: "Stars detected",     value: cullingService.controlStarCount },
                            { label: "Usable stars",        value: cullingService.controlUsableStarCount },
                            { label: "Median FWHM",          value: autoSortWindow.formatMetric(cullingService.controlFwhm) + " px" },
                            { label: "Median star flux",     value: autoSortWindow.formatMetric(cullingService.controlFlux, 1) + " ADU" },
                            { label: "Median eccentricity",  value: autoSortWindow.formatMetric(cullingService.controlEccentricity, 3) },
                            { label: "Background level",     value: autoSortWindow.formatMetric(cullingService.controlBackgroundLevel, 1) + " ADU" },
                            { label: "Background noise",     value: autoSortWindow.formatMetric(cullingService.controlBackgroundNoise, 2) + " ADU" }
                        ]
                        delegate: Row {
                            width: metricsCol.width
                            Text {
                                width: parent.width * 0.55
                                text: modelData.label
                                color: pal.placeholderText
                                font.pixelSize: 13
                            }
                            Text {
                                text: modelData.value
                                color: pal.windowText
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}
