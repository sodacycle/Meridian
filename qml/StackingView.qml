import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var    candidatePaths: []
    property var    rejectedSet: ({})
    property string referencePath: ""
    property string targetName: ""

    signal openResultRequested(string path)

    // "shown" = the Files-tab list (current File-Level Details view);
    // "target" = every scanned frame of the open image's target, across all folders.
    property string sourceMode: "target"
    readonly property var effectiveCandidates:
        (sourceMode === "target" && targetName !== "")
            ? metadataModel.pathsForTarget(targetName)
            : candidatePaths

    function frameList() {
        var base = effectiveCandidates
        var out = []
        for (var i = 0; i < base.length; i++) {
            var p = base[i]
            if (p && !rejectedSet[p]) out.push(p)
        }
        return out
    }

    readonly property int availableCount: frameList().length
    property string combineMethod: "average"
    property bool   alignFrames: true
    property string outputMode: "mono"
    property bool   autoBalance: true
    readonly property bool colourOutput: outputMode === "color" || outputMode === "colorfull"

    property bool calibrationEnabled: false
    property var  darkPaths: []
    property var  flatPaths: []
    property var  biasPaths: []

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
                text: "Integrate many frames into a single, deeper image. Choose the source below — "
                      + "the whole target (every scanned frame of this object, across all folders) or "
                      + "just the Files-tab list. Culled (rejected) frames are left out automatically."
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
                        Text { text: "Source:"; color: "#8a8a8a"; font.pixelSize: 12
                               anchors.verticalCenter: parent.verticalCenter }
                        RadioButton {
                            id: srcTarget
                            text: "Entire target"
                            checked: root.sourceMode === "target"
                            enabled: !stackingService.stacking && root.targetName !== ""
                            onCheckedChanged: if (checked) root.sourceMode = "target"
                            contentItem: Text {
                                text: srcTarget.text; color: "#dddddd"; font.pixelSize: 12
                                leftPadding: srcTarget.indicator.width + 4
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        RadioButton {
                            id: srcShown
                            text: "Files shown"
                            checked: root.sourceMode === "shown"
                            enabled: !stackingService.stacking
                            onCheckedChanged: if (checked) root.sourceMode = "shown"
                            contentItem: Text {
                                text: srcShown.text; color: "#dddddd"; font.pixelSize: 12
                                leftPadding: srcShown.indicator.width + 4
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    Row {
                        spacing: 8
                        Text { text: "Frames to stack:"; color: "#8a8a8a"; font.pixelSize: 12 }
                        Text {
                            text: root.availableCount + " of " + root.effectiveCandidates.length
                                  + (root.sourceMode === "target" ? " for this target (all folders)" : " shown")
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
                    text: "Registers each frame to the reference by matching star patterns, "
                          + "correcting for shift and field rotation (sub-pixel). Turn off only "
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
                            { label: "Mono (luminance)",          value: "mono" },
                            { label: "Colour — full resolution",  value: "colorfull" },
                            { label: "Colour — superpixel (½ res)", value: "color" },
                            { label: "Red channel",               value: "r" },
                            { label: "Green channel",             value: "g" },
                            { label: "Blue channel",              value: "b" }
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
                          : (root.outputMode === "colorfull"
                             ? "Full-resolution RGB via bilinear demosaic. Colour frames (OSC) only; best detail, slower."
                             : (root.outputMode === "color"
                                ? "Three-channel RGB via superpixel debayer (half resolution). Colour frames (OSC) only; faster, lower memory."
                                : "A single colour channel, written as a greyscale image. Colour frames (OSC) only."))
                    color: "#777777"; font.pixelSize: 11
                }

                CheckBox {
                    id: balanceCheck
                    text: "Auto colour balance"
                    visible: root.colourOutput
                    checked: root.autoBalance
                    onCheckedChanged: root.autoBalance = checked
                    enabled: !stackingService.stacking
                    contentItem: Text {
                        text: balanceCheck.text
                        color: "#dddddd"; font.pixelSize: 13
                        leftPadding: balanceCheck.indicator.width + 6
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Text {
                    visible: root.colourOutput
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Neutralises the colour cast of raw OSC colour (often green) by equalising "
                          + "the channel backgrounds (grey-world). Turn off to keep the unbalanced channels."
                    color: "#777777"; font.pixelSize: 11
                    leftPadding: 26
                }

                CheckBox {
                    id: calibCheck
                    text: "Apply calibration frames (darks / flats / bias)"
                    checked: root.calibrationEnabled
                    onCheckedChanged: root.calibrationEnabled = checked
                    enabled: !stackingService.stacking
                    contentItem: Text {
                        text: calibCheck.text
                        color: "#dddddd"; font.pixelSize: 13
                        leftPadding: calibCheck.indicator.width + 6
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "For non-Seestar rigs that need their own calibration. Each set is optional; "
                          + "the frames must match the lights' dimensions (any that don't are skipped). "
                          + "Darks are subtracted from each light (or bias, if no darks); flats are "
                          + "bias-corrected, normalised, and divided out."
                    color: "#777777"; font.pixelSize: 11
                    leftPadding: 26
                }

                Column {
                    visible: root.calibrationEnabled
                    width: parent.width
                    spacing: 6
                    leftPadding: 26

                    Repeater {
                        model: [
                            { label: "Darks", key: "dark" },
                            { label: "Flats", key: "flat" },
                            { label: "Bias",  key: "bias" }
                        ]
                        delegate: Row {
                            required property var modelData
                            spacing: 8
                            Button {
                                text: "Choose " + modelData.label + "…"
                                width: 150
                                enabled: !stackingService.stacking
                                onClicked: {
                                    var l = stackingService.selectCalibrationFolder()
                                    if (l && l.length > 0) {
                                        if (modelData.key === "dark") root.darkPaths = l
                                        else if (modelData.key === "flat") root.flatPaths = l
                                        else root.biasPaths = l
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                readonly property int cnt: modelData.key === "dark" ? root.darkPaths.length
                                                         : (modelData.key === "flat" ? root.flatPaths.length
                                                            : root.biasPaths.length)
                                text: cnt > 0 ? (cnt + " frame" + (cnt !== 1 ? "s" : "")) : "none selected"
                                color: cnt > 0 ? "#a0e0b0" : "#777777"
                                font.pixelSize: 12
                            }
                        }
                    }
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
                                                         root.outputMode,
                                                         root.autoBalance,
                                                         root.calibrationEnabled
                                                            ? { darks: root.darkPaths, flats: root.flatPaths, bias: root.biasPaths }
                                                            : ({}))
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
                         || stackingService.lastWarning !== ""
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
                        visible: stackingService.lastWarning !== ""
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "⚠ " + stackingService.lastWarning
                        color: "#e0c080"; font.pixelSize: 12
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
