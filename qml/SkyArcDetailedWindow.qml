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
    property var stars: []

    signal objectSelected(var entry)

    function resetView() {
        focusAltDeg = 90.0; focusAzDeg = 0.0; zoom = 1.0
        domeCanvas.requestPaint()
    }

    function rebuildObjects() {
        var list = []
        var model = plannerService.objects
        var n = model.entryCount()
        for (var i = 0; i < n; i++) {
            var e = model.entryAt(i)
            var integ = targetSummaryModel.integrationSecondsForTarget(e.name)
            list.push({
                index: i, name: e.name, commonName: e.commonName, type: e.type,
                raHours: e.raHours, decDeg: e.decDeg, mag: e.mag,
                integ: integ, observed: integ > 0
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

    function loadStars() {
        if (stars.length > 0) return
        var raw = catalogService.brightStars()
        var arr = []
        for (var i = 0; i < raw.length; i++) {
            var s = raw[i]
            var decRad = s[1] * Math.PI / 180
            arr.push({ raDeg: s[0] * 15, sinDec: Math.sin(decRad), cosDec: Math.cos(decRad), mag: s[2] })
        }
        stars = arr
        domeCanvas.requestPaint()
    }

    onVisibleChanged: if (visible) { nowMs = Date.now(); rebuildObjects(); loadStars() }
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
            Button { text: "Zoom In"; flat: true; implicitHeight: 28
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Magnify the sky around the current centre.\nYou can also scroll the wheel over the dome."
                onClicked: skyArcDetailedWindow.zoom = Math.min(8.0, skyArcDetailedWindow.zoom * 1.2) }
            Button { text: "Zoom Out"; flat: true; implicitHeight: 28
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Widen the field of view to show more sky."
                onClicked: skyArcDetailedWindow.zoom = Math.max(0.5, skyArcDetailedWindow.zoom / 1.2) }
            Button { text: "Reset View"; flat: true; implicitHeight: 28
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Return to the zenith-centred whole-sky view at 1× zoom."
                onClicked: skyArcDetailedWindow.resetView() }
            Button { text: "Grid"; flat: true; implicitHeight: 28; checkable: true
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Show or hide the horizon, altitude rings,\nand azimuth spokes."
                checked: skyArcDetailedWindow.showGrid
                onToggled: skyArcDetailedWindow.showGrid = checked }
            Button { text: "Labels"; flat: true; implicitHeight: 28; checkable: true
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Show or hide cardinal-direction and object labels."
                checked: skyArcDetailedWindow.showLabels
                onToggled: skyArcDetailedWindow.showLabels = checked }
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
            property bool interacting: false
            readonly property real scaleFactor:
                (Math.min(width, height) / 2 - 44) / (Math.PI / 2) * skyArcDetailedWindow.zoom

            property real wfa: skyArcDetailedWindow.focusAltDeg
            property real wfz: skyArcDetailedWindow.focusAzDeg
            property real wz:  skyArcDetailedWindow.zoom
            property bool wg:  skyArcDetailedWindow.showGrid
            property bool wl:  skyArcDetailedWindow.showLabels
            property var  wobj: skyArcDetailedWindow.objects
            property var  wstars: skyArcDetailedWindow.stars
            property double wnow: skyArcDetailedWindow.nowMs
            onWfaChanged: requestPaint()
            onWfzChanged: requestPaint()
            onWzChanged:  requestPaint()
            onWgChanged:  requestPaint()
            onWlChanged:  requestPaint()
            onWobjChanged: requestPaint()
            onWstarsChanged: requestPaint()
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
                ctx.fillStyle = "#0b1020"
                ctx.fillRect(0, 0, width, height)
                screenObjects = []
                if (!skyArcDetailedWindow.hasLocation) {
                    ctx.fillStyle = "rgba(255,255,255,0.6)"
                    ctx.font = "14px sans-serif"; ctx.textAlign = "center"
                    ctx.fillText("No location set — open from the planner with a site location.",
                                 width / 2, height / 2)
                    return
                }

                var DEG = Math.PI / 180, RAD = 180 / Math.PI
                var lat = skyArcDetailedWindow.latitude
                var lon = skyArcDetailedWindow.longitude
                var altFrac = Math.max(0, Math.min(1, skyArcDetailedWindow.focusAltDeg / 90))
                var cx = width / 2
                var cy = height * (0.5 + (1 - altFrac) * (1 / 6))
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

                function strokeSky(samples) {
                    ctx.beginPath()
                    var drawing = false
                    for (var i = 0; i < samples.length; i++) {
                        var p = proj(samples[i][0], samples[i][1])
                        if (p.c > cMax) { drawing = false; continue }
                        if (!drawing) { ctx.moveTo(p.x, p.y); drawing = true }
                        else ctx.lineTo(p.x, p.y)
                    }
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
                    ctx.setLineDash([2, 4])
                    for (var ringAlt = 15; ringAlt <= 75; ringAlt += 15) {
                        ctx.strokeStyle = "rgba(255,255,255,0.10)"; ctx.lineWidth = 0.5
                        var ring = []
                        for (var ra = 0; ra <= 360; ra += 3) ring.push([ringAlt, ra])
                        strokeSky(ring)
                    }
                    for (var spokeAz = 0; spokeAz < 360; spokeAz += 30) {
                        var meridian = (spokeAz === 0 || spokeAz === 180)
                        ctx.setLineDash(meridian ? [] : [2, 4])
                        ctx.lineWidth = meridian ? 1.0 : 0.5
                        ctx.strokeStyle = meridian ? "rgba(255,255,255,0.22)" : "rgba(255,255,255,0.10)"
                        var spoke = []
                        for (var sa2 = 0; sa2 <= 88; sa2 += 2) spoke.push([sa2, spokeAz])
                        strokeSky(spoke)
                    }
                    ctx.setLineDash([])
                }

                ctx.strokeStyle = "rgba(255,255,255,0.55)"
                ctx.lineWidth = 1.5; ctx.setLineDash([])
                var horizon = []
                for (var hz = 0; hz <= 360; hz += 2) horizon.push([0, hz])
                strokeSky(horizon)

                if (!domeCanvas.interacting && skyArcDetailedWindow.stars.length > 0) {
                    var latRad = lat * DEG, sinLat = Math.sin(latRad), cosLat = Math.cos(latRad)
                    var lstDeg = plannerService.lst(plannerService.toJD(skyArcDetailedWindow.nowMs), lon)
                    ctx.fillStyle = "#ffffff"
                    for (var si = 0; si < skyArcDetailedWindow.stars.length; si++) {
                        var st = skyArcDetailedWindow.stars[si]
                        var haRad = (lstDeg - st.raDeg) * DEG
                        var cosHa = Math.cos(haRad)
                        var sinAlt = sinLat * st.sinDec + cosLat * st.cosDec * cosHa
                        if (sinAlt < 0) continue
                        var altDeg = Math.asin(sinAlt) * RAD
                        var azDeg = Math.atan2(Math.sin(haRad),
                                               cosHa * sinLat - (st.sinDec / st.cosDec) * cosLat) * RAD + 180
                        var sp = proj(altDeg, azDeg)
                        if (sp.c > cMax) continue
                        var r = Math.max(0.4, (6.0 - st.mag) * 0.45)
                        ctx.globalAlpha = Math.max(0.35, Math.min(1.0, (6.5 - st.mag) / 6.0))
                        ctx.beginPath(); ctx.arc(sp.x, sp.y, r, 0, 2 * Math.PI); ctx.fill()
                    }
                    ctx.globalAlpha = 1.0
                }

                ctx.textAlign = "center"; ctx.textBaseline = "middle"
                var compass = [["N", 0], ["E", 90], ["S", 180], ["W", 270],
                               ["NE", 45], ["SE", 135], ["SW", 225], ["NW", 315]]
                for (var ci = 0; ci < compass.length; ci++) {
                    var cp = proj(0, compass[ci][1])
                    if (cp.c > cMax) continue
                    var dxc = cp.x - cx, dyc = cp.y - cy
                    var len = Math.max(1, Math.sqrt(dxc * dxc + dyc * dyc))
                    var one = compass[ci][0].length === 1
                    ctx.font = one ? "bold 14px sans-serif" : "11px sans-serif"
                    ctx.fillStyle = one ? "rgba(255,255,255,0.85)" : "rgba(255,255,255,0.55)"
                    ctx.fillText(compass[ci][0], cp.x + dxc / len * 14, cp.y + dyc / len * 14)
                }
                ctx.textBaseline = "alphabetic"

                var nowJd = plannerService.toJD(skyArcDetailedWindow.nowMs)
                var lstNow = plannerService.lst(nowJd, lon)

                var selDec = null, selColor = "#ffd060"
                for (var pi = 0; pi < skyArcDetailedWindow.objects.length; pi++) {
                    var po = skyArcDetailedWindow.objects[pi]
                    if (po.name === skyArcDetailedWindow.selectedName) {
                        selDec = po.decDeg
                        if (po.color) selColor = po.color.toString()
                        continue
                    }
                    if (po.observed) drawPath(po.decDeg, po.color.toString(), 1.4)
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
                    var oCol = o.color ? o.color.toString() : (isSel ? selColor : "rgba(255,255,255,0.45)")

                    ctx.fillStyle = o.observed ? oCol : "rgba(255,255,255,0.45)"
                    ctx.beginPath(); ctx.arc(p.x, p.y, dotR, 0, 2 * Math.PI); ctx.fill()

                    if (isSel) {
                        ctx.strokeStyle = oCol; ctx.lineWidth = 2
                        ctx.beginPath(); ctx.arc(p.x, p.y, dotR + 5, 0, 2 * Math.PI); ctx.stroke()
                    }

                    if (skyArcDetailedWindow.showLabels && (o.observed || isSel)) {
                        ctx.fillStyle = isSel ? oCol : "rgba(255,255,255,0.85)"
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
                        if (Math.abs(dx) + Math.abs(dy) > 3) { dragging = true; domeCanvas.interacting = true }
                        var deg = (1.0 / domeCanvas.scaleFactor) * 180 / Math.PI
                        var fa = skyArcDetailedWindow.focusAltDeg + dy * deg
                        skyArcDetailedWindow.focusAltDeg = Math.max(0, Math.min(90, fa))
                        var fz = skyArcDetailedWindow.focusAzDeg - dx * deg
                        skyArcDetailedWindow.focusAzDeg = ((fz % 360) + 360) % 360
                        lastX = mouse.x; lastY = mouse.y
                    }
                }
                onReleased: function(mouse) {
                    domeCanvas.interacting = false
                    if (!dragging) domeCanvas.selectAt(mouse.x, mouse.y)
                    else domeCanvas.requestPaint()
                }
            }

            WheelHandler {
                onWheel: function(event) {
                    var f = event.angleDelta.y > 0 ? 1.15 : 0.87
                    skyArcDetailedWindow.zoom = Math.max(0.5, Math.min(8.0, skyArcDetailedWindow.zoom * f))
                    domeCanvas.interacting = true
                    zoomSettle.restart()
                }
            }

            Timer {
                id: zoomSettle
                interval: 180; repeat: false
                onTriggered: { domeCanvas.interacting = false; domeCanvas.requestPaint() }
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

            Text { text: "Live Sky"; font.pixelSize: 11; font.bold: true; color: pal.placeholderText }
            Text {
                width: parent.width
                text: {
                    var t = new Date(skyArcDetailedWindow.nowMs)
                    var hh = t.getUTCHours(), mm = t.getUTCMinutes()
                    return "Now " + (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm + " UTC  ·  "
                           + skyArcDetailedWindow.stars.length + " stars"
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

            Text { text: "Selected Object"; font.pixelSize: 11; font.bold: true; color: pal.placeholderText }
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
                text: "Its path across the sky is highlighted, and the selection is mirrored in the planner's Sky Arc."
                font.pixelSize: 11; color: pal.placeholderText
                wrapMode: Text.WordWrap
            }

            Rectangle { width: parent.width; height: 1; color: pal.mid }

            Text { text: "Legend"; font.pixelSize: 11; font.bold: true; color: pal.placeholderText }
            Row {
                spacing: 8
                Rectangle { width: 8; height: 8; radius: 4; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Star — brighter = larger"; font.pixelSize: 11; color: pal.windowText
                       anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 8
                Rectangle { width: 7; height: 7; radius: 3.5; color: Qt.rgba(1, 1, 1, 0.45)
                            anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Catalogue object, up now"; font.pixelSize: 11; color: pal.windowText
                       anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 8
                Rectangle { width: 10; height: 10; radius: 5; color: Qt.hsva(0.55, 0.65, 0.95, 1)
                            anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Imaged target — own colour + path"; font.pixelSize: 11; color: pal.windowText
                       anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 8
                Rectangle { width: 12; height: 12; radius: 6; color: "transparent"
                            border.color: "#ffd060"; border.width: 2
                            anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Selected object"; font.pixelSize: 11; color: pal.windowText
                       anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: parent.width; height: 1; color: pal.mid }

            Text {
                width: parent.width
                text: "Drag to re-centre the sky · scroll to zoom · click an object to open it in the planner. Stars and positions update live for your location."
                font.pixelSize: 11; color: pal.placeholderText
                wrapMode: Text.WordWrap
            }
        }
    }
}
