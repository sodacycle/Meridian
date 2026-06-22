import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    height: col.height + 32
    color:        window.sysPal.base
    border.color: window.sysPal.mid
    border.width: 1
    radius: 6

    property var  metadataList: []
    property real latitude:  weatherService.latitude
    property real longitude: weatherService.longitude
    readonly property bool hasLocation: latitude !== 0.0 || longitude !== 0.0

    property string selectedTarget: ""
    property var targets: []

    function parseRaHours(s) {
        if (s === undefined || s === null) return NaN
        s = ("" + s).trim()
        if (s === "" || s === "Unknown") return NaN
        if (s.indexOf(":") >= 0) {
            var p = s.split(":")
            var h = parseFloat(p[0])
            if (isNaN(h)) return NaN
            var sign = (s[0] === "-") ? -1 : 1
            return sign * (Math.abs(h) + (parseFloat(p[1]) || 0) / 60 + (parseFloat(p[2]) || 0) / 3600)
        }
        var v = parseFloat(s)
        return isNaN(v) ? NaN : v / 15.0
    }

    function parseDecDeg(s) {
        if (s === undefined || s === null) return NaN
        s = ("" + s).trim()
        if (s === "" || s === "Unknown") return NaN
        if (s.indexOf(":") >= 0) {
            var neg = s[0] === "-"
            var p = s.replace("+", "").split(":")
            var d = parseFloat(p[0])
            if (isNaN(d)) return NaN
            var val = Math.abs(d) + (parseFloat(p[1]) || 0) / 60 + (parseFloat(p[2]) || 0) / 3600
            return (neg || d < 0) ? -val : val
        }
        var v = parseFloat(s)
        return isNaN(v) ? NaN : v
    }

    function colorFor(i, n) {
        return Qt.hsva((i % n) / Math.max(1, n), 0.62, 0.95, 1.0)
    }

    function localMidnightUTC() {
        var lonOffMs = (longitude / 15.0) * 3600000
        var localNow = Date.now() + lonOffMs
        var dayMs    = 86400000
        return new Date(Math.floor(localNow / dayMs) * dayMs - lonOffMs)
    }

    function rebuild() {
        var byName = {}
        for (var i = 0; i < metadataList.length; i++) {
            var e = metadataList[i]
            if (e["Frame Type"] !== "LIGHT") continue
            var name = e["Target"]
            if (!name || name === "Unknown" || name === "") continue
            if (byName[name]) continue
            var ra  = parseRaHours(e["RA"])
            var dec = parseDecDeg(e["DEC"])
            if (isNaN(ra) || isNaN(dec)) continue
            byName[name] = { name: name, raHours: ra, decDeg: dec }
        }
        var arr = []
        for (var k in byName) arr.push(byName[k])
        arr.sort(function(a, b) { return a.decDeg - b.decDeg })
        for (var j = 0; j < arr.length; j++) arr[j].color = colorFor(j, arr.length)
        targets = arr
        skyCanvas.requestPaint()
    }

    function toggleSelect(name) {
        selectedTarget = (selectedTarget === name) ? "" : name
    }

    onMetadataListChanged: rebuild()
    onLatitudeChanged:       skyCanvas.requestPaint()
    onLongitudeChanged:      skyCanvas.requestPaint()
    onSelectedTargetChanged: skyCanvas.requestPaint()

    Column {
        id: col
        anchors.top:     parent.top
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.margins: 16
        spacing: 8

        Text {
            text: "Observed Sky Paths"
            font.pixelSize: 20; font.bold: true
            color: window.sysPal.windowText; width: parent.width
        }

        Text {
            width: parent.width
            text: !root.hasLocation
                  ? "Set a location (scan FITS files with site coordinates, or use the planner) to plot observed paths."
                  : "Scan FITS files with valid RA/Dec headers to plot observed target paths."
            color: window.sysPal.placeholderText
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            visible: !root.hasLocation || root.targets.length === 0
        }

        Canvas {
            id: skyCanvas
            width: parent.width
            height: 200
            visible: root.hasLocation && root.targets.length > 0

            property var    watchTargets: root.targets
            property string watchSel:     root.selectedTarget
            property real   watchLat:      root.latitude
            property real   watchLon:      root.longitude
            onWatchTargetsChanged: requestPaint()
            onWatchSelChanged:     requestPaint()
            onWatchLatChanged:     requestPaint()
            onWatchLonChanged:     requestPaint()
            onWidthChanged:        requestPaint()
            onVisibleChanged:      if (visible) requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (!root.hasLocation || root.targets.length === 0) return

                var lat = root.latitude
                var lon = root.longitude
                var padL = 30, padR = 10
                var horizonY = height - 20
                var altScale = horizonY - 6
                var plotW = Math.max(1, width - padL - padR)

                var midnight = root.localMidnightUTC()
                var jdMid    = plannerService.toJD(midnight.getTime())

                function sunAlt(jd) {
                    var T          = (jd - 2451545.0) / 36525.0
                    var meanAnom   = (357.52911 + 35999.05029 * T) * Math.PI / 180
                    var eclipLon   = (280.46646 + 36000.76983 * T
                                      + (1.914602 - 0.004817 * T) * Math.sin(meanAnom)
                                      + 0.019993 * Math.sin(2 * meanAnom)) * Math.PI / 180
                    var obliquity  = (23.439291 - 0.013004 * T) * Math.PI / 180
                    var raH = (Math.atan2(Math.cos(obliquity) * Math.sin(eclipLon), Math.cos(eclipLon))
                               * 180 / Math.PI / 15 + 24) % 24
                    var dec = Math.asin(Math.sin(obliquity) * Math.sin(eclipLon)) * 180 / Math.PI
                    return plannerService.altitudeDeg(raH, dec, lat, plannerService.lst(jd, lon))
                }

                var hStart = -6, hEnd = 6, span = 12
                function xOf(h)   { return padL + (h - hStart) / span * plotW }
                function yOf(alt) { return horizonY - (alt / 90.0) * altScale }
                function clockAt(h) {
                    var t = new Date(midnight.getTime() + h * 3600000)
                    var hh = t.getUTCHours(), mm = t.getUTCMinutes()
                    return (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm
                }

                var shadeSteps = Math.max(48, Math.round(plotW / 2))
                for (var i = 0; i < shadeSteps; i++) {
                    var hA = hStart + span * i / shadeSteps
                    var hB = hStart + span * (i + 1) / shadeSteps
                    var sa = sunAlt(jdMid + (hA + hB) / 2 / 24.0)
                    var twilightColor = null
                    if      (sa >= 0)   twilightColor = "rgba(160,110,50,0.20)"
                    else if (sa >= -6)  twilightColor = "rgba(160,100,40,0.13)"
                    else if (sa >= -12) twilightColor = "rgba(60,80,140,0.10)"
                    else if (sa >= -18) twilightColor = "rgba(30,50,100,0.07)"
                    if (twilightColor) {
                        ctx.fillStyle = twilightColor
                        ctx.fillRect(xOf(hA), 0, xOf(hB) - xOf(hA) + 0.5, horizonY)
                    }
                }

                ctx.strokeStyle = window.sysPal.mid
                ctx.lineWidth = 1; ctx.setLineDash([])
                ctx.beginPath(); ctx.moveTo(padL, horizonY); ctx.lineTo(width - padR, horizonY); ctx.stroke()

                ctx.font = "10px sans-serif"
                ctx.fillStyle = window.sysPal.placeholderText
                ctx.textAlign = "left"

                var planningLimitY = yOf(15)
                ctx.strokeStyle = window.sysPal.mid
                ctx.setLineDash([2, 6]); ctx.lineWidth = 0.5
                ctx.beginPath(); ctx.moveTo(padL, planningLimitY); ctx.lineTo(width - padR, planningLimitY); ctx.stroke()
                ctx.fillText("15°", 2, planningLimitY + 4)

                for (var gridAlt = 30; gridAlt <= 60; gridAlt += 30) {
                    var gridY = yOf(gridAlt)
                    ctx.setLineDash([2, 4]); ctx.lineWidth = 0.5
                    ctx.strokeStyle = window.sysPal.mid
                    ctx.beginPath(); ctx.moveTo(padL, gridY); ctx.lineTo(width - padR, gridY); ctx.stroke()
                    ctx.fillText(gridAlt + "°", 2, gridY + 4)
                }
                ctx.setLineDash([])

                ctx.fillStyle = window.sysPal.placeholderText
                var firstHour = Math.ceil(hStart), lastHour = Math.floor(hEnd)
                for (var labelH = firstHour; labelH <= lastHour; labelH += 2) {
                    var labelX = xOf(labelH)
                    ctx.strokeStyle = window.sysPal.mid
                    ctx.setLineDash([2, 5]); ctx.lineWidth = 0.5
                    ctx.beginPath(); ctx.moveTo(labelX, 0); ctx.lineTo(labelX, horizonY); ctx.stroke()
                    ctx.setLineDash([])
                    ctx.textAlign = (labelH === firstHour) ? "left" : (labelH === lastHour ? "right" : "center")
                    ctx.fillText(clockAt(labelH), labelX, horizonY + 13)
                }

                function drawCurve(tgt, strokeColor, lineW) {
                    ctx.strokeStyle = strokeColor
                    ctx.lineWidth = lineW
                    ctx.beginPath()
                    var on = false
                    for (var h = hStart; h <= hEnd + 1e-9; h += 0.1) {
                        var alt = plannerService.altitudeDeg(tgt.raHours, tgt.decDeg, lat,
                                                             plannerService.lst(jdMid + h / 24.0, lon))
                        if (alt < 0) { on = false; continue }
                        var p = { x: xOf(h), y: yOf(alt) }
                        if (!on) { ctx.moveTo(p.x, p.y); on = true }
                        else ctx.lineTo(p.x, p.y)
                    }
                    ctx.stroke()
                }

                var grayCol = Qt.rgba(window.sysPal.placeholderText.r, window.sysPal.placeholderText.g,
                                      window.sysPal.placeholderText.b, 0.45)
                for (var ti = 0; ti < root.targets.length; ti++) {
                    var tg = root.targets[ti]
                    if (root.selectedTarget !== "" && tg.name === root.selectedTarget) continue
                    drawCurve(tg, root.selectedTarget !== "" ? grayCol : tg.color, 1.8)
                }
                if (root.selectedTarget !== "") {
                    for (var si = 0; si < root.targets.length; si++) {
                        if (root.targets[si].name === root.selectedTarget) {
                            drawCurve(root.targets[si], root.targets[si].color, 3.0)
                            break
                        }
                    }
                }
            }

            TapHandler {
                onTapped: root.selectedTarget = ""
            }
        }

        Flow {
            width: parent.width
            spacing: 6
            visible: root.hasLocation && root.targets.length > 0

            Repeater {
                model: root.targets
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: root.selectedTarget === modelData.name
                    readonly property bool dim: root.selectedTarget !== "" && !sel
                    height: 24; radius: 4
                    width: swatch.width + label.width + 18
                    color: sel ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.22)
                               : window.sysPal.alternateBase
                    border.color: sel ? modelData.color : window.sysPal.mid
                    border.width: 1
                    opacity: dim ? 0.5 : 1.0

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            id: swatch
                            width: 12; height: 12; radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.color
                        }
                        Text {
                            id: label
                            text: modelData.name
                            font.pixelSize: 11
                            color: window.sysPal.windowText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleSelect(modelData.name)
                    }
                }
            }
        }
    }
}
