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

    property real focusAltDeg: 90.0
    property real focusAzDeg:  0.0
    property real zoom:  1.0
    property bool showGrid: true
    property bool showLabels: true
    property string selectedName: ""

    property double nowMs: Date.now()
    property var objects: []

    signal objectSelected(var entry)

    function resetView() {
        focusAltDeg = 90.0; focusAzDeg = 0.0; zoom = 1.0
        domeCanvas.requestPaint()
    }

    function rebuildObjects() {
        var list = []
        var model = plannerService.objects
        var n = model.count
        for (var i = 0; i < n; i++) {
            var e = model.entryAt(i)
            var integ = targetSummaryModel.integrationSecondsForTarget(e.name)
            list.push({
                index: i,
                name: e.name,
                commonName: e.commonName,
                type: e.type,
                raHours: e.raHours,
                decDeg: e.decDeg,
                mag: e.mag,
                integ: integ,
                observed: integ > 0
            })
        }
        var observedTotal = 0
        for (var a = 0; a < list.length; a++) if (list[a].observed) observedTotal++
        var obsIdx = 0
        for (var b = 0; b < list.length; b++) {
            if (list[b].observed) {
                list[b].color = Qt.hsva(obsIdx / Math.max(1, observedTotal), 0.65, 0.95, 1.0)
                obsIdx++
            } else {
                list[b].color = null
            }
        }
        objects = list
        domeCanvas.requestPaint()
    }

    onVisibleChanged: if (visible) { nowMs = Date.now(); rebuildObjects() }
    onLatitudeChanged:  domeCanvas.requestPaint()
    onLongitudeChanged: domeCanvas.requestPaint()
    onSelectedNameChanged: domeCanvas.requestPaint()

    Connections {
        target: plannerService.objects
        function onModelReset() { skyArcDetailedWindow.rebuildObjects() }
    }

    Timer {
        interval: 30000; running: skyArcDetailedWindow.visible; repeat: true
        onTriggered: { skyArcDetailedWindow.nowMs = Date.now(); domeCanvas.requestPaint() }
    }

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

            Button {
                text: "Zoom In"; flat: true; implicitHeight: 28
                onClicked: skyArcDetailedWindow.zoom = Math.min(8.0, skyArcDetailedWindow.zoom * 1.2)
            }
            Button {
                text: "Zoom Out"; flat: true; implicitHeight: 28
                onClicked: skyArcDetailedWindow.zoom = Math.max(0.5, skyArcDetailedWindow.zoom / 1.2)
            }
            Button {
                text: "Reset View"; flat: true; implicitHeight: 28
                onClicked: skyArcDetailedWindow.resetView()
            }
            Button {
                text: "Grid"; flat: true; implicitHeight: 28; checkable: true
                checked: skyArcDetailedWindow.showGrid
                onToggled: skyArcDetailedWindow.showGrid = checked
            }
            Button {
                text: "Labels"; flat: true; implicitHeight: 28; checkable: true
                checked: skyArcDetailedWindow.showLabels
                onToggled: skyArcDetailedWindow.showLabels = checked
            }
        }
    }

    Item {
        id: domeArea
        anchors { top: headerBar.bottom; left: parent.left; right: featurePanel.left; bottom: parent.bottom }
        clip: true

        Canvas {
            id: domeCanvas
            anchors.fill: parent

            property var screenObjects: []
            readonly property real scaleFactor:
                (Math.min(width, height) / 2 - 44) / (Math.PI / 2) * skyArcDetailedWindow.zoom

            property real wfa: skyArcDetailedWindow.focusAltDeg
            property real wfz: skyArcDetailedWindow.focusAzDeg
            property real wz:  skyArcDetailedWindow.zoom
            property bool wg:  skyArcDetailedWindow.showGrid
            property bool wl:  skyArcDetailedWindow.showLabels
            property var  wobj: skyArcDetailedWindow.objects
            property double wnow: skyArcDetailedWindow.nowMs
            onWfaChanged: requestPaint()
            onWfzChanged: requestPaint()
            onWzChanged:  requestPaint()
            onWgChanged:  requestPaint()
            onWlChanged:  requestPaint()
            onWobjChanged: requestPaint()
            onWnowChanged: requestPaint()
            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()

            function selectAt(mx, my) {
                var best = null, bestD = 16 * 16
                for (var i = 0; i < screenObjects.length; i++) {
                    var s = screenObjects[i]
                    var dx = s.x - mx, dy = s.y - my
                    var d = dx * dx + dy * dy
                    if (d < bestD) { bestD = d; best = s }
                }
                if (best) {
                    skyArcDetailedWindow.selectedName = best.name
                    skyArcDetailedWindow.objectSelected(plannerService.objects.entryAt(best.index))
                }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                screenObjects = []
                if (!skyArcDetailedWindow.hasLocation) {
                    ctx.fillStyle = pal.placeholderText.toString()
                    ctx.font = "14px sans-serif"; ctx.textAlign = "center"
                    ctx.fillText("No location set — open from the planner with a site location.",
                                 width / 2, height / 2)
                    return
                }

                var DEG = Math.PI / 180
                var lat = skyArcDetailedWindow.latitude
                var lon = skyArcDetailedWindow.longitude
                var cx = width / 2, cy = height / 2
                var scale = domeCanvas.scaleFactor
                var cMax = 1.74

                var alt0 = skyArcDetailedWindow.focusAltDeg * DEG
                var az0  = skyArcDetailedWindow.focusAzDeg * DEG
                var sinA0 = Math.sin(alt0), cosA0 = Math.cos(alt0)

                function proj(altDeg, azDeg) {
                    var alt = altDeg * DEG, az = azDeg * DEG
                    var dAz = az - az0
                    var sa = Math.sin(alt), ca = Math.cos(alt)
                    var cosc = Math.max(-1, Math.min(1, sinA0 * sa + cosA0 * ca * Math.cos(dAz)))
                    var c = Math.acos(cosc)
                    var k = (c < 1e-6) ? 1 : c / Math.sin(c)
                    var X = k * ca * Math.sin(dAz)
                    var Y = k * (cosA0 * sa - sinA0 * ca * Math.cos(dAz))
                    return { x: cx + scale * X, y: cy - scale * Y, c: c }
                }

                function strokeSky(samples, close) {
                    ctx.beginPath()
                    var drawing = false
                    for (var i = 0; i < samples.length; i++) {
                        var p = proj(samples[i][0], samples[i][1])
                        if (p.c > cMax) { drawing = false; continue }
                        if (!drawing) { ctx.moveTo(p.x, p.y); drawing = true }
                        else ctx.lineTo(p.x, p.y)
                    }
                    if (close && drawing) ctx.closePath()
                    ctx.stroke()
                }

                function drawPath(decDeg, strokeColor, lw) {
                    ctx.strokeStyle = strokeColor; ctx.lineWidth = lw; ctx.setLineDash([])
                    ctx.beginPath()
                    var drawing = false
                    for (var ha = 0; ha <= 360; ha += 2) {
                        var palt = plannerService.altitudeDeg(0, decDeg, lat, ha)
                        if (palt < 0) { drawing = false; continue }
                        var paz = plannerService.azimuthDeg(0, decDeg, lat, ha)
                        var pp = proj(palt, paz)
                        if (pp.c > cMax) { drawing = false; continue }
                        if (!drawing) { ctx.moveTo(pp.x, pp.y); drawing = true }
                        else ctx.lineTo(pp.x, pp.y)
                    }
                    ctx.stroke()
                }

                if (skyArcDetailedWindow.showGrid) {
                    ctx.strokeStyle = Qt.rgba(pal.mid.r, pal.mid.g, pal.mid.b, 0.5)
                    ctx.lineWidth = 0.5; ctx.setLineDash([2, 4])
                    for (var ringAlt = 15; ringAlt <= 75; ringAlt += 15) {
                        var ring = []
                        for (var ra = 0; ra <= 360; ra += 3) ring.push([ringAlt, ra])
                        strokeSky(ring, false)
                    }
                    for (var spokeAz = 0; spokeAz < 360; spokeAz += 30) {
                        var meridian = (spokeAz === 0 || spokeAz === 180)
                        ctx.setLineDash(meridian ? [] : [2, 4])
                        ctx.lineWidth = meridian ? 1.0 : 0.5
                        ctx.strokeStyle = meridian ? pal.mid.toString()
                                                   : Qt.rgba(pal.mid.r, pal.mid.g, pal.mid.b, 0.5)
                        var spoke = []
                        for (var sa2 = 0; sa2 <= 88; sa2 += 2) spoke.push([sa2, spokeAz])
                        strokeSky(spoke, false)
                    }
                    ctx.setLineDash([])
                }

                ctx.strokeStyle = pal.windowText.toString()
                ctx.lineWidth = 1.5; ctx.setLineDash([])
                var horizon = []
                for (var ha = 0; ha <= 360; ha += 2) horizon.push([0, ha])
                strokeSky(horizon, false)

                ctx.fillStyle = pal.placeholderText.toString()
                ctx.beginPath()
                var z = proj(90, 0)
                if (z.c < cMax) { ctx.arc(z.x, z.y, 2, 0, 2 * Math.PI); ctx.fill() }

                var compass = [["N", 0], ["E", 90], ["S", 180], ["W", 270],
                               ["NE", 45], ["SE", 135], ["SW", 225], ["NW", 315]]
                ctx.textAlign = "center"; ctx.textBaseline = "middle"
                for (var ci = 0; ci < compass.length; ci++) {
                    var cp = proj(0, compass[ci][1])
                    if (cp.c > cMax) continue
                    var dx = cp.x - cx, dy = cp.y - cy
                    var len = Math.max(1, Math.sqrt(dx * dx + dy * dy))
                    var lx = cp.x + dx / len * 14, ly = cp.y + dy / len * 14
                    var one = compass[ci][0].length === 1
                    ctx.font = one ? "bold 14px sans-serif" : "11px sans-serif"
                    ctx.fillStyle = one ? pal.windowText.toString() : pal.placeholderText.toString()
                    ctx.fillText(compass[ci][0], lx, ly)
                }
                ctx.textBaseline = "alphabetic"

                var nowJd = plannerService.toJD(skyArcDetailedWindow.nowMs)
                var lstNow = plannerService.lst(nowJd, lon)
                var accent = pal.highlight.toString()
                var faint  = Qt.rgba(pal.windowText.r, pal.windowText.g, pal.windowText.b, 0.5)
                var faintAccent = Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.35)

                var selDec = null, selColor = accent
                for (var pi = 0; pi < skyArcDetailedWindow.objects.length; pi++) {
                    var po = skyArcDetailedWindow.objects[pi]
                    if (po.name === skyArcDetailedWindow.selectedName) {
                        selDec = po.decDeg
                        if (po.color) selColor = po.color.toString()
                        continue
                    }
                    if (po.observed) drawPath(po.decDeg, po.color.toString(), 1.6)
                }
                if (selDec !== null) drawPath(selDec, selColor, 2.8)

                for (var oi = 0; oi < skyArcDetailedWindow.objects.length; oi++) {
                    var o = skyArcDetailedWindow.objects[oi]
                    var alt = plannerService.altitudeDeg(o.raHours, o.decDeg, lat, lstNow)
                    if (alt < 0) continue
                    var azv = plannerService.azimuthDeg(o.raHours, o.decDeg, lat, lstNow)
                    var p = proj(alt, azv)
                    if (p.c > cMax) continue
                    if (p.x < -20 || p.x > width + 20 || p.y < -20 || p.y > height + 20) continue

                    var isSel = (o.name === skyArcDetailedWindow.selectedName)
                    var dotR = o.observed ? (3 + Math.min(6, Math.sqrt(o.integ / 3600))) : 2.0
                    var oCol = o.color ? o.color.toString() : (isSel ? accent : faint)

                    ctx.fillStyle = o.observed ? oCol : faint
                    ctx.beginPath(); ctx.arc(p.x, p.y, dotR, 0, 2 * Math.PI); ctx.fill()

                    if (isSel) {
                        ctx.strokeStyle = oCol; ctx.lineWidth = 2
                        ctx.beginPath(); ctx.arc(p.x, p.y, dotR + 4, 0, 2 * Math.PI); ctx.stroke()
                    }

                    if (skyArcDetailedWindow.showLabels && (o.observed || isSel)) {
                        ctx.fillStyle = isSel ? oCol : pal.windowText.toString()
                        ctx.font = isSel ? "bold 11px sans-serif" : "10px sans-serif"
                        ctx.textAlign = "left"
                        var nm = (o.commonName && o.commonName !== "") ? o.commonName : o.name
                        ctx.fillText(nm, p.x + dotR + 3, p.y + 3)
                    }

                    screenObjects.push({ x: p.x, y: p.y, name: o.name, index: o.index })
                }
            }

            MouseArea {
                id: domeMouse
                anchors.fill: parent
                property real lastX: 0
                property real lastY: 0
                property bool dragging: false
                cursorShape: Qt.OpenHandCursor
                onPressed: function(mouse) { lastX = mouse.x; lastY = mouse.y; dragging = false }
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        var dx = mouse.x - lastX, dy = mouse.y - lastY
                        if (Math.abs(dx) + Math.abs(dy) > 3) dragging = true
                        var radPerPx = 1.0 / domeCanvas.scaleFactor
                        var deg = radPerPx * 180 / Math.PI
                        var fa = skyArcDetailedWindow.focusAltDeg + dy * deg
                        skyArcDetailedWindow.focusAltDeg = Math.max(0, Math.min(90, fa))
                        var fz = skyArcDetailedWindow.focusAzDeg - dx * deg
                        skyArcDetailedWindow.focusAzDeg = ((fz % 360) + 360) % 360
                        lastX = mouse.x; lastY = mouse.y
                    }
                }
                onReleased: function(mouse) {
                    if (!dragging) domeCanvas.selectAt(mouse.x, mouse.y)
                }
            }

            WheelHandler {
                onWheel: function(event) {
                    var f = event.angleDelta.y > 0 ? 1.15 : 0.87
                    skyArcDetailedWindow.zoom = Math.max(0.5, Math.min(8.0, skyArcDetailedWindow.zoom * f))
                }
            }
        }
    }

    Rectangle {
        id: featurePanel
        anchors { top: headerBar.bottom; right: parent.right; bottom: parent.bottom }
        width: 300
        color: Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.04)

        Rectangle {
            anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
            width: 1; color: pal.mid
        }

        property var selObj: {
            var name = skyArcDetailedWindow.selectedName
            if (!name) return null
            var list = skyArcDetailedWindow.objects
            for (var i = 0; i < list.length; i++) if (list[i].name === name) return list[i]
            return null
        }

        Column {
            anchors { fill: parent; margins: 20 }
            spacing: 12

            Text {
                text: "Live Sky"
                font.pixelSize: 11; font.bold: true; color: pal.placeholderText
            }
            Text {
                width: parent.width
                text: {
                    var t = new Date(skyArcDetailedWindow.nowMs)
                    var hh = t.getUTCHours(), mm = t.getUTCMinutes()
                    return "Now " + (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm + " UTC"
                }
                font.pixelSize: 13; color: pal.windowText
            }
            Text {
                width: parent.width
                text: "Centre " + Math.round(skyArcDetailedWindow.focusAltDeg) + "° alt · "
                      + Math.round(skyArcDetailedWindow.focusAzDeg) + "° az · " + skyArcDetailedWindow.zoom.toFixed(1) + "×"
                font.pixelSize: 11; color: pal.placeholderText
            }

            Rectangle { width: parent.width; height: 1; color: pal.mid }

            Text {
                text: "Selected Object"
                font.pixelSize: 11; font.bold: true; color: pal.placeholderText
            }
            Text {
                width: parent.width
                text: featurePanel.selObj
                      ? ((featurePanel.selObj.commonName && featurePanel.selObj.commonName !== "")
                         ? featurePanel.selObj.commonName : featurePanel.selObj.name)
                      : "Click an object on the dome"
                font.pixelSize: 15; font.bold: true; color: pal.windowText
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                visible: featurePanel.selObj !== null
                text: featurePanel.selObj
                      ? (featurePanel.selObj.type
                         + (featurePanel.selObj.observed
                            ? "  ·  " + Math.round(featurePanel.selObj.integ / 3600 * 10) / 10 + " h imaged"
                            : "  ·  not yet imaged"))
                      : ""
                font.pixelSize: 12; color: pal.placeholderText
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                visible: featurePanel.selObj !== null
                text: "Selected here is mirrored in the planner's Sky Arc."
                font.pixelSize: 11; color: pal.placeholderText
                wrapMode: Text.WordWrap
            }

            Rectangle { width: parent.width; height: 1; color: pal.mid }

            Text {
                text: "Legend"
                font.pixelSize: 11; font.bold: true; color: pal.placeholderText
            }
            Row {
                spacing: 8
                Rectangle { width: 10; height: 10; radius: 5; color: pal.highlight; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Imaged target (size = integration)"; font.pixelSize: 11; color: pal.windowText
                       anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 8
                Rectangle { width: 6; height: 6; radius: 3
                            color: Qt.rgba(pal.windowText.r, pal.windowText.g, pal.windowText.b, 0.5)
                            anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Catalogue object up now"; font.pixelSize: 11; color: pal.windowText
                       anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: parent.width; height: 1; color: pal.mid }

            Text {
                width: parent.width
                text: "Drag to re-centre the sky · scroll to zoom · click an object to open it in the planner. Positions update live for your location."
                font.pixelSize: 11; color: pal.placeholderText
                wrapMode: Text.WordWrap
            }
        }
    }
}
