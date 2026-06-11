import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    height: col.height + 32
    color:        window.sysPal.base
    border.color: window.sysPal.mid
    border.width: 1
    radius: 6

    property int    rowCount:       0
    property string selectedTarget: ""

    signal catalogSelected(string catalogName)

    Connections {
        target: catalogModel
        function onModelReset()   { root.rowCount = catalogModel.rowCount() }
        function onRowsInserted() { root.rowCount = catalogModel.rowCount() }
        function onRowsRemoved()  { root.rowCount = catalogModel.rowCount() }
    }

    function classifyCatalog(name) {
        var n = name.toUpperCase()
                    .replace(/MOSAIC/g, "").replace(/PANEL/g, "")
                    .replace(/-/g, " ").trim().replace(/\s+/g, " ")
        if (n.startsWith("M "))       return "Messier"
        if (n.startsWith("NGC"))      return "NGC"
        if (n.startsWith("IC"))       return "IC"
        if (n.startsWith("CALDWELL")) return "Caldwell"
        if (n.startsWith("SH2") || n.startsWith("SH ")) return "Sharpless"
        if (n.startsWith("BARNARD") || n.startsWith("B ")) return "Barnard"
        if (n.startsWith("LDN"))      return "LDN"
        if (n.startsWith("LBN"))      return "LBN"
        if (n.startsWith("ABELL"))    return "Abell"
        if (n.startsWith("PGC"))      return "PGC"
        if (n.startsWith("UGC"))      return "UGC"
        return "Other"
    }

    function fmtExpKey(seconds) {
        var n = Number(seconds)
        return (n === Math.floor(n) ? String(Math.floor(n)) : n.toFixed(1)) + "s"
    }

    function fmtHMS(s) {
        var h = Math.floor(s / 3600)
        var m = Math.round((s % 3600) / 60)
        if (m === 60) { h++; m = 0 }
        if (h === 0) return m + "m"
        return h + "h" + (m > 0 ? " " + m + "m" : "")
    }

    // Computed from window.fullMetadataList whenever selectedTarget changes
    property var targetDetails: {
        var name = root.selectedTarget
        if (!name) return null
        var allRows = window.fullMetadataList
        if (!allRows || !allRows.length) return null

        var expGroups = {}
        var lastDate  = ""

        for (var i = 0; i < allRows.length; i++) {
            var row = allRows[i]
            if (row["Target"] !== name || row["Frame Type"] !== "LIGHT") continue

            var exp = Number(row["Exposure Time s"])
            if (exp > 0) {
                var key = root.fmtExpKey(exp)
                expGroups[key] = (expGroups[key] || 0) + 1
            }

            var d = (row["Start Time UTC"] || "").substring(0, 10)
            if (d && d > lastDate) lastDate = d
        }

        // Sum integration time for the last session
        var lastSessionSecs = 0
        if (lastDate) {
            for (var j = 0; j < allRows.length; j++) {
                var r = allRows[j]
                if (r["Target"] !== name || r["Frame Type"] !== "LIGHT") continue
                if ((r["Start Time UTC"] || "").substring(0, 10) === lastDate)
                    lastSessionSecs += Number(r["Total Exposure Time s"]) || 0
            }
        }

        // Build sorted exposure list
        var expList = []
        for (var k in expGroups) expList.push({ key: k, count: expGroups[k] })
        expList.sort(function(a, b) { return parseFloat(a.key) - parseFloat(b.key) })

        return {
            catalog:         root.classifyCatalog(name),
            expList:         expList,
            lastDate:        lastDate || "—",
            lastSessionSecs: lastSessionSecs
        }
    }

    Column {
        id: col
        anchors.top:     parent.top
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.margins: 16
        spacing: 10

        Text {
            text: "Catalog Breakdown"
            font.pixelSize: 20; font.bold: true
            color: window.sysPal.windowText; width: parent.width
        }

        // Catalog chips grid
        Grid {
            id: catalogGrid
            width: parent.width
            visible: root.rowCount > 0
            readonly property int minChipW: 100
            readonly property int gap: 8
            columns: Math.max(1, Math.floor((width + gap) / (minChipW + gap)))
            columnSpacing: gap
            rowSpacing:    gap

            Repeater {
                model: catalogModel
                delegate: Rectangle {
                    required property var model
                    width:  Math.floor((catalogGrid.width
                                        - (catalogGrid.columns - 1) * catalogGrid.gap)
                                       / catalogGrid.columns)
                    height: 36; radius: 6
                    color: ma.containsMouse ? window.sysPal.highlight : window.sysPal.alternateBase
                    border.color: ma.containsMouse ? window.sysPal.highlight : window.sysPal.mid
                    border.width: 1
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:    parent.left
                        anchors.right:   parent.right
                        anchors.margins: 8
                        spacing: 4
                        Text {
                            text: model.catalogName || ""
                            color: ma.containsMouse ? window.sysPal.highlightedText : window.sysPal.windowText
                            font.pixelSize: 13
                            width: parent.width - 36
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: 28; height: 20; radius: 10
                            color: window.sysPal.highlight
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: model.catalogCount || "0"
                                color: window.sysPal.highlightedText
                                font.pixelSize: 11; font.bold: true
                            }
                        }
                    }
                    MouseArea {
                        id: ma; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.catalogSelected(model.catalogName)
                    }
                }
            }
        }

        Text {
            text: "Scan FITS files to see catalog breakdown."
            color: window.sysPal.placeholderText; font.pixelSize: 13
            visible: root.rowCount === 0; width: parent.width
        }

        // ── Target detail section (shown when a target is selected) ──────────

        Rectangle {
            width: parent.width; height: 1
            color: window.sysPal.mid
            visible: root.targetDetails !== null
        }

        Column {
            width: parent.width
            spacing: 8
            visible: root.targetDetails !== null

            // Header row: target name + catalog badge
            Row {
                spacing: 8
                Text {
                    text: root.selectedTarget
                    font.pixelSize: 14; font.bold: true
                    color: window.sysPal.windowText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    height: 20; radius: 10
                    width: catalogBadge.implicitWidth + 16
                    color: window.sysPal.highlight
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        id: catalogBadge
                        anchors.centerIn: parent
                        text: root.targetDetails ? root.targetDetails.catalog : ""
                        color: window.sysPal.highlightedText
                        font.pixelSize: 11; font.bold: true
                    }
                }
            }

            // Exposure breakdown row
            Row {
                width: parent.width
                spacing: 6
                Text {
                    text: "Exposures"
                    font.pixelSize: 11; font.bold: true
                    color: window.sysPal.placeholderText
                    width: 72
                    anchors.top: parent.top; topPadding: 3
                }
                Flow {
                    width: parent.width - 78
                    spacing: 4
                    Repeater {
                        model: root.targetDetails ? root.targetDetails.expList : []
                        delegate: Rectangle {
                            required property var modelData
                            height: 22; radius: 4
                            width: expLabel.implicitWidth + 16
                            color: window.sysPal.alternateBase
                            border.color: window.sysPal.mid; border.width: 1
                            Text {
                                id: expLabel
                                anchors.centerIn: parent
                                text: modelData.key + " × " + modelData.count
                                font.pixelSize: 11
                                color: window.sysPal.windowText
                            }
                        }
                    }
                    Text {
                        text: "No exposure data"
                        font.pixelSize: 11; color: window.sysPal.placeholderText
                        visible: !root.targetDetails || root.targetDetails.expList.length === 0
                    }
                }
            }

            // Last session row
            Row {
                spacing: 6
                Text {
                    text: "Last session"
                    font.pixelSize: 11; font.bold: true
                    color: window.sysPal.placeholderText
                    width: 72
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.targetDetails ? root.targetDetails.lastDate : "—"
                    font.pixelSize: 12; color: window.sysPal.windowText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "·"
                    font.pixelSize: 12; color: window.sysPal.placeholderText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.targetDetails && root.targetDetails.lastSessionSecs > 0
                }
                Text {
                    text: root.targetDetails && root.targetDetails.lastSessionSecs > 0
                          ? root.fmtHMS(root.targetDetails.lastSessionSecs) + " observed"
                          : ""
                    font.pixelSize: 12; color: window.sysPal.windowText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.targetDetails && root.targetDetails.lastSessionSecs > 0
                }
            }
        }

        Item { width: 1; height: 4 }
    }
}
