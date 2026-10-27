import QtQuick
import QtQuick.Controls
import QtCore

Item {
    id: root

    property var    candidatePaths: []
    property var    rejectedSet: ({})
    property string referencePath: ""
    property string targetName: ""

    signal openResultRequested(string path)

    Settings {
        category: "stacking"
        property alias mosaicDecisions: root.mosaicDecisions
    }

    // Mosaic awareness: the frame set is clustered by pointing (RA/DEC), exactly
    // as the Culling tab does. When it falls into separate panels the user picks
    // whether to assemble a mosaic or stack only the open frame's panel.
    property int    detectedPanels: 1
    property int    significantPanels: 1
    property bool   mosaicMode: false
    property string mosaicDecisions: "{}"
    readonly property bool mosaicActive: mosaicMode && alignFrames && significantPanels >= 2

    onVisibleChanged:     if (visible) root.refreshMosaic()
    onSourceModeChanged:  root.refreshMosaic()
    onTargetNameChanged:  root.refreshMosaic()

    function angSep(a, b) {
        var dRa = Math.abs(a.ra - b.ra)
        if (dRa > 180) dRa = 360 - dRa
        var mdec = (a.dec + b.dec) / 2 * Math.PI / 180
        var x = dRa * Math.cos(mdec)
        var y = a.dec - b.dec
        return Math.sqrt(x * x + y * y)
    }

    // Clusters a path list into panels at 0.2°, returning per-path panel ids
    // (aligned to the list), the panel count, and how many panels are populated.
    function clusterIds(paths) {
        var coords = metadataModel.pointingsForPaths(paths)
        var tol = 0.2
        var panels = []
        var ids = []
        for (var i = 0; i < paths.length; i++) {
            var c = coords[paths[i]]
            if (!c) { ids.push(-1); continue }
            var best = -1, bestD = 1e9
            for (var j = 0; j < panels.length; j++) {
                var d = angSep(c, panels[j])
                if (d < tol && d < bestD) { bestD = d; best = j }
            }
            if (best === -1) {
                panels.push({ ra: c.ra, dec: c.dec, n: 1 })
                best = panels.length - 1
            } else {
                var pn = panels[best]
                pn.ra  = (pn.ra  * pn.n + c.ra)  / (pn.n + 1)
                pn.dec = (pn.dec * pn.n + c.dec) / (pn.n + 1)
                pn.n  += 1
            }
            ids.push(best)
        }
        var sig = 0
        for (var k = 0; k < panels.length; k++) if (panels[k].n >= 3) sig++
        return { ids: ids, count: panels.length, significant: sig }
    }

    function refPanelOf(paths, ids) {
        var ri = paths.indexOf(root.referencePath)
        if (ri < 0) ri = 0
        return (ids.length > ri) ? ids[ri] : -1
    }

    // The frames that will actually be stacked, plus the panel ids and mosaic
    // flag to hand the service. Mosaic → every panel; focus → only the open
    // frame's panel; no mosaic → the whole list unchanged.
    function stackPlan() {
        var fl = root.frameList()
        var info = root.clusterIds(fl)
        if (root.mosaicActive)
            return { list: fl, panelIds: info.ids, mosaic: true }
        if (info.significant >= 2) {
            var rp = root.refPanelOf(fl, info.ids)
            var sub = []
            for (var i = 0; i < fl.length; i++)
                if (info.ids[i] === rp) sub.push(fl[i])
            return { list: sub, panelIds: [], mosaic: false }
        }
        return { list: fl, panelIds: [], mosaic: false }
    }

    function mosaicDecisionFor(target) {
        if (target === "") return ""
        try {
            var m = JSON.parse(root.mosaicDecisions || "{}")
            if (m[target] === true)  return "yes"
            if (m[target] === false) return "no"
        } catch (e) {}
        return ""
    }

    function setMosaicDecision(target, enabled) {
        root.mosaicMode = enabled
        if (target === "") return
        var m = {}
        try { m = JSON.parse(root.mosaicDecisions || "{}") } catch (e) { m = {} }
        m[target] = enabled
        root.mosaicDecisions = JSON.stringify(m)
    }

    function refreshMosaic() {
        if (stackingService.stacking) return
        var info = root.clusterIds(root.frameList())
        root.detectedPanels = info.count
        root.significantPanels = info.significant
        if (info.significant >= 2) {
            var decided = root.mosaicDecisionFor(root.targetName)
            if (decided === "yes")      root.mosaicMode = true
            else if (decided === "no")  root.mosaicMode = false
            else if (root.visible && !mosaicDialog.opened) {
                mosaicDialog.panelCount = info.significant
                mosaicDialog.open()
            }
        } else {
            root.mosaicMode = false
        }
    }

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

    property bool   calibrationEnabled: false
    property string calibMode: "auto"       // "auto" = find near lights, "manual" = choose folders
    property bool   calibProbed: false
    property var  darkPaths: []
    property var  flatPaths: []
    property var  biasPaths: []

    function clearCalibration() {
        root.darkPaths = []; root.flatPaths = []; root.biasPaths = []; root.calibProbed = false
    }

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

            Rectangle {
                visible: root.significantPanels >= 2
                width: parent.width
                height: mosaicCol.height + 24
                radius: 6; color: "#2a2620"; border.color: "#6a5a3a"; border.width: 1

                Column {
                    id: mosaicCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "◈ Mosaic detected — " + root.significantPanels + " panels"
                        color: "#e0c080"; font.pixelSize: 13; font.bold: true
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "These frames cover " + root.significantPanels + " separate pointings. Assemble "
                              + "them into one mosaic, or stack only the panel the open frame belongs to."
                        color: "#b9a87a"; font.pixelSize: 11
                    }
                    RadioButton {
                        id: mosaicAll
                        text: "Stack as mosaic (combine all panels)"
                        checked: root.mosaicMode
                        enabled: !stackingService.stacking && root.alignFrames
                        onCheckedChanged: if (checked) root.setMosaicDecision(root.targetName, true)
                        contentItem: Text {
                            text: mosaicAll.text; color: "#dddddd"; font.pixelSize: 12
                            leftPadding: mosaicAll.indicator.width + 6; verticalAlignment: Text.AlignVCenter
                        }
                    }
                    RadioButton {
                        id: mosaicOne
                        text: "Focus on one panel (the open frame's)"
                        checked: !root.mosaicMode
                        enabled: !stackingService.stacking
                        onCheckedChanged: if (checked) root.setMosaicDecision(root.targetName, false)
                        contentItem: Text {
                            text: mosaicOne.text; color: "#dddddd"; font.pixelSize: 12
                            leftPadding: mosaicOne.indicator.width + 6; verticalAlignment: Text.AlignVCenter
                        }
                    }
                    Text {
                        visible: root.mosaicMode && !root.alignFrames
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "Mosaic assembly needs alignment — turn on “Align frames” below."
                        color: "#c08040"; font.pixelSize: 11
                    }
                    Text {
                        visible: root.mosaicActive
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "Panels are tied together by the stars they share in their overlaps; any "
                              + "panel that overlaps none of the others is left out. Memory grows with the "
                              + "mosaic's total area."
                        color: "#8a7f5a"; font.pixelSize: 11
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
                    text: "For non-Seestar rigs that need their own calibration. Darks are subtracted "
                          + "from each light (or bias, if no darks); flats are bias-corrected, normalised, "
                          + "and divided out. Masters use a sigma-clipped mean. Frames that don't match the "
                          + "lights' size are skipped (the result panel reports it)."
                    color: "#777777"; font.pixelSize: 11
                    leftPadding: 26
                }

                Column {
                    visible: root.calibrationEnabled
                    width: parent.width
                    spacing: 6
                    leftPadding: 26

                    Row {
                        spacing: 16
                        RadioButton {
                            id: calAuto
                            text: "Auto-match near lights"
                            checked: root.calibMode === "auto"
                            enabled: !stackingService.stacking
                            onCheckedChanged: if (checked) { root.calibMode = "auto"; root.clearCalibration() }
                            contentItem: Text {
                                text: calAuto.text; color: "#dddddd"; font.pixelSize: 12
                                leftPadding: calAuto.indicator.width + 4; verticalAlignment: Text.AlignVCenter
                            }
                        }
                        RadioButton {
                            id: calManual
                            text: "Choose folders"
                            checked: root.calibMode === "manual"
                            enabled: !stackingService.stacking
                            onCheckedChanged: if (checked) { root.calibMode = "manual"; root.clearCalibration() }
                            contentItem: Text {
                                text: calManual.text; color: "#dddddd"; font.pixelSize: 12
                                leftPadding: calManual.indicator.width + 4; verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    Button {
                        visible: root.calibMode === "auto"
                        text: "Find matching calibration"
                        enabled: !stackingService.stacking && root.frameList().length > 0
                        onClicked: {
                            var m = stackingService.autoMatchCalibration(root.frameList())
                            root.darkPaths = (m && m.darks) ? m.darks : []
                            root.flatPaths = (m && m.flats) ? m.flats : []
                            root.biasPaths = (m && m.bias)  ? m.bias  : []
                            root.calibProbed = true
                        }
                    }
                    Text {
                        visible: root.calibMode === "auto" && root.calibProbed
                        width: parent.width; wrapMode: Text.WordWrap
                        readonly property int total: root.darkPaths.length + root.flatPaths.length + root.biasPaths.length
                        text: total > 0
                              ? "Looks in darks/flats/bias folders beside the lights, matching darks by exposure/temperature and all by size."
                              : "No matching calibration frames found in darks/flats/bias folders beside the lights."
                        color: total > 0 ? "#777777" : "#c08040"; font.pixelSize: 11
                    }

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
                                visible: root.calibMode === "manual"
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
                                text: modelData.label + ": " + (cnt > 0 ? (cnt + " frame" + (cnt !== 1 ? "s" : "")) : "none")
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
                    text: stackingService.stacking
                          ? "Stacking…"
                          : (root.mosaicActive ? "Integrate Mosaic" : "Integrate")
                    enabled: !stackingService.stacking && root.availableCount >= 2
                    onClicked: {
                        var plan = root.stackPlan()
                        stackingService.integrate(plan.list,
                                                   root.referencePath,
                                                   root.targetName,
                                                   root.alignFrames,
                                                   root.combineMethod,
                                                   root.outputMode,
                                                   root.autoBalance,
                                                   root.calibrationEnabled
                                                      ? { darks: root.darkPaths, flats: root.flatPaths, bias: root.biasPaths }
                                                      : ({}),
                                                   plan.panelIds,
                                                   plan.mosaic)
                    }
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

    Dialog {
        id: mosaicDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Mosaic Detected"

        property int panelCount: 0

        Column {
            spacing: 12
            width: 440

            Text {
                width: parent.width
                text: "The frames for " + (root.targetName !== "" ? "“" + root.targetName + "”" : "this target")
                      + " cover " + mosaicDialog.panelCount + " separate pointings, so this looks like a mosaic."
                color: "#dddddd"; wrapMode: Text.WordWrap; font.pixelSize: 13
            }
            Text {
                width: parent.width
                text: "Stack as a mosaic to register the panels by their shared stars and assemble one wide image, "
                      + "or focus on a single panel to stack only the frames that share the open frame's pointing."
                color: "#9a9a9a"; wrapMode: Text.WordWrap; font.pixelSize: 12
            }
            Text {
                width: parent.width
                text: "Your choice is remembered for this target. You can change it on the Stacking screen."
                color: "#9a9a9a"; wrapMode: Text.WordWrap; font.pixelSize: 11; opacity: 0.8
            }
            Row {
                spacing: 8
                anchors.right: parent.right
                Button {
                    text: "Focus on one panel"
                    onClicked: { root.setMosaicDecision(root.targetName, false); mosaicDialog.close() }
                }
                Button {
                    text: "Stack as Mosaic"
                    highlighted: true
                    onClicked: { root.setMosaicDecision(root.targetName, true); mosaicDialog.close() }
                }
            }
        }
    }
}
