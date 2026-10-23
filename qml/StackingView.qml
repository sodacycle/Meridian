import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var    candidatePaths: []
    property var    rejectedSet: ({})
    property string referencePath: ""
    property string targetName: ""

    signal openResultRequested(string path)

    function frameList() {
        var out = []
        for (var i = 0; i < candidatePaths.length; i++) {
            var p = candidatePaths[i]
            if (p && !rejectedSet[p]) out.push(p)
        }
        return out
    }

    readonly property int availableCount: frameList().length
    property string combineMethod: "average"
    property bool   alignFrames: true
    property string outputMode: "mono"

    Rectangle { anchors.fill: parent; color: "#1b1b1b" }

    Flickable {
        anchors.fill: parent
        anchors.margins: 20
        contentHeight: content.height
        clip: true

        Column {
            id: content
            width: parent.width
            spacing: 16

            Text {
                text: "Stacking"
                color: "#e8e8e8"; font.pixelSize: 20; font.bold: true
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#9a9a9a"; font.pixelSize: 12
                text: "Integrate the frames compatible with the open image "
                      + "(same target, filter, exposure and gear) into a single, deeper image. "
                      + "Rejected frames are left out automatically."
            }

            Rectangle {
                width: parent.width
                height: summaryCol.height + 24
                radius: 6; color: "#232323"; border.color: "#333333"; border.width: 1

                Column {
                    id: summaryCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 6

                    Row {
                        spacing: 8
                        Text { text: "Target:"; color: "#8a8a8a"; font.pixelSize: 12 }
                        Text {
                            text: root.targetName !== "" ? root.targetName : "(unknown)"
                            color: "#dddddd"; font.pixelSize: 12; font.bold: true
                        }
                    }
                    Row {
                        spacing: 8
                        Text { text: "Frames to stack:"; color: "#8a8a8a"; font.pixelSize: 12 }
                        Text {
                            text: root.availableCount + " of " + root.candidatePaths.length + " compatible"
                            color: "#dddddd"; font.pixelSize: 12; font.bold: true
                        }
                    }
                    Row {
                        spacing: 8
                        Text { text: "Reference:"; color: "#8a8a8a"; font.pixelSize: 12 }
                        Text {
                            width: summaryCol.width - 90
                            text: root.referencePath !== ""
                                  ? root.referencePath.split("/").pop() : "(first frame)"
                            color: "#dddddd"; font.pixelSize: 12
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 10

                Text { text: "Options"; color: "#cfcfcf"; font.pixelSize: 14; font.bold: true }

                CheckBox {
                    id: alignCheck
                    text: "Align frames (star-based)"
                    checked: root.alignFrames
                    onCheckedChanged: root.alignFrames = checked
                    enabled: !stackingService.stacking
                    contentItem: Text {
                        text: alignCheck.text
                        color: "#dddddd"; font.pixelSize: 13
                        leftPadding: alignCheck.indicator.width + 6
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Registers each frame to the reference by detecting stars and "
                          + "correcting for X/Y shift (dithering, small drift). Turn off only "
                          + "if the frames are already registered."
                    color: "#777777"; font.pixelSize: 11
                    leftPadding: 26
                }

                Row {
                    spacing: 16
                    Text {
                        text: "Combine:"; color: "#8a8a8a"; font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    RadioButton {
                        id: rbAverage
                        text: "Average"
                        checked: root.combineMethod === "average"
                        enabled: !stackingService.stacking
                        onCheckedChanged: if (checked) root.combineMethod = "average"
                        contentItem: Text {
                            text: rbAverage.text; color: "#dddddd"; font.pixelSize: 13
                            leftPadding: rbAverage.indicator.width + 6
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    RadioButton {
                        id: rbSigma
                        text: "Sigma-clipped average"
                        checked: root.combineMethod === "sigma"
                        enabled: !stackingService.stacking
                        onCheckedChanged: if (checked) root.combineMethod = "sigma"
                        contentItem: Text {
                            text: rbSigma.text; color: "#dddddd"; font.pixelSize: 13
                            leftPadding: rbSigma.indicator.width + 6
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: root.combineMethod === "sigma"
                          ? "Rejects per-pixel outliers (hot pixels, satellite/plane trails) "
                            + "beyond 3σ before averaging. Slower: reads each frame twice."
                          : "Plain mean of every frame. Fastest, but outliers survive into the result."
                    color: "#777777"; font.pixelSize: 11
                }

                Row {
                    spacing: 10
                    Text {
                        text: "Output:"; color: "#8a8a8a"; font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ComboBox {
                        id: outputCombo
                        width: 220
                        enabled: !stackingService.stacking
                        model: [
                            { label: "Mono (luminance)", value: "mono" },
                            { label: "Colour (RGB)",      value: "color" },
                            { label: "Red channel",       value: "r" },
                            { label: "Green channel",     value: "g" },
                            { label: "Blue channel",      value: "b" }
                        ]
                        textRole: "label"
                        valueRole: "value"
                        currentIndex: 0
                        onActivated: root.outputMode = model[currentIndex].value
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: root.outputMode === "mono"
                          ? "One greyscale (luminance) image. Works for any frame."
                          : (root.outputMode === "color"
                             ? "Three-channel RGB image via superpixel debayer (half resolution). Colour frames (OSC) only; raw colour is green-heavy before balancing."
                             : "A single colour channel, written as a greyscale image. Colour frames (OSC) only.")
                    color: "#777777"; font.pixelSize: 11
                }
            }

            Row {
                spacing: 10

                Button {
                    id: stackBtn
                    text: stackingService.stacking ? "Stacking…" : "Integrate"
                    enabled: !stackingService.stacking && root.availableCount >= 2
                    onClicked: stackingService.integrate(root.frameList(),
                                                         root.referencePath,
                                                         root.targetName,
                                                         root.alignFrames,
                                                         root.combineMethod,
                                                         root.outputMode)
                }
                Button {
                    text: "Cancel"
                    visible: stackingService.stacking
                    onClicked: stackingService.cancel()
                }
            }

            Text {
                visible: root.availableCount < 2
                text: "Open a light frame in the Viewer first — stacking needs at least two compatible frames."
                color: "#c08040"; font.pixelSize: 12
                width: parent.width; wrapMode: Text.WordWrap
            }

            Column {
                width: parent.width
                spacing: 6
                visible: stackingService.stacking

                Text {
                    text: stackingService.phase + "  "
                          + stackingService.progressDone + " / " + stackingService.progressTotal
                    color: "#bbbbbb"; font.pixelSize: 12
                }
                Rectangle {
                    width: parent.width; height: 8; radius: 4; color: "#2a2a2a"
                    Rectangle {
                        height: parent.height; radius: 4; color: "#2f6fdb"
                        width: stackingService.progressTotal > 0
                               ? parent.width * stackingService.progressDone / stackingService.progressTotal
                               : 0
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: resultCol.height + 24
                radius: 6
                visible: stackingService.resultPath !== "" || stackingService.lastError !== ""
                color: stackingService.lastError !== "" ? "#3a2626" : "#26332a"
                border.color: stackingService.lastError !== "" ? "#7a3a3a" : "#3a7a4a"
                border.width: 1

                Column {
                    id: resultCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12
                    spacing: 8

                    Text {
                        visible: stackingService.lastError !== ""
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "Stacking failed: " + stackingService.lastError
                        color: "#e0a0a0"; font.pixelSize: 12
                    }
                    Text {
                        visible: stackingService.resultPath !== ""
                        text: "✓ Stacked " + stackingService.framesUsed + " frames"
                        color: "#a0e0b0"; font.pixelSize: 13; font.bold: true
                    }
                    Text {
                        visible: stackingService.resultPath !== ""
                        width: parent.width; wrapMode: Text.WrapAnywhere
                        text: stackingService.resultPath
                        color: "#bbbbbb"; font.pixelSize: 11
                    }
                    Button {
                        visible: stackingService.resultPath !== ""
                        text: "Open Result in Viewer"
                        onClicked: root.openResultRequested(stackingService.resultPath)
                    }
                }
            }
        }
    }
}
