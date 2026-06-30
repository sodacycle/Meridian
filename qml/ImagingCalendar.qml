import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    height: col.height + 32
    color:        window.sysPal.base
    border.color: window.sysPal.mid
    border.width: 1
    radius: 6

    property var anchorDate: { var d = new Date(); d.setHours(0, 0, 0, 0); return d }
    property var monthNames: ["January","February","March","April","May","June",
                              "July","August","September","October","November","December"]
    property var monthShort: ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    property var dayNames: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    property var calendarDays: []
    property string activeCatalogFilter: ""
    property string activeTargetFilter: ""

    property string density: "Compact"
    readonly property string viewMode: density === "Normal" ? "week"
                                       : (density === "Detailed" ? "3day" : "month")

    readonly property int  rowUnit: 80
    readonly property int  columns: viewMode === "3day" ? 3 : 7
    readonly property int  monthRows: weeksInMonth(anchorDate.getFullYear(), anchorDate.getMonth())
    readonly property real gridAreaH: monthRows * rowUnit
    readonly property real cellW: Math.max(1, (width - 32 - (columns - 1) * 2) / columns)
    readonly property real cellH: viewMode === "month" ? (rowUnit - 2) : (gridAreaH - 2)
    readonly property int  maxTargets: viewMode === "month" ? 2 : (viewMode === "week" ? 7 : 14)
    readonly property bool showDayExtras: viewMode !== "month"

    function pad2(n) { return (n < 10 ? "0" : "") + n }
    function dateStrOf(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) }
    function fmtShort(d) { return monthShort[d.getMonth()] + " " + d.getDate() }

    function weeksInMonth(year, month0) {
        var firstDow = new Date(year, month0, 1).getDay()
        var dim = new Date(year, month0 + 1, 0).getDate()
        return Math.ceil((firstDow + dim) / 7)
    }

    function startOfWeek(d) {
        var s = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        s.setDate(s.getDate() - s.getDay())
        return s
    }

    function rangeLabel() {
        if (viewMode === "month")
            return monthNames[anchorDate.getMonth()] + " " + anchorDate.getFullYear()
        if (viewMode === "week") {
            var s = startOfWeek(anchorDate)
            var e = new Date(s); e.setDate(s.getDate() + 6)
            return fmtShort(s) + " – " + fmtShort(e) + ", " + e.getFullYear()
        }
        var e2 = new Date(anchorDate); e2.setDate(anchorDate.getDate() + 2)
        return fmtShort(anchorDate) + " – " + fmtShort(e2) + ", " + e2.getFullYear()
    }

    function navigate(dir) {
        var d = new Date(anchorDate)
        if (viewMode === "month")     d.setMonth(d.getMonth() + dir)
        else if (viewMode === "week") d.setDate(d.getDate() + dir * 7)
        else                          d.setDate(d.getDate() + dir * 3)
        anchorDate = d
        weatherService.fetchWeather(anchorDate.getFullYear(), anchorDate.getMonth() + 1)
        buildCalendar(window.fullMetadataList)
    }

    onDensityChanged: Qt.callLater(buildCalendar, window.fullMetadataList)

    function matchesCatalog(targetName, catalog) {
        if (catalog === "") return true
        var t = targetName.toUpperCase().replace(/MOSAIC/g,"").replace(/PANEL/g,"").replace(/-/g," ").trim()
        if (catalog === "Messier")   return t.startsWith("M ")
        if (catalog === "NGC")       return t.startsWith("NGC")
        if (catalog === "IC")        return t.startsWith("IC")
        if (catalog === "Caldwell")  return t.startsWith("CALDWELL")
        if (catalog === "Sharpless") return t.startsWith("SH2") || t.startsWith("SH ")
        if (catalog === "Barnard")   return t.startsWith("BARNARD") || t.startsWith("B ")
        if (catalog === "LDN")       return t.startsWith("LDN")
        if (catalog === "LBN")       return t.startsWith("LBN")
        if (catalog === "Abell")     return t.startsWith("ABELL")
        if (catalog === "PGC")       return t.startsWith("PGC")
        if (catalog === "UGC")       return t.startsWith("UGC")
        if (catalog === "Other")     return !t.startsWith("M ") && !t.startsWith("NGC") &&
            !t.startsWith("IC") && !t.startsWith("CALDWELL") && !t.startsWith("SH") &&
            !t.startsWith("BARNARD") && !t.startsWith("B ") && !t.startsWith("LDN") &&
            !t.startsWith("LBN") && !t.startsWith("ABELL") && !t.startsWith("PGC") &&
            !t.startsWith("UGC")
        return true
    }

    function dayObject(d, isOther, sbd, ebd) {
        var ds = dateStrOf(d)
        var sessions = sbd[ds] || {}
        var wd = weatherService.weatherForDate(ds)
        return {
            dayNumber:    d.getDate(),
            weekdayName:  dayNames[d.getDay()],
            moonPhase:    weatherService.getMoonPhase(d),
            isOtherMonth: isOther,
            dateStr:      ds,
            sessions:     sessions,
            equipment:    Object.keys(ebd[ds] || {}),
            weather:      wd.valid ? wd : null
        }
    }

    function buildCalendar(metadataList) {
        var sbd = {}
        var ebd = {}
        if (metadataList) {
            for (var i = 0; i < metadataList.length; i++) {
                var it = metadataList[i]
                var dp = it["Start Time UTC"] ? it["Start Time UTC"].toString().split(" ")[0] : ""
                var tg = it["Target"]
                var ex = parseFloat(it["Total Exposure Time s"] || 0)
                if (dp && tg && ex > 0 && matchesCatalog(tg, activeCatalogFilter)
                        && (activeTargetFilter === "" || tg === activeTargetFilter)) {
                    if (!sbd[dp]) sbd[dp] = {}
                    sbd[dp][tg] = (sbd[dp][tg] || 0) + ex
                    var tel = it["Telescope"]
                    if (tel && tel !== "" && tel !== "Unknown") {
                        if (!ebd[dp]) ebd[dp] = {}
                        ebd[dp][tel] = true
                    }
                }
            }
        }

        var days = []
        if (viewMode === "month") {
            var year = anchorDate.getFullYear()
            var month = anchorDate.getMonth()
            var firstDow = new Date(year, month, 1).getDay()
            var dim = new Date(year, month + 1, 0).getDate()
            var prevDim = new Date(year, month, 0).getDate()
            for (var p = firstDow - 1; p >= 0; p--)
                days.push(dayObject(new Date(year, month - 1, prevDim - p), true, sbd, ebd))
            for (var dn = 1; dn <= dim; dn++)
                days.push(dayObject(new Date(year, month, dn), false, sbd, ebd))
            var rem = (7 - ((firstDow + dim) % 7)) % 7
            for (var n = 1; n <= rem; n++)
                days.push(dayObject(new Date(year, month + 1, n), true, sbd, ebd))
        } else if (viewMode === "week") {
            var ws = startOfWeek(anchorDate)
            for (var w = 0; w < 7; w++)
                days.push(dayObject(new Date(ws.getFullYear(), ws.getMonth(), ws.getDate() + w), false, sbd, ebd))
        } else {
            for (var t3 = 0; t3 < 3; t3++)
                days.push(dayObject(new Date(anchorDate.getFullYear(), anchorDate.getMonth(),
                                             anchorDate.getDate() + t3), false, sbd, ebd))
        }
        calendarDays = days
    }

    function weatherDetail(wd) {
        if (!wd) return ""
        var emoji = weatherService.getWeatherEmoji(wd.weatherCode, wd.avgCloud)
        var parts = []
        if (wd.nightTemp !== 0) {
            var temp = weatherService.celsius ? Math.round(wd.nightTemp)
                                              : Math.round(wd.nightTemp * 9/5 + 32)
            parts.push("🌡" + temp + "°" + (weatherService.celsius ? "C" : "F"))
        }
        if (wd.avgHumidity > 0) parts.push("💧" + Math.round(wd.avgHumidity) + "%")
        return " |" + emoji + (parts.length > 0 ? " (" + parts.join("|") + ")" : "")
    }

    function dayTotalMinutes(dd) {
        var total = 0
        for (var k in dd.sessions) total += dd.sessions[k]
        return Math.round(total / 60)
    }

    Column {
        id: col
        anchors.top:     parent.top
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.margins: 16
        spacing: 10

        Row {
            width: parent.width; spacing: 8
            Text {
                text: "Imaging Calendar"; font.pixelSize: 20; font.bold: true
                color: window.sysPal.windowText
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - densityLabel.width - densityCombo.width - tempBtn.width - 32
            }
            Text {
                id: densityLabel; text: "View"
                font.pixelSize: 11; color: window.sysPal.placeholderText
                anchors.verticalCenter: parent.verticalCenter
            }
            ComboBox {
                id: densityCombo
                model: ["Compact", "Normal", "Detailed"]
                currentIndex: 0
                font.pixelSize: 11; implicitWidth: 110; implicitHeight: 28
                anchors.verticalCenter: parent.verticalCenter
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Compact = month grid · Normal = 7-day week · Detailed = 3-day view.\nFewer days show more detail per night."
                onActivated: root.density = currentText
            }
            Button {
                id: tempBtn; text: weatherService.celsius ? "°C / °F" : "°F / °C"
                font.pixelSize: 11; implicitWidth: 80; implicitHeight: 28
                anchors.verticalCenter: parent.verticalCenter
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Toggle weather temperature display\nbetween Celsius and Fahrenheit."
                onClicked: weatherService.toggleUnit()
            }
        }

        Row {
            width: parent.width; spacing: 0
            Button {
                text: "<"; implicitWidth: 36; implicitHeight: 28
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Go to the previous period."
                onClicked: root.navigate(-1)
            }
            Text {
                text: root.rangeLabel()
                color: window.sysPal.windowText; font.pixelSize: 15; font.bold: true
                width: parent.width - 72
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
            }
            Button {
                text: ">"; implicitWidth: 36; implicitHeight: 28
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Go to the next period."
                onClicked: root.navigate(1)
            }
        }

        Text {
            text: "Scan FITS files to populate the imaging calendar."
            color: window.sysPal.placeholderText; font.pixelSize: 13
            visible: !window.fullMetadataList || window.fullMetadataList.length === 0
            width: parent.width
        }

        Row {
            spacing: 2
            visible: root.viewMode !== "3day"
            Repeater {
                model: dayNames
                Rectangle {
                    width: root.cellW; height: 26
                    color: window.sysPal.alternateBase; radius: 3
                    Text { anchors.centerIn: parent; text: modelData
                        color: window.sysPal.windowText; font.pixelSize: 11; font.bold: true }
                }
            }
        }

        Item {
            width: parent.width; height: root.gridAreaH

            Grid {
                columns: root.columns; spacing: 2
                Repeater {
                    model: calendarDays
                    delegate: Rectangle {
                        required property var modelData
                        property var dd: modelData
                        property bool hasSessions: Object.keys(dd.sessions).length > 0
                        width: root.cellW; height: root.cellH
                        color: window.sysPal.base
                        border.color: hasSessions ? window.sysPal.highlight : window.sysPal.mid
                        border.width: hasSessions ? 2 : 1
                        radius: 4
                        opacity: dd.isOtherMonth ? 0.4 : 1.0; clip: true
                        Column {
                            anchors.fill: parent; anchors.margins: 4; spacing: 2
                            Text {
                                text: (root.viewMode === "month" ? dd.dayNumber : dd.weekdayName + " " + dd.dayNumber)
                                      + "  " + dd.moonPhase
                                      + (hasSessions ? root.weatherDetail(dd.weather) : "")
                                color: window.sysPal.windowText
                                font.pixelSize: 10; font.bold: true
                                width: parent.width; elide: Text.ElideRight
                            }
                            Repeater {
                                model: Object.keys(dd.sessions).slice(0, root.maxTargets)
                                delegate: Rectangle {
                                    required property string modelData
                                    property string tgt: modelData
                                    width: parent.width; height: 17
                                    color: window.sysPal.highlight; radius: 3
                                    Text {
                                        anchors.fill: parent; anchors.margins: 2
                                        text: tgt + " – " + Math.round(dd.sessions[tgt]/60) + "m"
                                        color: window.sysPal.highlightedText
                                        font.pixelSize: 9; elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: fileDetailsView.filterByTargetAndDate(tgt, dd.dateStr)
                                    }
                                }
                            }
                            Text {
                                visible: root.showDayExtras && hasSessions
                                width: parent.width
                                text: "Σ " + root.dayTotalMinutes(dd) + "m total"
                                color: window.sysPal.windowText
                                font.pixelSize: 9; elide: Text.ElideRight
                            }
                            Text {
                                visible: root.showDayExtras && hasSessions && (dd.equipment || []).length > 0
                                width: parent.width
                                text: "🔭 " + (dd.equipment || []).join(", ")
                                color: window.sysPal.placeholderText
                                font.pixelSize: 9; elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
        Item { width: 1; height: 4 }
    }
    Connections {
        target: weatherService
        function onWeatherUpdated() { buildCalendar(window.fullMetadataList) }
        function onUnitChanged()    { buildCalendar(window.fullMetadataList) }
    }
}
