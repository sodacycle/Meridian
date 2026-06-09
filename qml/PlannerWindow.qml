import QtQuick
import QtQuick.Controls

Window {
    id: plannerWindow
    title: "Meridian — Observation Planner"
    width:  1200
    height: 780
    minimumWidth:  900
    minimumHeight: 600

    SystemPalette { id: pal; colorGroup: SystemPalette.Active }
    color: pal.window

    // Location — populated from weatherService on open and on location changes.
    property real latitude:  0.0
    property real longitude: 0.0
    readonly property bool hasLocation: (latitude !== 0.0 || longitude !== 0.0)

    // Night offset: 0 = tonight, 1 = tomorrow night, …
    property int nightOffset: 0

    // Currently selected object from the list (PlannerEntry Q_GADGET or null)
    property var selectedObj: null

    // ── UI-only helpers ───────────────────────────────────────────────────────

    // UTC Date object for 23:00 local on the selected night (used by Canvas)
    function localMidnightUTC() {
        var d = new Date()
        d.setHours(23, 0, 0, 0)
        d.setDate(d.getDate() + nightOffset)
        return d
    }

    function nightLabel() {
        var d = new Date()
        d.setDate(d.getDate() + nightOffset)
        if (nightOffset === 0) return "Tonight"
        if (nightOffset === 1) return "Tomorrow"
        return d.toLocaleDateString(Qt.locale().name, { weekday: "short", month: "short", day: "numeric" })
    }

    // ── Formatters ────────────────────────────────────────────────────────────
    function fmtMag(mag) {
        return (mag === undefined || mag === null || mag >= 99.0) ? "—" : mag.toFixed(1)
    }
    function fmtSize(sizeArcmin) {
        if (!sizeArcmin || sizeArcmin <= 0) return "—"
        if (sizeArcmin >= 60) return (sizeArcmin / 60.0).toFixed(1) + "°"
        return sizeArcmin.toFixed(1) + "'"
    }
    function fmtAlt(a) { return a.toFixed(1) + "°" }
    function fmtWindow(circumpolar, windowH) {
        if (circumpolar) return "All night"
        if (!windowH || windowH <= 0) return "—"
        var h = Math.floor(windowH)
        var m = Math.round((windowH - h) * 60)
        return h + "h" + (m > 0 ? " " + m + "m" : "")
    }
    function fmtRA(raH) {
        var h = Math.floor(raH)
        var m = Math.floor((raH - h) * 60)
        return h + "h " + (m < 10 ? "0" : "") + m + "m"
    }
    function fmtDec(decD) {
        var neg  = decD < 0
        var abs  = Math.abs(decD)
        var d    = Math.floor(abs)
        var m    = Math.floor((abs - d) * 60)
        return (neg ? "−" : "+") + d + "° " + (m < 10 ? "0" : "") + m + "'"
    }

    // ── Reactivity ────────────────────────────────────────────────────────────
    onLatitudeChanged:    plannerService.compute(latitude, longitude, nightOffset)
    onLongitudeChanged:   plannerService.compute(latitude, longitude, nightOffset)
    onNightOffsetChanged: plannerService.compute(latitude, longitude, nightOffset)

    Component.onCompleted: {
        latitude  = weatherService.latitude
        longitude = weatherService.longitude
        plannerService.compute(latitude, longitude, nightOffset)
    }

    Connections {
        target: weatherService
        function onLocationChanged() {
            plannerWindow.latitude  = weatherService.latitude
            plannerWindow.longitude = weatherService.longitude
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────
    Rectangle {
        id: headerBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 52
        color: pal.alternateBase

        Row {
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 12

            Text {
                text: "Observation Planner"
                font.pixelSize: 17; font.bold: true
                color: pal.windowText
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle { width: 1; height: 28; color: pal.mid; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: plannerWindow.hasLocation
                      ? ("Lat " + plannerWindow.latitude.toFixed(4)
                         + "°  ·  Lon " + plannerWindow.longitude.toFixed(4) + "°")
                      : "No location — scan FITS files to set location"
                font.pixelSize: 13
                color: plannerWindow.hasLocation ? pal.windowText : pal.placeholderText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Night selector (right-anchored)
        Row {
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 4

            Button {
                text: "‹"; flat: true
                enabled: plannerWindow.nightOffset > 0
                onClicked: plannerWindow.nightOffset--
                implicitWidth: 28; implicitHeight: 28
            }
            Text {
                text: plannerWindow.nightLabel()
                font.pixelSize: 13; font.bold: true
                color: pal.windowText
                anchors.verticalCenter: parent.verticalCenter
                width: 130; horizontalAlignment: Text.AlignHCenter
            }
            Button {
                text: "›"; flat: true
                enabled: plannerWindow.nightOffset < 6
                onClicked: plannerWindow.nightOffset++
                implicitWidth: 28; implicitHeight: 28
            }
        }
    }

    // ── Body ─────────────────────────────────────────────────────────────────
    Item {
        anchors { top: headerBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }

        // ── Object list (left ~55 %) ──────────────────────────────────────────
        Item {
            id: listPanel
            anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
            width: parent.width * 0.55

            // Column header
            Row {
                id: listHeader
                anchors { top: parent.top; topMargin: 10; left: parent.left; leftMargin: 12 }
                height: 28; spacing: 0
                Repeater {
                    model: [
                        { label: "Name",       w: 140 },
                        { label: "Type",       w: 158 },
                        { label: "Con",        w: 42  },
                        { label: "Mag",        w: 48  },
                        { label: "Size",       w: 58  },
                        { label: "Peak Alt",   w: 72  },
                        { label: "Visible",    w: 72  },
                    ]
                    Rectangle {
                        width: modelData.w; height: 28
                        color: pal.alternateBase
                        Text {
                            anchors.fill: parent; anchors.leftMargin: 6
                            text: modelData.label; color: pal.windowText
                            font.pixelSize: 11; font.bold: true
                            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                        }
                    }
                }
            }

            ListView {
                id: objList
                anchors {
                    top: listHeader.bottom; left: parent.left; leftMargin: 12
                    right: parent.right; bottom: parent.bottom; bottomMargin: 8
                }
                clip: true
                model: plannerService.objects
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Item {
                    id: row
                    required property string name
                    required property string commonName
                    required property string type
                    required property string constellation
                    required property double mag
                    required property double sizeArcmin
                    required property double peakAlt
                    required property double windowH
                    required property bool   circumpolar
                    required property double raHours
                    required property double decDeg
                    required property double altAtMidnight
                    required property int    index
                    width: objList.width
                    height: 28

                    readonly property bool isSelected:
                        plannerWindow.selectedObj !== null &&
                        plannerWindow.selectedObj.name === name

                    property color textColor:
                        (isSelected || rowMouse.containsMouse)
                        ? pal.highlightedText : pal.windowText

                    Rectangle {
                        anchors.fill: parent; radius: 2
                        color: row.isSelected
                               ? pal.highlight
                               : (rowMouse.containsMouse
                                  ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.35)
                                  : (row.index % 2 === 0 ? pal.alternateBase : "transparent"))
                    }

                    Row {
                        anchors.fill: parent; spacing: 0
                        Text { width: 140; height: 28; leftPadding: 6
                               text: row.commonName !== "" ? row.commonName : row.name
                               color: row.textColor; font.pixelSize: 12
                               verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                        Text { width: 158; height: 28; leftPadding: 6
                               text: row.type
                               color: row.textColor; font.pixelSize: 12
                               verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                        Text { width: 42;  height: 28; leftPadding: 6
                               text: row.constellation
                               color: row.textColor; font.pixelSize: 12
                               verticalAlignment: Text.AlignVCenter }
                        Text { width: 48;  height: 28; leftPadding: 6
                               text: plannerWindow.fmtMag(row.mag)
                               color: row.textColor; font.pixelSize: 12
                               verticalAlignment: Text.AlignVCenter }
                        Text { width: 58;  height: 28; leftPadding: 6
                               text: plannerWindow.fmtSize(row.sizeArcmin)
                               color: row.textColor; font.pixelSize: 12
                               verticalAlignment: Text.AlignVCenter }
                        Text { width: 72;  height: 28; leftPadding: 6
                               text: plannerWindow.fmtAlt(row.peakAlt)
                               color: row.textColor; font.pixelSize: 12
                               verticalAlignment: Text.AlignVCenter }
                        Text { width: 72;  height: 28; leftPadding: 6
                               text: plannerWindow.fmtWindow(row.circumpolar, row.windowH)
                               color: row.textColor; font.pixelSize: 12
                               verticalAlignment: Text.AlignVCenter }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: plannerWindow.selectedObj = plannerService.objects.entryAt(index)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: !plannerWindow.hasLocation
                          ? "Scan FITS files to set your location.\nThe planner will then list tonight's best objects."
                          : (!catalogService.ready ? "Loading catalog…" : "No objects found for this night.")
                    color: pal.placeholderText; font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.5
                    visible: plannerService.objects.count === 0
                }
            }
        }

        // Divider
        Rectangle {
            id: divider
            anchors { top: parent.top; bottom: parent.bottom; left: listPanel.right }
            width: 1; color: pal.mid
        }

        // ── Detail panel (right ~45 %) ────────────────────────────────────────
        Item {
            anchors { top: parent.top; left: divider.right; right: parent.right; bottom: parent.bottom }

            property var obj: plannerWindow.selectedObj

            // Placeholder
            Text {
                anchors.centerIn: parent
                text: "Select an object to see details"
                color: pal.placeholderText; font.pixelSize: 13
                visible: !parent.obj
            }

            // Detail content
            Column {
                anchors { fill: parent; margins: 18 }
                spacing: 12
                visible: !!parent.obj
                property var obj: parent.obj || {}

                // Name
                Column {
                    spacing: 3
                    Text {
                        text: parent.parent.obj.commonName !== ""
                              ? parent.parent.obj.commonName : parent.parent.obj.name || ""
                        font.pixelSize: 22; font.bold: true
                        color: pal.windowText
                    }
                    Text {
                        text: {
                            var o = parent.parent.obj
                            if (!o) return ""
                            var parts = []
                            if (o.commonName !== "" && o.name !== "") parts.push(o.name)
                            if (o.constellation !== "") parts.push(o.constellation)
                            return parts.join("  ·  ")
                        }
                        font.pixelSize: 13; color: pal.placeholderText
                        visible: text !== ""
                    }
                }

                // Type badge
                Rectangle {
                    width: typeLabel.implicitWidth + 16; height: 22; radius: 11
                    color: pal.highlight
                    Text {
                        id: typeLabel
                        anchors.centerIn: parent
                        text: parent.parent.parent.obj.type || ""
                        color: pal.highlightedText; font.pixelSize: 11; font.bold: true
                    }
                }

                Rectangle { width: parent.width; height: 1; color: pal.mid }

                // Stats grid
                Grid {
                    id: statsGrid
                    columns: 2; columnSpacing: 20; rowSpacing: 8
                    property var obj: parent.obj

                    Text { text: "Magnitude";     color: pal.placeholderText; font.pixelSize: 12 }
                    Text { text: plannerWindow.fmtMag(statsGrid.obj.mag);        color: pal.windowText; font.pixelSize: 12 }

                    Text { text: "Size";           color: pal.placeholderText; font.pixelSize: 12 }
                    Text { text: plannerWindow.fmtSize(statsGrid.obj.sizeArcmin); color: pal.windowText; font.pixelSize: 12 }

                    Text { text: "Peak Altitude";  color: pal.placeholderText; font.pixelSize: 12 }
                    Text { text: statsGrid.obj.peakAlt !== undefined
                                 ? plannerWindow.fmtAlt(statsGrid.obj.peakAlt) : "—"
                           color: pal.windowText; font.pixelSize: 12 }

                    Text { text: "Visible Window"; color: pal.placeholderText; font.pixelSize: 12 }
                    Text { text: plannerWindow.fmtWindow(statsGrid.obj.circumpolar, statsGrid.obj.windowH)
                           color: pal.windowText; font.pixelSize: 12 }

                    Text { text: "RA  /  Dec";     color: pal.placeholderText; font.pixelSize: 12 }
                    Text { text: statsGrid.obj.raHours !== undefined
                                 ? (plannerWindow.fmtRA(statsGrid.obj.raHours) + "  ·  "
                                    + plannerWindow.fmtDec(statsGrid.obj.decDeg)) : "—"
                           color: pal.windowText; font.pixelSize: 12 }
                }

                Rectangle { width: parent.width; height: 1; color: pal.mid }

                // Sky arc
                Text {
                    text: "Sky Arc  —  " + plannerWindow.nightLabel()
                    font.pixelSize: 12; color: pal.placeholderText
                }

                Canvas {
                    id: skyCanvas
                    width: parent.width
                    height: Math.min(200, plannerWindow.height - 420)

                    property var watchObj: plannerWindow.selectedObj

                    onWatchObjChanged: requestPaint()
                    onWidthChanged:    requestPaint()
                    onHeightChanged:   requestPaint()

                    onPaint: {
                        var ctx2d = getContext("2d")
                        ctx2d.clearRect(0, 0, width, height)

                        var o = plannerWindow.selectedObj
                        if (!o || !plannerWindow.hasLocation || height < 40) return

                        var cx = width / 2
                        var cy = height - 14
                        var r  = cy - 4   // radius: zenith to horizon

                        // Horizon line
                        ctx2d.strokeStyle = pal.mid.toString()
                        ctx2d.lineWidth = 1
                        ctx2d.setLineDash([])
                        ctx2d.beginPath(); ctx2d.moveTo(0, cy); ctx2d.lineTo(width, cy); ctx2d.stroke()

                        // Altitude reference lines
                        ctx2d.setLineDash([2, 4])
                        ctx2d.lineWidth = 0.5
                        ctx2d.font = "10px sans-serif"
                        ctx2d.fillStyle = pal.placeholderText.toString()
                        ctx2d.textAlign = "left"
                        for (var alt = 30; alt <= 80; alt += 30) {
                            var ytick = cy - (alt / 90.0) * r
                            ctx2d.strokeStyle = pal.mid.toString()
                            ctx2d.beginPath(); ctx2d.moveTo(24, ytick); ctx2d.lineTo(width, ytick); ctx2d.stroke()
                            ctx2d.fillText(alt + "°", 2, ytick + 4)
                        }
                        ctx2d.setLineDash([])

                        // Time labels
                        ctx2d.fillStyle = pal.placeholderText.toString()
                        ctx2d.textAlign = "center"
                        ctx2d.font = "10px sans-serif"
                        ctx2d.fillText("−6h", cx - r / 2, cy + 12)
                        ctx2d.fillText("midnight", cx, cy + 12)
                        ctx2d.fillText("+6h", cx + r / 2, cy + 12)

                        // Compute arc: sample from −12h to +12h around midnight
                        var midnight = plannerWindow.localMidnightUTC()
                        var jdMid   = plannerService.toJD(midnight.getTime())
                        var lstMid  = plannerService.lst(jdMid, plannerWindow.longitude)

                        ctx2d.beginPath()
                        var started = false
                        for (var step = 0; step <= 96; step++) {
                            var h = -12.0 + step * 0.25
                            var jd = jdMid + h / 24.0
                            var lstH = plannerService.lst(jd, plannerWindow.longitude)
                            var altH = plannerService.altitudeDeg(
                                           o.raHours, o.decDeg,
                                           plannerWindow.latitude, lstH)

                            var px = cx + (h / 12.0) * r
                            var py = cy - (altH / 90.0) * r

                            if (altH < 15.0) { started = false; continue }
                            if (!started) { ctx2d.moveTo(px, py); started = true }
                            else ctx2d.lineTo(px, py)
                        }
                        ctx2d.strokeStyle = pal.highlight.toString()
                        ctx2d.lineWidth = 2.5
                        ctx2d.stroke()

                        // Midnight dot
                        var altMid = plannerService.altitudeDeg(
                                         o.raHours, o.decDeg, plannerWindow.latitude, lstMid)
                        if (altMid >= 15.0) {
                            var dotY = cy - (altMid / 90.0) * r
                            ctx2d.fillStyle = pal.highlight.toString()
                            ctx2d.beginPath(); ctx2d.arc(cx, dotY, 4, 0, 2 * Math.PI); ctx2d.fill()
                        }
                    }
                }
            }
        }
    }
}
