import QtQuick
import QtQuick.Controls
import QtCore

Item {
    id: culling

    Settings {
        category: "culling"
        property alias sensitivity:      culling.sensitivity
        property alias metricStarCount:  culling.mStarcount
        property alias metricBrightness: culling.mBrightness
        property alias metricFwhm:       culling.mFwhm
        property alias metricEcc:        culling.mEccentricity
        property alias metricNoise:      culling.mNoise
    }

    property int step: 1
    property string reviewMode: ""
    property var candidatePaths: []

    property int reviewIndex: 0
    property var reviewFrames: filterReview(cullingService.batchResults, reviewMode)

    onReviewModeChanged: reviewIndex = 0

    function filterReview(results, mode) {
        if (mode === "") return []
        var want = mode === "rejected" ? "REJECT" : "BORDERLINE"
        var out = []
        for (var i = 0; i < results.length; i++) {
            if (results[i].classification === want) out.push({ gi: i, f: results[i] })
        }
        return out
    }

    function pct(n, total) { return total > 0 ? (100 * n / total).toFixed(1) + "%" : "0%" }

    property real stretchA: 0.1
    property real stretchP: 99.0
    property int  denoiseRadius: 0

    function imgSource(path) {
        if (!path || path === "") return ""
        return "image://fitsprovider/" + encodeURIComponent(path)
               + "?a=" + stretchA.toFixed(3) + "&p=" + stretchP.toFixed(2) + "&d=" + denoiseRadius
    }

    property string sensitivity: "balanced"
    property bool mStarcount:    true
    property bool mBrightness:   true
    property bool mFwhm:         true
    property bool mEccentricity: true
    property bool mNoise:        true

    property bool hasApplied: false
    property int  appliedCount: 0

    signal rejectionsApplied(var paths)

    function sensitivityLabel() {
        return sensitivity.charAt(0).toUpperCase() + sensitivity.slice(1)
    }

    function enabledMetrics() {
        var m = []
        if (mStarcount)    m.push("starcount")
        if (mBrightness)   m.push("brightness")
        if (mFwhm)         m.push("fwhm")
        if (mEccentricity) m.push("eccentricity")
        if (mNoise)        m.push("noise")
        return m
    }

    readonly property color surface:      "#1b1b1b"
    readonly property color panel:         "#242424"
    readonly property color card:          "#2a2a2a"
    readonly property color divider:       "#3a3a3a"
    readonly property color textPrimary:   "#e8e8e8"
    readonly property color textSecondary: "#9a9a9a"
    readonly property color textMuted:     "#6f6f6f"

    readonly property color accent:        "#2f6fdb"
    readonly property color controlBlue:   "#4a90d0"

    readonly property color goodColor:     "#3fb950"
    readonly property color okColor:       "#d9a520"
    readonly property color badColor:      "#e5484d"
    readonly property color goodBg:        "#132a1a"
    readonly property color okBg:          "#2e2712"
    readonly property color badBg:         "#2e1517"
    readonly property color goodBorder:    "#2a5a38"
    readonly property color okBorder:      "#6a5a1f"
    readonly property color badBorder:     "#6a2a2f"

    function metric(value, digits) {
        return value.toFixed(digits === undefined ? 2 : digits)
    }

    Rectangle { anchors.fill: parent; color: culling.surface }

    Rectangle {
        id: stepperBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 60
        color: culling.panel

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: culling.divider }

        Row {
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: [
                    { n: 1, label: "Control" },
                    { n: 2, label: "Analyze" },
                    { n: 3, label: "Review"  },
                    { n: 4, label: "Apply"   }
                ]

                delegate: Row {
                    spacing: 0
                    required property var modelData

                    readonly property bool isActive: culling.reviewMode === "" && culling.step === modelData.n
                    readonly property bool isDone:   culling.step > modelData.n

                    Item {
                        width: 130; height: 60

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { culling.reviewMode = ""; culling.step = modelData.n }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                width: 26; height: 26; radius: 13
                                anchors.verticalCenter: parent.verticalCenter
                                color: isDone ? culling.goodColor
                                      : isActive ? culling.accent : "transparent"
                                border.width: isDone || isActive ? 0 : 1
                                border.color: culling.textMuted

                                Text {
                                    anchors.centerIn: parent
                                    text: isDone ? "✓" : modelData.n
                                    color: isDone || isActive ? "#ffffff" : culling.textMuted
                                    font.pixelSize: 13; font.bold: true
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                font.pixelSize: 14
                                font.bold: isActive
                                color: isActive ? culling.textPrimary
                                      : isDone ? culling.goodColor : culling.textSecondary
                            }
                        }
                    }

                    Rectangle {
                        visible: modelData.n < 4
                        width: 34; height: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: isDone ? culling.goodColor : culling.divider
                    }
                }
            }
        }
    }

    Loader {
        anchors.top: stepperBar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        sourceComponent: culling.reviewMode !== "" ? reviewFrameScreen
                        : culling.step === 1 ? controlScreen
                        : culling.step === 2 ? analyzeScreen
                        : culling.step === 3 ? resultsScreen
                        : applyScreen
    }

    Component {
        id: controlScreen

        ScrollView {
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: culling.width
                spacing: 16
                padding: 24

                Text {
                    text: "1. Select Control Image"
                    font.pixelSize: 20; font.bold: true; color: culling.textPrimary
                }
                Text {
                    width: parent.width - 48
                    wrapMode: Text.WordWrap
                    color: culling.textSecondary; font.pixelSize: 13
                    text: "Choose a good frame to establish the quality baseline. Every compatible " +
                          "frame in your collection is later compared against this control image."
                }

                Row {
                    spacing: 16
                    width: parent.width - 48

                    Rectangle {
                        width: (parent.width - 16) * 0.5
                        height: 300
                        color: "#111111"
                        border.color: culling.divider; border.width: 1
                        radius: 6
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            visible: cullingService.controlPath !== ""
                            source: culling.imgSource(cullingService.controlPath)
                        }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 40
                            spacing: 10
                            visible: cullingService.controlPath === "" && !cullingService.recommending

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No control image selected"
                                color: culling.textMuted; font.pixelSize: 13
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8
                                Button {
                                    text: "Choose Control Image…"
                                    enabled: !cullingService.analyzing
                                    onClicked: {
                                        var path = cullingService.selectControlImage()
                                        if (path !== "") cullingService.analyzeControl(path)
                                    }
                                }
                                Button {
                                    text: "Recommend for Me"
                                    enabled: !cullingService.analyzing && !cullingService.recommending && culling.candidatePaths.length > 1
                                    onClicked: {
                                        if (culling.candidatePaths.length > 1)
                                            cullingService.recommendControlImage(culling.candidatePaths)
                                    }
                                }
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: culling.candidatePaths.length > 1
                                      ? "Not sure which frame to use? Recommend compares the " + culling.candidatePaths.length +
                                        " frames matching the opened image (same target, filter, exposure) and picks the sharpest, star-richest one."
                                      : "Recommend compares frames matching the opened image. Open a frame from a set with more than one matching sub to enable it."
                                color: "#5f5f5f"; font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            visible: cullingService.controlPath !== ""
                            anchors.left: parent.left; anchors.bottom: parent.bottom
                            anchors.margins: 6
                            width: fileTag.implicitWidth + 16; height: fileTag.implicitHeight + 10
                            color: "#000000cc"; radius: 4
                            Text {
                                id: fileTag
                                anchors.centerIn: parent
                                text: cullingService.controlPath.split("/").pop()
                                color: culling.textPrimary; font.pixelSize: 11
                            }
                        }

                        BusyIndicator {
                            anchors.centerIn: parent
                            width: 48; height: 48
                            running: cullingService.analyzing
                            visible: running
                        }

                        Rectangle {
                            visible: cullingService.recommending
                            anchors.fill: parent; anchors.margins: 1
                            radius: 6
                            color: "#000000cc"

                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                BusyIndicator {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    running: cullingService.recommending
                                    width: 44; height: 44
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Analyzing frames to recommend a control…"
                                    color: culling.textPrimary; font.pixelSize: 12
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: cullingService.recommendDone + " / " + cullingService.recommendTotal
                                    color: culling.textSecondary; font.pixelSize: 12
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 16) * 0.5
                        height: 300
                        color: culling.card
                        border.color: culling.divider; border.width: 1
                        radius: 6

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 8

                            Text {
                                text: "Control Image Metrics"
                                font.pixelSize: 14; font.bold: true; color: culling.textPrimary
                            }

                            Rectangle { width: parent.width; height: 1; color: culling.divider }

                            Repeater {
                                model: [
                                    { label: "Stars",            value: cullingService.controlValid ? cullingService.controlStarCount : "—" },
                                    { label: "Usable stars",     value: cullingService.controlValid ? cullingService.controlUsableStarCount : "—" },
                                    { label: "Median FWHM",      value: cullingService.controlValid ? culling.metric(cullingService.controlFwhm) + " px" : "—" },
                                    { label: "Median star flux", value: cullingService.controlValid ? culling.metric(cullingService.controlFlux, 1) + " ADU" : "—" },
                                    { label: "Eccentricity",     value: cullingService.controlValid ? culling.metric(cullingService.controlEccentricity, 3) : "—" },
                                    { label: "Background noise", value: cullingService.controlValid ? culling.metric(cullingService.controlBackgroundNoise, 1) + " ADU" : "—" }
                                ]
                                delegate: Row {
                                    width: parent.width
                                    height: 26
                                    required property var modelData
                                    Text {
                                        width: parent.width * 0.6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        color: culling.textSecondary; font.pixelSize: 13
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.value
                                        color: culling.textPrimary; font.pixelSize: 13; font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: cullingService.controlWarning !== ""
                    width: parent.width - 48
                    height: warnRow.implicitHeight + 20
                    color: culling.okBg
                    border.color: culling.okBorder; border.width: 1
                    radius: 6

                    Text {
                        id: warnRow
                        anchors.fill: parent; anchors.margins: 10
                        wrapMode: Text.WordWrap
                        color: culling.okColor; font.pixelSize: 13
                        text: "⚠  " + cullingService.controlWarning
                    }
                }

                Rectangle {
                    visible: cullingService.controlValid
                    width: parent.width - 48
                    height: 58
                    color: culling.goodBg
                    border.color: culling.goodBorder; border.width: 1
                    radius: 6

                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Rectangle {
                            width: 24; height: 24; radius: 12; color: culling.goodColor
                            anchors.verticalCenter: parent.verticalCenter
                            Text { anchors.centerIn: parent; text: "✓"; color: "#ffffff"; font.pixelSize: 14; font.bold: true }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text { text: cullingService.controlRecommended ? "Recommended Control" : "Control Quality: Good"; color: culling.goodColor; font.pixelSize: 14; font.bold: true }
                            Text { text: cullingService.controlRecommended ? "Meridian picked a sharp, star-rich frame from your scan folders." : "Sufficient stars and good signal characteristics."; color: culling.textSecondary; font.pixelSize: 12 }
                        }
                    }
                }

                Row {
                    width: parent.width - 48
                    spacing: 8
                    Button {
                        id: chooseAnotherBtn
                        visible: cullingService.controlValid
                        text: "Choose Another…"
                        enabled: !cullingService.analyzing && !cullingService.recommending
                        onClicked: {
                            var p = cullingService.selectControlImage()
                            if (p !== "") cullingService.analyzeControl(p)
                        }
                    }
                    Button {
                        id: recAgainBtn
                        visible: cullingService.controlValid
                        text: "Recommend for Me"
                        enabled: !cullingService.analyzing && !cullingService.recommending && culling.candidatePaths.length > 1
                        onClicked: {
                            if (culling.candidatePaths.length > 1)
                                cullingService.recommendControlImage(culling.candidatePaths)
                        }
                    }
                    Item {
                        width: Math.max(0, parent.width - nextBtn.width
                                 - (cullingService.controlValid ? chooseAnotherBtn.width + recAgainBtn.width + 16 : 0))
                        height: 1
                    }
                    Button {
                        id: nextBtn
                        text: "Use This Image →"
                        highlighted: true
                        enabled: cullingService.controlValid
                        onClicked: culling.step = 2
                    }
                }
            }
        }
    }

    Component {
        id: analyzeScreen

        ScrollView {
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: culling.width
                spacing: 16
                padding: 24

                Text { text: "2. Analysis Settings"; font.pixelSize: 20; font.bold: true; color: culling.textPrimary }
                Text {
                    width: parent.width - 48; wrapMode: Text.WordWrap
                    color: culling.textSecondary; font.pixelSize: 13
                    text: "Pick which metrics to weigh and how strict the culling should be, " +
                          "then analyze the compatible frames against your control image."
                }

                Row {
                    spacing: 16
                    width: parent.width - 48

                    Rectangle {
                        width: (parent.width - 16) * 0.5
                        height: settingsCol.height + 32
                        color: culling.card; border.color: culling.divider; border.width: 1; radius: 6

                        Column {
                            id: settingsCol
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 16
                            spacing: 10

                            Text { text: "Metrics to Analyze"; font.pixelSize: 14; font.bold: true; color: culling.textPrimary }

                            CheckBox { text: "Star Count";        checked: culling.mStarcount;    onToggled: culling.mStarcount = checked;    font.pixelSize: 13 }
                            CheckBox { text: "Star Brightness";   checked: culling.mBrightness;   onToggled: culling.mBrightness = checked;   font.pixelSize: 13 }
                            CheckBox { text: "FWHM";              checked: culling.mFwhm;         onToggled: culling.mFwhm = checked;         font.pixelSize: 13 }
                            CheckBox { text: "Star Eccentricity"; checked: culling.mEccentricity; onToggled: culling.mEccentricity = checked; font.pixelSize: 13 }
                            CheckBox { text: "Background Noise";  checked: culling.mNoise;        onToggled: culling.mNoise = checked;        font.pixelSize: 13 }

                            Rectangle { width: parent.width; height: 1; color: culling.divider }

                            Text { text: "Culling Sensitivity"; font.pixelSize: 14; font.bold: true; color: culling.textPrimary }

                            Column {
                                spacing: 4
                                RadioButton { text: "Conservative"; checked: culling.sensitivity === "conservative"; onToggled: if (checked) culling.sensitivity = "conservative"; font.pixelSize: 13 }
                                RadioButton { text: "Balanced";     checked: culling.sensitivity === "balanced";     onToggled: if (checked) culling.sensitivity = "balanced"; font.pixelSize: 13 }
                                RadioButton { text: "Aggressive";   checked: culling.sensitivity === "aggressive";   onToggled: if (checked) culling.sensitivity = "aggressive"; font.pixelSize: 13 }
                            }
                            Text {
                                width: parent.width - 8; wrapMode: Text.WordWrap
                                text: culling.sensitivity === "conservative"
                                      ? "Conservative rejects only clearly bad frames — the fewest rejections."
                                      : culling.sensitivity === "aggressive"
                                      ? "Aggressive rejects anything measurably below the control — the most rejections."
                                      : "Balanced trades a good mix of sensitivity and false positives."
                                color: culling.textMuted; font.pixelSize: 11
                            }
                        }
                    }

                    Column {
                        width: (parent.width - 16) * 0.5
                        spacing: 16

                        Rectangle {
                            width: parent.width
                            height: profileCol.height + 32
                            color: culling.card; border.color: culling.divider; border.width: 1; radius: 6

                            Column {
                                id: profileCol
                                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                                anchors.margins: 16
                                spacing: 8

                                Text { text: "Control Profile"; font.pixelSize: 14; font.bold: true; color: culling.textPrimary }
                                Rectangle { width: parent.width; height: 1; color: culling.divider }

                                Repeater {
                                    model: [
                                        { label: "Stars",            value: cullingService.controlValid ? cullingService.controlStarCount : "1,247" },
                                        { label: "Star Flux",        value: cullingService.controlValid ? culling.metric(cullingService.controlFlux, 0) + " ADU" : "18,420 ADU" },
                                        { label: "FWHM",             value: cullingService.controlValid ? culling.metric(cullingService.controlFwhm) + " px" : "2.31 px" },
                                        { label: "Eccentricity",     value: cullingService.controlValid ? culling.metric(cullingService.controlEccentricity, 2) : "0.17" },
                                        { label: "Background Noise", value: cullingService.controlValid ? culling.metric(cullingService.controlBackgroundNoise, 1) + " ADU" : "38.2 ADU" }
                                    ]
                                    delegate: Row {
                                        width: parent.width; height: 24
                                        required property var modelData
                                        Text { width: parent.width * 0.6; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: culling.textSecondary; font.pixelSize: 13 }
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.value; color: culling.textPrimary; font.pixelSize: 13; font.bold: true }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: threshCol.height + 32
                            color: culling.card; border.color: culling.divider; border.width: 1; radius: 6

                            Column {
                                id: threshCol
                                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                                anchors.margins: 16
                                spacing: 8

                                Text { text: "Thresholds (" + culling.sensitivityLabel() + ")"; font.pixelSize: 14; font.bold: true; color: culling.textPrimary }
                                Rectangle { width: parent.width; height: 1; color: culling.divider }

                                Repeater {
                                    model: cullingService.thresholdTable(culling.sensitivity)
                                    delegate: Row {
                                        width: parent.width; height: 22
                                        required property var modelData
                                        Text { width: parent.width * 0.4; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: culling.textSecondary; font.pixelSize: 12 }
                                        Text { width: parent.width * 0.25; anchors.verticalCenter: parent.verticalCenter; text: modelData.value; color: culling.textPrimary; font.pixelSize: 12; font.bold: true }
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.reject; color: culling.textMuted; font.pixelSize: 11 }
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width - 48
                    Text {
                        id: foundText
                        anchors.verticalCenter: parent.verticalCenter
                        text: culling.candidatePaths.length + " compatible frames found"
                        color: culling.textSecondary; font.pixelSize: 13
                    }
                    Item { width: Math.max(0, parent.width - analyzeBtn.width - foundText.width); height: 1 }
                    Button {
                        id: analyzeBtn
                        text: "Analyze Frames →"
                        highlighted: true
                        enabled: cullingService.controlValid && culling.candidatePaths.length > 0 && !cullingService.batchAnalyzing
                        onClicked: {
                            culling.hasApplied = false
                            cullingService.analyzeBatch(culling.candidatePaths, culling.sensitivity, culling.enabledMetrics())
                            culling.step = 3
                        }
                    }
                }
            }
        }
    }

    Component {
        id: resultsScreen

        ScrollView {
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            readonly property int total: cullingService.passCount + cullingService.borderlineCount
                                         + cullingService.rejectCount + cullingService.insufficientCount

            Column {
                width: culling.width
                spacing: 16
                padding: 24

                Text { text: "3. Frame Culling Results"; font.pixelSize: 20; font.bold: true; color: culling.textPrimary }

                Rectangle {
                    visible: cullingService.batchAnalyzing
                    width: parent.width - 48
                    height: 120
                    color: culling.card; border.color: culling.divider; border.width: 1; radius: 6
                    Column {
                        anchors.centerIn: parent; spacing: 10
                        BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: cullingService.batchAnalyzing; width: 40; height: 40 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Analyzing " + cullingService.batchDone + " / " + cullingService.batchTotal + " frames…"; color: culling.textSecondary; font.pixelSize: 13 }
                    }
                }

                Column {
                    visible: !cullingService.batchAnalyzing && total === 0
                    width: parent.width - 48
                    spacing: 10
                    Text { text: "No analysis yet."; color: culling.textSecondary; font.pixelSize: 14 }
                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "Go back to Analyze and run the batch analyzer to classify the compatible frames against your control image."; color: culling.textMuted; font.pixelSize: 12 }
                    Button { text: "← Back to Analyze"; onClicked: culling.step = 2 }
                }

                Row {
                    visible: !cullingService.batchAnalyzing && total > 0
                    width: parent.width - 48
                    spacing: 14

                    Repeater {
                        model: [
                            { label: "Pass",       count: cullingService.passCount,       fg: culling.goodColor, bg: culling.goodBg, bd: culling.goodBorder, glyph: "✓" },
                            { label: "Borderline", count: cullingService.borderlineCount, fg: culling.okColor,   bg: culling.okBg,   bd: culling.okBorder,   glyph: "⚠" },
                            { label: "Reject",     count: cullingService.rejectCount,     fg: culling.badColor,  bg: culling.badBg,  bd: culling.badBorder,  glyph: "✕" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: (culling.width - 48 - 28) / 3
                            height: 92
                            color: modelData.bg; border.color: modelData.bd; border.width: 1; radius: 8

                            Column {
                                anchors.left: parent.left; anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Row {
                                    spacing: 8
                                    Text { text: modelData.glyph; color: modelData.fg; font.pixelSize: 20; font.bold: true }
                                    Text { text: modelData.count; color: culling.textPrimary; font.pixelSize: 30; font.bold: true }
                                }
                                Text { text: modelData.label + "  ·  " + culling.pct(modelData.count, total); color: modelData.fg; font.pixelSize: 13; font.bold: true }
                            }
                        }
                    }
                }

                Text {
                    visible: !cullingService.batchAnalyzing && cullingService.insufficientCount > 0
                    width: parent.width - 48; wrapMode: Text.WordWrap
                    text: cullingService.insufficientCount + " frame(s) had too few usable stars (insufficient data) and were left unclassified."
                    color: culling.textMuted; font.pixelSize: 12
                }

                Rectangle {
                    visible: !cullingService.batchAnalyzing && cullingService.rejectionReasons.length > 0
                    width: parent.width - 48
                    height: reasonsCol.height + 32
                    color: culling.card; border.color: culling.divider; border.width: 1; radius: 6

                    Column {
                        id: reasonsCol
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                        anchors.margins: 16
                        spacing: 8

                        Text { text: "Rejection Reasons"; font.pixelSize: 14; font.bold: true; color: culling.textPrimary }

                        Repeater {
                            model: cullingService.rejectionReasons
                            delegate: Row {
                                width: parent.width; height: 22; spacing: 10
                                required property var modelData
                                Text { width: parent.width * 0.35; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: culling.textSecondary; font.pixelSize: 12 }
                                Item {
                                    width: parent.width * 0.5; height: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width * (modelData.count / Math.max(1, cullingService.rejectionReasons[0].count))
                                        height: 10; radius: 5; color: culling.badColor
                                    }
                                }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.count; color: culling.textPrimary; font.pixelSize: 12; font.bold: true }
                            }
                        }
                    }
                }

                Row {
                    visible: !cullingService.batchAnalyzing && total > 0
                    width: parent.width - 48
                    spacing: 10
                    Button { id: revRejBtn; text: "Review Rejected (" + cullingService.rejectCount + ")"; enabled: cullingService.rejectCount > 0; onClicked: culling.reviewMode = "rejected" }
                    Button { id: revBorBtn; text: "Review Borderline (" + cullingService.borderlineCount + ")"; enabled: cullingService.borderlineCount > 0; onClicked: culling.reviewMode = "borderline" }
                    Item { width: Math.max(0, parent.width - revRejBtn.width - revBorBtn.width - contBtn.width - 20); height: 1 }
                    Button {
                        id: contBtn
                        text: "Continue to Apply →"
                        highlighted: true
                        onClicked: culling.step = 4
                    }
                }
            }
        }
    }

    Component {
        id: reviewFrameScreen

        ScrollView {
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            readonly property bool isReject: culling.reviewMode === "rejected"
            readonly property int frameCount: culling.reviewFrames.length
            readonly property var entry: (frameCount > 0 && culling.reviewIndex < frameCount) ? culling.reviewFrames[culling.reviewIndex] : null
            readonly property var frame: entry ? entry.f : null
            readonly property string decision: frame ? frame.decision : "auto"

            Column {
                width: culling.width
                spacing: 16
                padding: 24

                Row {
                    width: parent.width - 48
                    Text {
                        id: revTitle
                        anchors.verticalCenter: parent.verticalCenter
                        text: (isReject ? "Review Rejected Frames" : "Review Borderline Frames")
                              + (frameCount > 0 ? "    " + (culling.reviewIndex + 1) + " / " + frameCount : "")
                        font.pixelSize: 20; font.bold: true; color: culling.textPrimary
                    }
                    Item { width: Math.max(0, parent.width - revTitle.width - backBtn.width); height: 1 }
                    Button { id: backBtn; text: "← Back to Results"; onClicked: culling.reviewMode = "" }
                }

                Text {
                    visible: frameCount === 0
                    width: parent.width - 48
                    text: "No frames in this category."
                    color: culling.textSecondary; font.pixelSize: 13
                }

                Row {
                    visible: frameCount > 0
                    width: parent.width - 48
                    spacing: 16

                    Rectangle {
                        width: (parent.width - 16) * 0.55
                        height: 300
                        color: "#111111"; border.color: culling.divider; border.width: 1; radius: 6
                        clip: true

                        Image {
                            anchors.fill: parent; anchors.margins: 1
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true; cache: false
                            source: frame ? culling.imgSource(frame.path) : ""
                        }

                        Rectangle {
                            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 6
                            width: nameTag.implicitWidth + 16; height: nameTag.implicitHeight + 10
                            color: "#000000cc"; radius: 4
                            Text { id: nameTag; anchors.centerIn: parent; text: frame ? frame.file : ""; color: culling.textPrimary; font.pixelSize: 11 }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 16) * 0.45
                        height: 300
                        color: culling.card; border.color: culling.divider; border.width: 1; radius: 6

                        Column {
                            anchors.fill: parent; anchors.margins: 16
                            spacing: 10

                            Row {
                                spacing: 8
                                Rectangle {
                                    width: badge.implicitWidth + 20; height: badge.implicitHeight + 10; radius: 4
                                    color: isReject ? culling.badBg : culling.okBg
                                    border.color: isReject ? culling.badBorder : culling.okBorder; border.width: 1
                                    Text {
                                        id: badge
                                        anchors.centerIn: parent
                                        text: (isReject ? "✕  REJECT" : "⚠  BORDERLINE")
                                        color: isReject ? culling.badColor : culling.okColor
                                        font.pixelSize: 12; font.bold: true
                                    }
                                }
                                Rectangle {
                                    visible: decision !== "auto"
                                    width: ovr.implicitWidth + 20; height: ovr.implicitHeight + 10; radius: 4
                                    color: "#20304a"; border.color: "#3a5a8a"; border.width: 1
                                    Text { id: ovr; anchors.centerIn: parent; text: decision === "keep" ? "◆ Kept" : "◆ Rejected"; color: "#9ec2ff"; font.pixelSize: 12; font.bold: true }
                                }
                            }

                            Text { text: "Frame Analysis"; font.pixelSize: 13; font.bold: true; color: culling.textPrimary }

                            Repeater {
                                model: frame ? frame.metrics : []
                                delegate: Row {
                                    width: parent.width; height: 26; spacing: 8
                                    required property var modelData
                                    readonly property color sc: modelData.status === "bad" ? culling.badColor
                                                               : modelData.status === "ok" ? culling.okColor : culling.goodColor
                                    Text { width: parent.width * 0.34; anchors.verticalCenter: parent.verticalCenter; text: modelData.key; color: culling.textSecondary; font.pixelSize: 12 }
                                    Item {
                                        width: parent.width * 0.36; height: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        Rectangle {
                                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width * Math.min(1, Math.abs(modelData.delta) / 70)
                                            height: 8; radius: 4; color: sc
                                        }
                                    }
                                    Text { width: 44; anchors.verticalCenter: parent.verticalCenter; text: (modelData.delta > 0 ? "+" : "") + modelData.delta + "%"; color: sc; font.pixelSize: 12; font.bold: true }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.status === "good" ? "✓" : (modelData.status === "ok" ? "⚠" : "✕"); color: sc; font.pixelSize: 13; font.bold: true }
                                }
                            }
                        }
                    }
                }

                Item {
                    visible: frameCount > 0
                    width: parent.width - 48
                    height: keepRow.height

                    Row {
                        id: keepRow
                        anchors.left: parent.left
                        spacing: 10
                        Button {
                            text: "✓ Keep"
                            highlighted: decision === "keep"
                            onClicked: if (entry) cullingService.setFrameDecision(entry.gi, "keep")
                        }
                        Button {
                            text: "✕ Reject"
                            highlighted: decision === "reject"
                            onClicked: if (entry) cullingService.setFrameDecision(entry.gi, "reject")
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: (parent.width - 16) * 0.55 + 16
                        anchors.verticalCenter: keepRow.verticalCenter
                        spacing: 10
                        Button { text: "‹ Previous"; enabled: culling.reviewIndex > 0; onClicked: culling.reviewIndex = Math.max(0, culling.reviewIndex - 1) }
                        Button { text: "Next ›"; enabled: culling.reviewIndex < frameCount - 1; onClicked: culling.reviewIndex = Math.min(frameCount - 1, culling.reviewIndex + 1) }
                        Button { text: "Finish Review"; highlighted: true; onClicked: culling.reviewMode = "" }
                    }
                }
            }
        }
    }

    Component {
        id: applyScreen

        Item {
            Column {
                anchors.centerIn: parent
                width: Math.min(460, culling.width - 48)
                spacing: 16

                Rectangle {
                    width: parent.width; height: 92
                    color: culling.hasApplied ? culling.goodBg : culling.badBg
                    border.color: culling.hasApplied ? culling.goodBorder : culling.badBorder; border.width: 1; radius: 8
                    Column {
                        anchors.centerIn: parent; spacing: 4
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: culling.hasApplied ? "✓  Rejections Applied" : "4. Apply Rejections"
                            color: culling.hasApplied ? culling.goodColor : culling.textPrimary
                            font.pixelSize: 18; font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: culling.hasApplied
                                  ? culling.appliedCount + " frame(s) marked rejected via .mrj sidecars"
                                  : cullingService.rejectionCount + " frames marked for rejection"
                            color: culling.hasApplied ? culling.textSecondary : culling.badColor
                            font.pixelSize: 13
                        }
                    }
                }

                Text {
                    width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                    color: culling.textSecondary; font.pixelSize: 13
                    text: culling.hasApplied
                          ? "The rejected frames now carry .mrj sidecars, so they show as rejected in the Viewer and Files tabs and stay rejected on the next scan. Move them out of the way with Finalize in the Viewer whenever you like."
                          : "Apply writes the approved rejection set (auto-rejections, minus any you kept, plus any you rejected by hand) through the same .mrj sidecar mechanism used in the Viewer. Nothing is rejected without this confirmation."
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: culling.hasApplied ? "Applied" : "Apply " + cullingService.rejectionCount + " Rejections"
                    highlighted: true
                    enabled: !culling.hasApplied && cullingService.rejectionCount > 0
                    onClicked: {
                        var paths = cullingService.rejectionPaths()
                        for (var i = 0; i < paths.length; i++)
                            organizer.writeSidecar(paths[i], true)
                        culling.appliedCount = paths.length
                        culling.hasApplied = true
                        culling.rejectionsApplied(paths)
                    }
                }
            }
        }
    }
}
