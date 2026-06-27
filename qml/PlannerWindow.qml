import QtQuick
import QtQuick.Controls

Window {
    id: plannerWindow
    title: "Meridian — Observation Planner"
    width:  1200
    height: 860
    minimumWidth:  900
    minimumHeight: 720

    SystemPalette { id: pal; colorGroup: SystemPalette.Active }
    color: pal.window

    property real latitude:  0.0
    property real longitude: 0.0
    readonly property bool hasLocation: (latitude !== 0.0 || longitude !== 0.0)

    property int nightOffset: 0
    property var selectedObj: null

    property bool clockLocal: false

    property var  viewSectors: [true, true, true, true, true, true, true, true]
    property real viewMinAlt:  15
    readonly property var  sectorNames: ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    readonly property bool viewAreaActive: viewSectors.indexOf(false) >= 0 || viewMinAlt > 15

    property bool viewFilterEnabled: false

    function toggleSector(i) {
        var a = viewSectors.slice()
        a[i] = !a[i]
        viewSectors = a
    }

    function applyViewFilter() {
        plannerService.setViewFilter(viewSectors, viewMinAlt, viewFilterEnabled)
    }
    onViewFilterEnabledChanged: applyViewFilter()
    onViewSectorsChanged:       if (viewFilterEnabled) applyViewFilter()
    onViewMinAltChanged:        if (viewFilterEnabled) applyViewFilter()
    property int weatherRevision: 0
    property int scheduleRevision: 0
    property bool showManualEntry: false

    property string sortCol:    "Peak Alt"
    property bool   sortAsc:    false
    property string searchText: ""

    onSearchTextChanged: plannerService.objects.setFilter(searchText)

    property var    wikiData:    null
    property bool   wikiLoading: false
    property string wikiError:   ""

    onSelectedObjChanged: {
        wikiData    = null
        wikiLoading = false
        wikiError   = ""
        if (selectedObj) {
            wikiLoading = true
            wikiService.lookup(selectedObj.name)
        }
    }

    function applySort() {
        plannerService.objects.sortBy(plannerWindow.sortCol, plannerWindow.sortAsc)
    }
    function headerClicked(col) {
        if (plannerWindow.sortCol === col) {
            plannerWindow.sortAsc = !plannerWindow.sortAsc
        } else {
            plannerWindow.sortCol = col
            plannerWindow.sortAsc = (col === "Name" || col === "Type" || col === "Con")
        }
        plannerWindow.applySort()
    }

    onShowManualEntryChanged: {
        if (showManualEntry) {
            latEntry.text  = hasLocation ? latitude.toFixed(6)  : ""
            lonEntry.text  = hasLocation ? longitude.toFixed(6) : ""
            manualEntryError.text = ""
            latEntry.forceActiveFocus()
        }
    }

    function applyManualLocation() {
        var lat = parseFloat(latEntry.text)
        var lon = parseFloat(lonEntry.text)
        if (isNaN(lat) || lat < -90 || lat > 90) {
            manualEntryError.text = "Latitude must be −90 to 90"; return
        }
        if (isNaN(lon) || lon < -180 || lon > 180) {
            manualEntryError.text = "Longitude must be −180 to 180"; return
        }
        weatherService.setLocation(lat, lon)
        plannerWindow.showManualEntry = false
    }

    function detailedStartAz() {
        var sx = 0, sy = 0, n = 0
        for (var i = 0; i < 8; i++) {
            if (viewSectors[i] === true) {
                var a = i * 45 * Math.PI / 180
                sx += Math.cos(a); sy += Math.sin(a); n++
            }
        }
        if (n === 0 || Math.sqrt(sx * sx + sy * sy) < 1e-6) return 0
        var az = Math.atan2(sy, sx) * 180 / Math.PI
        return ((az % 360) + 360) % 360
    }

    function openSkyArcDetailed() {
        skyArcDetailedWindow.latitude    = plannerWindow.latitude
        skyArcDetailedWindow.longitude   = plannerWindow.longitude
        skyArcDetailedWindow.nightOffset = plannerWindow.nightOffset
        skyArcDetailedWindow.focusAltDeg = 0
        skyArcDetailedWindow.focusAzDeg  = detailedStartAz()
        skyArcDetailedWindow.show()
        skyArcDetailedWindow.raise()
    }

    readonly property string currentNightDateStr: {
        var d = new Date()
        d.setDate(d.getDate() + nightOffset)
        var y = d.getFullYear()
        var m = d.getMonth() + 1
        var day = d.getDate()
        return y + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day
    }

    property var planAnchor: { var d = new Date(); d.setHours(0, 0, 0, 0); return d }

    property string calendarDensity: "Compact"
    readonly property string calViewMode: calendarDensity === "Normal" ? "week"
                                          : (calendarDensity === "Detailed" ? "3day" : "month")
    readonly property int  calColumns:   calViewMode === "3day" ? 3 : 7
    readonly property int  calRowUnit:   70
    readonly property int  calMonthRows: weeksInMonth(planAnchor.getFullYear(), planAnchor.getMonth() + 1)
    readonly property real calGridAreaH: calMonthRows * calRowUnit
    readonly property int  calMaxObjs:   calViewMode === "month" ? 2 : (calViewMode === "week" ? 7 : 12)

    property var dayNames:   ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    property var monthShort: ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

    function localMidnightUTC() {
        var lonOffMs = (longitude / 15.0) * 3600000
        var localNow = Date.now() + lonOffMs
        var dayMs    = 86400000
        return new Date(Math.floor(localNow / dayMs) * dayMs
                        - lonOffMs + nightOffset * dayMs)
    }

    function nightLabel() {
        if (nightOffset === 0) return "Tonight"
        if (nightOffset === 1) return "Tomorrow"
        var d = new Date()
        d.setDate(d.getDate() + nightOffset)
        return d.toLocaleDateString(Qt.locale(), "ddd d MMM")
    }

    function daysInMonth(year, month) {
        return new Date(year, month, 0).getDate()
    }

    function firstWeekdayOfMonth(year, month) {
        return new Date(year, month - 1, 1).getDay()
    }

    function weeksInMonth(year, month) {
        return Math.ceil((firstWeekdayOfMonth(year, month) + daysInMonth(year, month)) / 7)
    }

    function monthName(month) {
        return ["January","February","March","April","May","June",
                "July","August","September","October","November","December"][month - 1]
    }

    function pad2(n) { return (n < 10 ? "0" : "") + n }
    function planDateStr(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) }
    function startOfWeek(d) {
        var s = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        s.setDate(s.getDate() - s.getDay())
        return s
    }

    function planRangeLabel() {
        var a = planAnchor
        if (calViewMode === "month") return monthName(a.getMonth() + 1) + " " + a.getFullYear()
        if (calViewMode === "week") {
            var s = startOfWeek(a); var e = new Date(s); e.setDate(s.getDate() + 6)
            return monthShort[s.getMonth()] + " " + s.getDate() + " – " + monthShort[e.getMonth()] + " " + e.getDate()
        }
        var e2 = new Date(a); e2.setDate(a.getDate() + 2)
        return monthShort[a.getMonth()] + " " + a.getDate() + " – " + monthShort[e2.getMonth()] + " " + e2.getDate()
    }

    function planNavigate(dir) {
        var d = new Date(planAnchor)
        if (calViewMode === "month")     d.setMonth(d.getMonth() + dir)
        else if (calViewMode === "week") d.setDate(d.getDate() + dir * 7)
        else                             d.setDate(d.getDate() + dir * 3)
        plannerWindow.planAnchor = d
    }

    function selectScheduledObject(dayOffset, name) {
        plannerWindow.nightOffset = dayOffset
        var model = plannerService.objects
        var count = model.entryCount()
        for (var i = 0; i < count; i++) {
            var e = model.entryAt(i)
            if (e.name === name) { plannerWindow.selectedObj = e; return }
        }
    }

    function fmtNightMin(min) {
        var total = (18 * 60 + min) % (24 * 60)
        var h = Math.floor(total / 60), m = total % 60
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
    }

    function colorForObject(name) {
        var hash = 0
        for (var i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) % 360
        return Qt.hsva(hash / 360.0, 0.55, 0.85, 1.0)
    }

    function planDay(d, isOther) {
        return { dayNum: d.getDate(), weekdayName: dayNames[d.getDay()],
                 yy: d.getFullYear(), mm: d.getMonth() + 1, dd: d.getDate(),
                 isOtherMonth: isOther, dateStr: planDateStr(d) }
    }

    readonly property var planCalendarDays: {
        var mode = calViewMode
        var a = planAnchor
        var days = []
        if (mode === "month") {
            var year = a.getFullYear(), month = a.getMonth()
            var firstDow = new Date(year, month, 1).getDay()
            var dim = new Date(year, month + 1, 0).getDate()
            var prevDim = new Date(year, month, 0).getDate()
            for (var p = firstDow - 1; p >= 0; p--) days.push(planDay(new Date(year, month - 1, prevDim - p), true))
            for (var dn = 1; dn <= dim; dn++) days.push(planDay(new Date(year, month, dn), false))
            var rem = (7 - ((firstDow + dim) % 7)) % 7
            for (var n = 1; n <= rem; n++) days.push(planDay(new Date(year, month + 1, n), true))
        } else if (mode === "week") {
            var ws = startOfWeek(a)
            for (var w = 0; w < 7; w++) days.push(planDay(new Date(ws.getFullYear(), ws.getMonth(), ws.getDate() + w), false))
        } else {
            for (var t3 = 0; t3 < 3; t3++) days.push(planDay(new Date(a.getFullYear(), a.getMonth(), a.getDate() + t3), false))
        }
        return days
    }

    function fmtMag(mag)  { return (mag === undefined || mag === null || mag >= 99.0) ? "—" : mag.toFixed(1) }
    function fmtSize(sz)  {
        if (!sz || sz <= 0) return "—"
        return sz >= 60 ? (sz / 60).toFixed(1) + "°" : sz.toFixed(1) + "'"
    }
    function fmtAlt(a)    { return a.toFixed(1) + "°" }
    function fmtWindow(circ, wH) {
        if (circ) return "All night"
        if (!wH || wH <= 0) return "—"
        var h = Math.floor(wH), m = Math.round((wH - h) * 60)
        return h + "h" + (m > 0 ? " " + m + "m" : "")
    }
    function fmtHHMM(h) {
        if (clockLocal) h += longitude / 15.0
        var hour24 = ((Math.floor(h) % 24) + 24) % 24
        var minute = Math.round((h - Math.floor(h)) * 60)
        if (minute === 60) { hour24 = (hour24 + 1) % 24; minute = 0 }
        if (clockLocal) {
            var ampm   = hour24 < 12 ? "AM" : "PM"
            var hour12 = hour24 % 12; if (hour12 === 0) hour12 = 12
            return hour12 + ":" + (minute < 10 ? "0" : "") + minute + " " + ampm
        }
        return (hour24 < 10 ? "0" : "") + hour24 + ":" + (minute < 10 ? "0" : "") + minute
    }
    function clockSuffix() { return clockLocal ? "" : " UTC" }
    function clockLabel()  { return clockLocal ? "Local" : "UTC" }
    function fmtViewableUTC(circ, riseH, setH) {
        if (circ) return "All night"
        if (riseH === 0 && setH === 0) return "—"
        return fmtHHMM(riseH) + "–" + fmtHHMM(setH)
    }
    function recommendedSessionHours(type) {
        if (!type) return { min: 2, max: 5 }
        var t = type.toLowerCase()
        if (t.indexOf("supernova remnant") >= 0) return { min: 5, max: 12 }
        if (t.indexOf("emission nebula")   >= 0) return { min: 4, max: 10 }
        if (t.indexOf("reflection nebula") >= 0) return { min: 3, max:  6 }
        if (t.indexOf("planetary nebula")  >= 0) return { min: 2, max:  4 }
        if (t.indexOf("galaxy")            >= 0) return { min: 4, max:  8 }
        if (t.indexOf("globular cluster")  >= 0) return { min: 2, max:  4 }
        if (t.indexOf("open cluster")      >= 0) return { min: 1, max:  3 }
        if (t.indexOf("nebula")            >= 0) return { min: 3, max:  7 }
        if (t.indexOf("dark nebula")       >= 0) return { min: 2, max:  5 }
        return { min: 2, max: 5 }
    }

    function fmtTotalTime(seconds) {
        if (seconds <= 0) return "None recorded"
        var h = Math.floor(seconds / 3600)
        var m = Math.round((seconds % 3600) / 60)
        if (m === 60) { h++; m = 0 }
        if (h === 0)  return m + "m"
        return h + "h" + (m > 0 ? " " + m + "m" : "")
    }

    function obsProgressColor(observedSeconds, type) {
        if (observedSeconds <= 0) return pal.placeholderText
        var recMin = recommendedSessionHours(type).min * 3600
        var ratio  = observedSeconds / recMin
        if (ratio >= 1.0) return "#66bb6a"
        if (ratio >= 0.5) return "#ffd54f"
        return "#ef5350"
    }

    function compass16(az) {
        var pts = ["N","NNE","NE","ENE","E","ESE","SE","SSE",
                   "S","SSW","SW","WSW","W","WNW","NW","NNW"]
        return pts[Math.round(((az % 360) + 360) % 360 / 22.5) % 16]
    }

    function sectorOf(az) {
        return Math.round((((az % 360) + 360) % 360) / 45) % 8
    }

    function azInSweep(az) {
        return viewSectors[sectorOf(az)] === true
    }

    function inView(az, alt) {
        return alt >= viewMinAlt && azInSweep(az)
    }

    function bortleColor(b) {
        if (b <= 0) return pal.mid
        if (b <= 2) return "#1565C0"
        if (b <= 4) return "#2e7d32"
        if (b <= 6) return "#F9A825"
        if (b <= 8) return "#E64A19"
        return "#B71C1C"
    }

    function transitHour(riseH, setH) {
        if (riseH < setH) return (riseH + setH) / 2
        var t = (riseH + setH + 24) / 2
        return t >= 24 ? t - 24 : t
    }
    function recommendedWindow(circ, riseH, setH) {
        if (circ) return "All night"
        if (riseH === 0 && setH === 0) return "Not observable tonight"
        var totalH = riseH < setH ? setH - riseH : setH + 24 - riseH
        var half   = Math.min(1.0, totalH / 2)
        var t      = transitHour(riseH, setH)
        return fmtHHMM((t - half + 24) % 24) + " – " + fmtHHMM((t + half) % 24) + plannerWindow.clockSuffix()
    }

    function fmtRA(raH) {
        var h = Math.floor(raH), m = Math.floor((raH - h) * 60)
        return h + "h " + (m < 10 ? "0" : "") + m + "m"
    }
    function fmtDec(decD) {
        var neg = decD < 0, abs = Math.abs(decD)
        var d = Math.floor(abs), m = Math.floor((abs - d) * 60)
        return (neg ? "−" : "+") + d + "° " + (m < 10 ? "0" : "") + m + "'"
    }
    function fmtTemp(celsius) {
        if (!weatherService.celsius) return (celsius * 9 / 5 + 32).toFixed(0) + "°F"
        return celsius.toFixed(0) + "°C"
    }

    onNightOffsetChanged: {
        var d = new Date()
        d.setDate(d.getDate() + nightOffset); d.setHours(0, 0, 0, 0)
        plannerWindow.planAnchor = d
        plannerService.compute(latitude, longitude, nightOffset)
    }
    onLatitudeChanged:  plannerService.compute(latitude, longitude, nightOffset)
    onLongitudeChanged: plannerService.compute(latitude, longitude, nightOffset)

    Component.onCompleted: {
        latitude  = weatherService.latitude
        longitude = weatherService.longitude
        plannerService.compute(latitude, longitude, nightOffset)
        if (latitude !== 0.0 || longitude !== 0.0) {
            var now = new Date()
            weatherService.fetchWeather(now.getFullYear(), now.getMonth() + 1)
        }
    }

    Connections {
        target: weatherService
        function onLocationChanged() {
            plannerWindow.latitude  = weatherService.latitude
            plannerWindow.longitude = weatherService.longitude
            var now = new Date()
            weatherService.fetchWeather(now.getFullYear(), now.getMonth() + 1)
        }
        function onWeatherUpdated() { plannerWindow.weatherRevision++ }
    }

    Connections {
        target: schedulerService
        function onScheduleChanged() { plannerWindow.scheduleRevision++ }
    }

    Connections {
        target: plannerService
        function onReadyChanged() {
            if (plannerService.ready)
                plannerWindow.applySort()
        }
    }

    Connections {
        target: wikiService
        function onInfoboxReady(data, objectName) {
            if (plannerWindow.selectedObj && plannerWindow.selectedObj.name === objectName) {
                plannerWindow.wikiData    = data
                plannerWindow.wikiLoading = false
                plannerWindow.wikiError   = ""
            }
        }
        function onLookupFailed(objectName, error) {
            if (plannerWindow.selectedObj && plannerWindow.selectedObj.name === objectName) {
                plannerWindow.wikiData    = null
                plannerWindow.wikiLoading = false
                plannerWindow.wikiError   = error
            }
        }
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
                text: "Observation Planner"
                font.pixelSize: 17; font.bold: true; color: pal.windowText
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle { width: 1; height: 28; color: pal.mid; anchors.verticalCenter: parent.verticalCenter }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: plannerWindow.hasLocation
                          ? ("Lat " + plannerWindow.latitude.toFixed(4)
                             + "°  ·  Lon " + plannerWindow.longitude.toFixed(4) + "°")
                          : "No location set"
                    font.pixelSize: 13
                    color: plannerWindow.hasLocation ? pal.windowText : pal.placeholderText
                }
                Text {
                    text: locationService.status
                    font.pixelSize: 10
                    color: pal.placeholderText
                    visible: locationService.status !== "Not located"
                }
            }

            Button {
                text: "Locate"
                flat: true
                implicitHeight: 28
                anchors.verticalCenter: parent.verticalCenter
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Request your current GPS position from the operating system."
                enabled: locationService.status !== "Requesting…"
                         && locationService.status !== "Requesting via IP…"
                onClicked: locationService.requestLocation()
            }

            Button {
                text: "Set Location"
                flat: true
                implicitHeight: 28
                anchors.verticalCenter: parent.verticalCenter
                checkable: true
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Enter latitude and longitude manually\ninstead of using GPS."
                checked: plannerWindow.showManualEntry
                onClicked: plannerWindow.showManualEntry = !plannerWindow.showManualEntry
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 4
            Button {
                text: "‹"; flat: true; enabled: plannerWindow.nightOffset > 0
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Plan the previous night."
                onClicked: plannerWindow.nightOffset--
                implicitWidth: 28; implicitHeight: 28
            }
            Text {
                text: plannerWindow.nightLabel()
                font.pixelSize: 13; font.bold: true; color: pal.windowText
                anchors.verticalCenter: parent.verticalCenter
                width: 130; horizontalAlignment: Text.AlignHCenter
            }
            Button {
                text: "›"; flat: true; enabled: plannerWindow.nightOffset < 30
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Plan the next night (up to 30 days ahead)."
                onClicked: plannerWindow.nightOffset++
                implicitWidth: 28; implicitHeight: 28
            }
        }
    }

    Item {
        id: body
        anchors { top: headerBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }

        Rectangle {
            id: manualEntryBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: plannerWindow.showManualEntry ? 52 : 0
            color: Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.08)
            clip: true

            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Row {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 10
                visible: plannerWindow.showManualEntry

                Text {
                    text: "Latitude"
                    font.pixelSize: 12; color: pal.windowText
                    anchors.verticalCenter: parent.verticalCenter
                }
                TextField {
                    id: latEntry
                    width: 130; implicitHeight: 32
                    placeholderText: "e.g. 51.5074"
                    font.pixelSize: 12
                    selectByMouse: true
                    onAccepted: plannerWindow.applyManualLocation()
                }

                Text {
                    text: "Longitude"
                    font.pixelSize: 12; color: pal.windowText
                    anchors.verticalCenter: parent.verticalCenter
                }
                TextField {
                    id: lonEntry
                    width: 130; implicitHeight: 32
                    placeholderText: "e.g. -0.1278"
                    font.pixelSize: 12
                    selectByMouse: true
                    onAccepted: plannerWindow.applyManualLocation()
                }

                Button {
                    text: "Apply"
                    implicitHeight: 32
                    anchors.verticalCenter: parent.verticalCenter
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: "Use the entered coordinates and recompute\ntonight's visible objects."
                    onClicked: plannerWindow.applyManualLocation()
                }

                Button {
                    text: "Cancel"
                    flat: true
                    implicitHeight: 32
                    anchors.verticalCenter: parent.verticalCenter
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: "Discard the manual entry and keep the current location."
                    onClicked: {
                        plannerWindow.showManualEntry = false
                        manualEntryError.text = ""
                    }
                }

                Text {
                    id: manualEntryError
                    text: ""
                    color: "#e05555"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                }
            }
        }

        Flickable {
            id: pageFlick
            anchors { top: manualEntryBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            contentWidth: pageContent.width
            contentHeight: pageContent.height
            clip: true
            interactive: !skyArcHover.hovered
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { id: pageScroll; policy: ScrollBar.AsNeeded }

            Item {
                id: pageContent
                // Reserve the scrollbar's width so it never overlays the content.
                width: pageFlick.width - pageScroll.width
                height: topSection.height + obsBar.height + calSection.height

                WheelHandler {
                    enabled: skyArcHover.hovered
                    onWheel: function(e) {
                        if (e.angleDelta.y !== 0) {
                            var f = e.angleDelta.y > 0 ? 1.15 : 0.87
                            skyCanvas.zoom = Math.max(1.0, Math.min(12.0, skyCanvas.zoom * f))
                        } else if (e.angleDelta.x !== 0) {
                            skyCanvas.focusAz = skyCanvas.focusAz + (e.angleDelta.x > 0 ? 6 : -6)
                            skyCanvas.clampFocusAz()
                        }
                    }
                }

        Rectangle {
            id: obsBar
            anchors { top: topSection.bottom; left: parent.left; right: parent.right }
            height: plannerWindow.selectedObj ? 82 : 0
            clip: true
            color: Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.04)

            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: pal.mid
                visible: plannerWindow.selectedObj !== null
            }

            Row {
                anchors { fill: parent; topMargin: 1; leftMargin: 16; rightMargin: 16 }
                spacing: 0
                visible: plannerWindow.selectedObj !== null

                Item {
                    width: parent.width / 2 - 1
                    height: parent.height

                    Column {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left }
                        spacing: 4

                        Text {
                            text: "Recommended Session Length"
                            font.pixelSize: 11; font.bold: true; color: pal.placeholderText
                        }

                        Row {
                            spacing: 10
                            Text {
                                text: {
                                    var o = plannerWindow.selectedObj
                                    if (!o) return "—"
                                    var r = plannerWindow.recommendedSessionHours(o.type)
                                    return r.min + " – " + r.max + "  hours"
                                }
                                font.pixelSize: 18; font.bold: true; color: pal.windowText
                            }
                            Text {
                                text: plannerWindow.selectedObj ? plannerWindow.selectedObj.type : ""
                                font.pixelSize: 11; color: pal.placeholderText
                                anchors.baseline: parent.children[0] ? undefined : undefined
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            text: {
                                var o = plannerWindow.selectedObj
                                if (!o) return ""
                                var t = (o.type || "").toLowerCase()
                                if (t.indexOf("galaxy")            >= 0) return "Faint spiral detail requires deep integration"
                                if (t.indexOf("emission nebula")   >= 0) return "Narrow-band targets benefit from extended sessions"
                                if (t.indexOf("reflection nebula") >= 0) return "Blue nebulosity benefits from longer exposures"
                                if (t.indexOf("planetary nebula")  >= 0) return "Small angular size — high resolution preferred"
                                if (t.indexOf("supernova remnant") >= 0) return "Faint filaments require significant integration"
                                if (t.indexOf("globular cluster")  >= 0) return "Core saturation limits very long sessions"
                                if (t.indexOf("open cluster")      >= 0) return "Short sessions can already yield great results"
                                return "Observation length depends on target brightness"
                            }
                            font.pixelSize: 10; color: pal.placeholderText
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }

                Rectangle { width: 1; height: parent.height; color: pal.mid; anchors.verticalCenter: parent.verticalCenter }

                Item {
                    width: parent.width / 2 - 1
                    height: parent.height

                    Column {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 16; right: parent.right }
                        spacing: 4

                        Text {
                            text: "Your Observations (from FITS data)"
                            font.pixelSize: 11; font.bold: true; color: pal.placeholderText
                        }

                        Row {
                            spacing: 12
                            Text {
                                text: {
                                    var o = plannerWindow.selectedObj
                                    if (!o) return "—"
                                    var s = targetSummaryModel.integrationSecondsForTarget(o.name)
                                    return plannerWindow.fmtTotalTime(s)
                                }
                                font.pixelSize: 18; font.bold: true
                                color: {
                                    var o = plannerWindow.selectedObj
                                    if (!o) return pal.windowText
                                    var s = targetSummaryModel.integrationSecondsForTarget(o.name)
                                    return plannerWindow.obsProgressColor(s, o.type)
                                }
                            }
                            Text {
                                text: {
                                    var o = plannerWindow.selectedObj
                                    if (!o) return ""
                                    var n = targetSummaryModel.sessionCountForTarget(o.name)
                                    if (n <= 0) return ""
                                    return n + (n === 1 ? " session" : " sessions")
                                }
                                font.pixelSize: 11; color: pal.placeholderText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Item {
                            width: parent.width; height: 8

                            Rectangle {
                                anchors.fill: parent; radius: 4
                                color: Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.18)
                            }
                            Rectangle {
                                height: parent.height; radius: 4
                                width: {
                                    var o = plannerWindow.selectedObj
                                    if (!o) return 0
                                    var observed = targetSummaryModel.integrationSecondsForTarget(o.name)
                                    if (observed <= 0) return 0
                                    var recMin = plannerWindow.recommendedSessionHours(o.type).min * 3600
                                    return Math.min(parent.width, parent.width * (observed / recMin))
                                }
                                color: {
                                    var o = plannerWindow.selectedObj
                                    if (!o) return pal.highlight
                                    var s = targetSummaryModel.integrationSecondsForTarget(o.name)
                                    return plannerWindow.obsProgressColor(s, o.type)
                                }
                                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: calSection
            anchors { top: obsBar.bottom; left: parent.left; right: parent.right }
            height: calTopBorder.height + calNav.height + calDayNames.height + plannerWindow.calGridAreaH

            Rectangle {
                id: calTopBorder
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: pal.mid
            }

            Row {
                id: calNav
                anchors { top: calTopBorder.bottom; left: parent.left; right: parent.right }
                height: 28
                Button {
                    text: "‹"; flat: true; implicitWidth: 32; implicitHeight: 28
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: "Show the previous period on the calendar."
                    onClicked: plannerWindow.planNavigate(-1)
                }
                Text {
                    width: parent.width - 64 - calDensityCombo.width
                    text: plannerWindow.planRangeLabel()
                    font.pixelSize: 12; font.bold: true; color: pal.windowText
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                }
                Button {
                    text: "›"; flat: true; implicitWidth: 32; implicitHeight: 28
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: "Show the next period on the calendar."
                    onClicked: plannerWindow.planNavigate(1)
                }
                ComboBox {
                    id: calDensityCombo
                    model: ["Compact", "Normal", "Detailed"]
                    currentIndex: 0
                    font.pixelSize: 10; implicitWidth: 100; implicitHeight: 26
                    anchors.verticalCenter: parent.verticalCenter
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: "Compact = month · Normal = 7-day week · Detailed = 3-day view."
                    onActivated: plannerWindow.calendarDensity = currentText
                }
            }

            Row {
                id: calDayNames
                anchors { top: calNav.bottom; left: parent.left; right: parent.right }
                height: plannerWindow.calViewMode === "3day" ? 0 : 18
                visible: plannerWindow.calViewMode !== "3day"
                Repeater {
                    model: plannerWindow.dayNames
                    Text {
                        width: calDayNames.width / 7
                        text: modelData
                        font.pixelSize: 10; font.bold: true; color: pal.placeholderText
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Item {
                id: calGrid
                anchors { top: calDayNames.bottom; left: parent.left; right: parent.right }
                height: plannerWindow.calGridAreaH
                clip: true

                readonly property real cellW: Math.max(1, (width - (plannerWindow.calColumns - 1) * 2) / plannerWindow.calColumns)
                readonly property real cellH: plannerWindow.calViewMode === "month"
                                              ? (plannerWindow.calRowUnit - 2) : (plannerWindow.calGridAreaH - 2)

                Grid {
                    columns: plannerWindow.calColumns
                    spacing: 2

                    Repeater {
                        model: plannerWindow.planCalendarDays

                        delegate: Rectangle {
                            required property var modelData
                            property var dd: modelData
                            readonly property string dateStr: dd.dateStr

                            readonly property int daysFromToday: {
                                var today = new Date(); today.setHours(0, 0, 0, 0)
                                return Math.round((new Date(dd.yy, dd.mm - 1, dd.dd) - today) / 86400000)
                            }
                            readonly property bool isSelected:   daysFromToday === plannerWindow.nightOffset
                            readonly property bool isToday:      daysFromToday === 0
                            readonly property bool isPast:       daysFromToday < 0
                            readonly property bool isSelectable: daysFromToday >= 0

                            readonly property var wd: {
                                var _ = plannerWindow.weatherRevision
                                return weatherService.weatherForDate(dateStr)
                            }

                            width:  calGrid.cellW
                            height: calGrid.cellH
                            radius: 4
                            border.color: isSelected ? pal.highlight : pal.mid
                            border.width: isSelected ? 2 : 1
                            clip: true

                            color: isToday
                                   ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.18)
                                   : (cellMouse.containsMouse && isSelectable
                                      ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.10)
                                      : pal.base)

                            Item {
                                anchors { fill: parent; margins: 3 }
                                z: 1
                                opacity: dd.isOtherMonth ? 0.4 : (isPast ? 0.55 : 1.0)

                                Text {
                                    id: cellDayNum
                                    anchors { top: parent.top; left: parent.left }
                                    text: plannerWindow.calViewMode === "3day"
                                          ? (dd.weekdayName + " " + dd.dayNum) : dd.dayNum
                                    font.pixelSize: 11
                                    font.bold: isToday || isSelected
                                    color: pal.windowText
                                }

                                Row {
                                    id: wxRow
                                    anchors { top: parent.top; right: parent.right }
                                    spacing: 4

                                    Text {
                                        text: {
                                            if (!(wd && wd.valid)) return ""
                                            var parts = [ weatherService.getWeatherEmoji(wd.weatherCode, wd.avgCloud)
                                                          + " " + Math.round(wd.avgCloud) + "%" ]
                                            if (wd.nightTemp !== 0) {
                                                var t = weatherService.celsius ? Math.round(wd.nightTemp)
                                                                               : Math.round(wd.nightTemp * 9 / 5 + 32)
                                                parts.push("🌡 " + t + "°" + (weatherService.celsius ? "C" : "F"))
                                            }
                                            if (plannerWindow.calViewMode === "month") {
                                                if (wd.avgHumidity > 0) parts.push("💧 " + Math.round(wd.avgHumidity) + "%")
                                            } else {
                                                var detailed = plannerWindow.calViewMode === "3day"
                                                if (wd.windSpeed > 0) {
                                                    var w = Math.round(wd.windSpeed) + " km/h " + plannerWindow.compass16(wd.windDir)
                                                    parts.push(detailed ? ("💨 " + w) : w)
                                                }
                                                if (detailed && (wd.sunrise !== "" || wd.sunset !== ""))
                                                    parts.push("🌇 " + wd.sunset + " – 🌅 " + wd.sunrise)
                                            }
                                            return parts.join("  |  ")
                                        }
                                        font.pixelSize: plannerWindow.calViewMode === "month" ? 10 : 12
                                        color: pal.windowText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "|"
                                        visible: wd && wd.valid
                                        font.pixelSize: plannerWindow.calViewMode === "month" ? 10 : 12
                                        color: pal.placeholderText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: weatherService.getMoonPhase(new Date(dd.yy, dd.mm - 1, dd.dd))
                                        font.pixelSize: plannerWindow.calViewMode === "month" ? 12 : 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Item {
                                    id: pillsArea
                                    anchors {
                                        top: wxRow.bottom; topMargin: 2
                                        left: parent.left; right: parent.right
                                        bottom: plannerWindow.calViewMode === "3day" ? timeline.top : parent.bottom
                                        bottomMargin: plannerWindow.calViewMode === "3day" ? 4 : 0
                                    }
                                    clip: true

                                Column {
                                    anchors { top: parent.top; left: parent.left; right: parent.right }
                                    spacing: 2

                                    Repeater {
                                        model: {
                                            var _ = plannerWindow.scheduleRevision
                                            var objs = schedulerService.objectsForDate(dateStr)
                                            var cap = plannerWindow.calMaxObjs
                                            return objs.length > cap ? objs.slice(0, cap - 1) : objs
                                        }
                                        Rectangle {
                                            required property string modelData
                                            width: parent.width; height: 16; radius: 3
                                            readonly property bool objSelected: plannerWindow.selectedObj
                                                && plannerWindow.selectedObj.name === modelData
                                            color: objMouse.containsMouse ? Qt.lighter(pal.highlight, 1.2) : pal.highlight
                                            border.color: objSelected ? pal.highlightedText : "transparent"
                                            border.width: objSelected ? 1 : 0

                                            Text {
                                                anchors { fill: parent; leftMargin: 4; rightMargin: 3 }
                                                text: parent.modelData
                                                color: pal.highlightedText
                                                font.pixelSize: 9; font.bold: parent.objSelected
                                                elide: Text.ElideRight
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            MouseArea {
                                                id: objMouse
                                                anchors.fill: parent
                                                enabled: isSelectable && plannerWindow.calViewMode !== "month"
                                                hoverEnabled: true
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: plannerWindow.selectScheduledObject(daysFromToday, parent.modelData)
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: {
                                            var _ = plannerWindow.scheduleRevision
                                            var extra = schedulerService.countForDate(dateStr) - (plannerWindow.calMaxObjs - 1)
                                            return extra > 0 ? "+" + extra + " more" : ""
                                        }
                                        font.pixelSize: 10; font.italic: true
                                        color: pal.placeholderText
                                        visible: text !== ""
                                    }
                                }
                                }

                                Item {
                                    id: timeline
                                    visible: plannerWindow.calViewMode === "3day"
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    height: parent.height / 3
                                    clip: true
                                    readonly property int nightMin: 720
                                    readonly property int labelH: 12
                                    readonly property int laneH: 16
                                    readonly property int blockCount: {
                                        var _ = plannerWindow.scheduleRevision
                                        return schedulerService.blocksForDate(dateStr).length
                                    }
                                    function xOf(m) { return m / nightMin * width }
                                    function minAt(x) {
                                        var v = Math.round(x / Math.max(1, width) * nightMin / 15) * 15
                                        return Math.max(0, Math.min(nightMin, v))
                                    }

                                    Repeater {
                                        model: [0, 180, 360, 540, 720]
                                        delegate: Rectangle {
                                            required property int modelData
                                            x: Math.min(timeline.width - 1, timeline.xOf(modelData))
                                            y: timeline.labelH
                                            width: 1; height: timeline.height - timeline.labelH
                                            color: pal.mid; opacity: 0.4
                                        }
                                    }

                                    Text {
                                        anchors { left: parent.left; top: parent.top }
                                        text: plannerWindow.fmtNightMin(0)
                                        font.pixelSize: 8; color: pal.placeholderText
                                    }
                                    Text {
                                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
                                        text: plannerWindow.fmtNightMin(360)
                                        font.pixelSize: 8; color: pal.placeholderText
                                    }
                                    Text {
                                        anchors { right: parent.right; top: parent.top }
                                        text: plannerWindow.fmtNightMin(720)
                                        font.pixelSize: 8; color: pal.placeholderText
                                    }

                                    MouseArea {
                                        id: trackMouse
                                        anchors { left: parent.left; right: parent.right
                                                  top: parent.top; topMargin: timeline.labelH; bottom: parent.bottom }
                                        enabled: isSelectable && plannerWindow.selectedObj
                                        property int startMin: -1
                                        property int curMin: -1
                                        onPressed: function(mouse) { startMin = timeline.minAt(mouse.x); curMin = startMin }
                                        onPositionChanged: function(mouse) { if (startMin >= 0) curMin = timeline.minAt(mouse.x) }
                                        onReleased: function(mouse) {
                                            if (startMin >= 0 && plannerWindow.selectedObj) {
                                                var a = Math.min(startMin, curMin), b = Math.max(startMin, curMin)
                                                if (b - a >= 15)
                                                    schedulerService.addBlock(dateStr, plannerWindow.selectedObj.name, a, b)
                                            }
                                            startMin = -1; curMin = -1
                                        }
                                    }

                                    Rectangle {
                                        readonly property color baseCol: plannerWindow.selectedObj
                                            ? plannerWindow.colorForObject(plannerWindow.selectedObj.name) : pal.highlight
                                        visible: trackMouse.startMin >= 0 && trackMouse.curMin !== trackMouse.startMin
                                        x: timeline.xOf(Math.min(trackMouse.startMin, trackMouse.curMin))
                                        width: Math.abs(timeline.xOf(trackMouse.curMin) - timeline.xOf(trackMouse.startMin))
                                        y: timeline.labelH + 1 + timeline.blockCount * timeline.laneH
                                        height: timeline.laneH - 2
                                        radius: 3
                                        color: Qt.rgba(baseCol.r, baseCol.g, baseCol.b, 0.5)
                                        border.color: pal.highlight; border.width: 1
                                    }

                                    Repeater {
                                        model: {
                                            var _ = plannerWindow.scheduleRevision
                                            return schedulerService.blocksForDate(dateStr)
                                        }
                                        delegate: Rectangle {
                                            required property var modelData
                                            x: timeline.xOf(modelData.start)
                                            width: Math.max(6, timeline.xOf(modelData.end) - timeline.xOf(modelData.start))
                                            y: timeline.labelH + 1 + modelData.index * timeline.laneH
                                            height: timeline.laneH - 2
                                            radius: 3
                                            color: plannerWindow.colorForObject(modelData.object)
                                            border.color: Qt.darker(color, 1.4); border.width: 1
                                            clip: true

                                            Text {
                                                anchors { fill: parent; leftMargin: 3; rightMargin: 3 }
                                                text: modelData.object + " " + plannerWindow.fmtNightMin(modelData.start)
                                                      + "–" + plannerWindow.fmtNightMin(modelData.end)
                                                color: "white"
                                                font.pixelSize: 8
                                                elide: Text.ElideRight
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: schedulerService.removeBlockAt(dateStr, modelData.index)
                                                ToolTip.visible: containsMouse
                                                ToolTip.delay: 600
                                                ToolTip.text: "Click to remove this time block"
                                            }
                                        }
                                    }

                                    Text {
                                        anchors { left: parent.left; leftMargin: 4
                                                  right: parent.right; rightMargin: 4
                                                  top: parent.top; topMargin: timeline.labelH + 6 }
                                        text: "Select an object, then drag across to block a time slot"
                                        visible: !plannerWindow.selectedObj && timeline.blockCount === 0
                                        font.pixelSize: 8; color: pal.placeholderText
                                        wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                            }

                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: isSelectable
                                cursorShape: isSelectable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: plannerWindow.nightOffset = daysFromToday
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: topSection
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: Math.max(detailColumn.height + 36,
                             Math.max(200, pageFlick.height - obsBar.height - calSection.height))

            Item {
                id: listPanel
                anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
                readonly property int contentWidth: 12 + 626 + 16
                width: Math.min(parent.width * 0.55, contentWidth)

                Item {
                    id: listTitleRow
                    anchors { top: parent.top; topMargin: 8; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12 }
                    height: 28

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: "Observable Objects"
                        font.pixelSize: 13; font.bold: true; color: pal.windowText
                    }

                    Rectangle {
                        id: searchBox
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 200; height: 26; radius: 4
                        color: pal.base
                        border.color: searchField.activeFocus ? pal.highlight : pal.mid
                        border.width: searchField.activeFocus ? 2 : 1

                        Text {
                            id: searchIcon
                            anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                            text: "⌕"; font.pixelSize: 14; color: pal.placeholderText
                        }

                        TextField {
                            id: searchField
                            anchors {
                                left: searchIcon.right; leftMargin: 4
                                right: clearSearchBtn.visible ? clearSearchBtn.left : parent.right
                                rightMargin: clearSearchBtn.visible ? 2 : 6
                                verticalCenter: parent.verticalCenter
                            }
                            height: 24
                            placeholderText: "Search…"
                            font.pixelSize: 12
                            background: Item {}
                            padding: 0; topPadding: 0; bottomPadding: 0; leftPadding: 0; rightPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            onTextChanged: plannerWindow.searchText = text
                        }

                        Text {
                            id: clearSearchBtn
                            anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                            text: "✕"; font.pixelSize: 9; color: pal.placeholderText
                            visible: searchField.text.length > 0
                            MouseArea {
                                anchors { fill: parent; margins: -4 }
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchField.clear()
                            }
                        }
                    }

                    Row {
                        id: clockToggle
                        anchors { right: searchBox.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 0

                        Repeater {
                            model: [ { lbl: "UTC", loc: false }, { lbl: "AM/PM", loc: true } ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool sel: plannerWindow.clockLocal === modelData.loc
                                width: 46; height: 24; radius: 4
                                color: sel ? pal.highlight
                                           : Qt.rgba(pal.windowText.r, pal.windowText.g, pal.windowText.b, 0.06)
                                border.color: sel ? pal.highlight : pal.mid
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.lbl
                                    font.pixelSize: 10; font.bold: parent.sel
                                    color: parent.sel ? pal.highlightedText : pal.windowText
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: plannerWindow.clockLocal = modelData.loc
                                }
                            }
                        }
                    }
                }

                Row {
                    id: listHeader
                    anchors { top: listTitleRow.bottom; topMargin: 2; left: parent.left; leftMargin: 12 }
                    height: 24; spacing: 0
                    Repeater {
                        model: [
                            { label: "Name",        w: 120 },
                            { label: "Type",        w: 120 },
                            { label: "Con",         w: 42  },
                            { label: "Mag",         w: 44  },
                            { label: "Size",        w: 56  },
                            { label: "Peak Alt",    w: 62  },
                            { label: "Window",      w: 62  },
                            { label: "UTC Visible", w: 120 },
                        ]
                        Rectangle {
                            required property var modelData
                            width: modelData.w; height: 24
                            color: plannerWindow.sortCol === modelData.label
                                   ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.22)
                                   : pal.alternateBase

                            Row {
                                anchors { fill: parent; leftMargin: 6 }
                                spacing: 3
                                Text {
                                    text: modelData.label === "UTC Visible"
                                          ? (plannerWindow.clockLabel() + " Visible")
                                          : modelData.label
                                    color: plannerWindow.sortCol === modelData.label
                                           ? pal.highlight : pal.windowText
                                    font.pixelSize: 11; font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: plannerWindow.sortAsc ? "▲" : "▼"
                                    color: pal.highlight
                                    font.pixelSize: 9
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                    visible: plannerWindow.sortCol === modelData.label
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: plannerWindow.headerClicked(modelData.label)
                            }
                        }
                    }
                }

                ListView {
                    id: objList
                    anchors {
                        top: listHeader.bottom; left: parent.left; leftMargin: 12
                        right: parent.right; bottom: listButtons.top
                    }
                    clip: true
                    model: plannerService.objects

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    onCurrentIndexChanged: {
                        if (activeFocus && currentIndex >= 0 && currentIndex < count)
                            plannerWindow.selectedObj = plannerService.objects.entryAt(currentIndex)
                    }

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
                        required property double riseUtcH
                        required property double setUtcH
                        required property int    index
                        width: objList.width
                        height: 28

                        readonly property bool isSelected:
                            plannerWindow.selectedObj !== null &&
                            plannerWindow.selectedObj.name === name

                        readonly property bool isCurrent: ListView.isCurrentItem

                        readonly property bool isScheduled: {
                            var _ = plannerWindow.scheduleRevision
                            return schedulerService.isScheduled(plannerWindow.currentNightDateStr, name)
                        }

                        property color textColor:
                            (isSelected || isCurrent || rowMouse.containsMouse)
                            ? pal.highlightedText : pal.windowText

                        Rectangle {
                            anchors.fill: parent; radius: 2
                            color: row.isSelected
                                   ? pal.highlight
                                   : (row.isCurrent || rowMouse.containsMouse
                                      ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.35)
                                      : (row.isScheduled
                                         ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.18)
                                         : (row.index % 2 === 0 ? pal.alternateBase : "transparent")))
                        }

                        Rectangle {
                            anchors { left: parent.left; leftMargin: 3; verticalCenter: parent.verticalCenter }
                            width: 6; height: 6; radius: 3
                            color: pal.highlight
                            visible: row.isScheduled && !row.isSelected
                        }

                        Row {
                            anchors.fill: parent; spacing: 0
                            Item { width: 10; height: 28 }
                            Text { width: 110; height: 28; leftPadding: 6
                                   text: row.commonName !== "" ? row.commonName : row.name
                                   color: row.textColor; font.pixelSize: 12
                                   verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                            Text { width: 120; height: 28; leftPadding: 6
                                   text: row.type; color: row.textColor; font.pixelSize: 12
                                   verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                            Text { width: 42; height: 28; leftPadding: 6
                                   text: row.constellation; color: row.textColor; font.pixelSize: 12
                                   verticalAlignment: Text.AlignVCenter }
                            Text { width: 44; height: 28; leftPadding: 6
                                   text: plannerWindow.fmtMag(row.mag); color: row.textColor; font.pixelSize: 12
                                   verticalAlignment: Text.AlignVCenter }
                            Text { width: 56; height: 28; leftPadding: 6
                                   text: plannerWindow.fmtSize(row.sizeArcmin); color: row.textColor; font.pixelSize: 12
                                   verticalAlignment: Text.AlignVCenter }
                            Text { width: 62; height: 28; leftPadding: 6
                                   text: plannerWindow.fmtAlt(row.peakAlt); color: row.textColor; font.pixelSize: 12
                                   verticalAlignment: Text.AlignVCenter }
                            Text { width: 62; height: 28; leftPadding: 6
                                   text: plannerWindow.fmtWindow(row.circumpolar, row.windowH)
                                   color: row.textColor; font.pixelSize: 12
                                   verticalAlignment: Text.AlignVCenter }
                            Text { width: 120; height: 28; leftPadding: 6
                                   text: plannerWindow.fmtViewableUTC(row.circumpolar, row.riseUtcH, row.setUtcH)
                                   color: row.textColor; font.pixelSize: 12
                                   verticalAlignment: Text.AlignVCenter }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                objList.currentIndex = index
                                objList.forceActiveFocus()
                                plannerWindow.selectedObj = plannerService.objects.entryAt(index)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: !plannerWindow.hasLocation
                              ? "Scan FITS files to set your location.\nThe planner will then list tonight's best objects."
                              : (!catalogService.ready ? "Loading catalog…" : "No objects found for this night.")
                        color: pal.placeholderText; font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter; lineHeight: 1.5
                        visible: plannerService.objects.count === 0
                    }
                }

                Row {
                    id: listButtons
                    anchors { bottom: parent.bottom; right: parent.right; rightMargin: 12; bottomMargin: 8 }
                    spacing: 8

                    Button {
                        text: "Remove"
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: "Remove the selected object from this night's schedule."
                        enabled: {
                            var _ = plannerWindow.scheduleRevision
                            return plannerWindow.selectedObj !== null
                                && schedulerService.isScheduled(plannerWindow.currentNightDateStr,
                                                                plannerWindow.selectedObj.name)
                        }
                        onClicked: {
                            if (plannerWindow.selectedObj)
                                schedulerService.toggleObject(plannerWindow.currentNightDateStr,
                                                              plannerWindow.selectedObj.name)
                        }
                    }

                    Button {
                        text: "Add"
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: "Add the selected object to this night's schedule."
                        enabled: {
                            var _ = plannerWindow.scheduleRevision
                            return plannerWindow.selectedObj !== null
                                && !schedulerService.isScheduled(plannerWindow.currentNightDateStr,
                                                                 plannerWindow.selectedObj.name)
                        }
                        onClicked: {
                            if (plannerWindow.selectedObj)
                                schedulerService.toggleObject(plannerWindow.currentNightDateStr,
                                                              plannerWindow.selectedObj.name)
                        }
                    }
                }
            }

            Rectangle {
                id: divider
                anchors { top: parent.top; bottom: parent.bottom; left: listPanel.right }
                width: 1; color: pal.mid
            }

            Item {
                anchors { top: parent.top; left: divider.right; right: parent.right; bottom: parent.bottom }
                clip: true

                Item {
                    id: detailFlick
                    anchors.fill: parent
                    clip: true

                    Column {
                        id: detailColumn
                        x: 18; y: 18
                        width: Math.max(detailFlick.width - 36, 360)
                        spacing: 12
                        property var obj: plannerWindow.selectedObj || {}

                    Column {
                        spacing: 3
                        visible: !!plannerWindow.selectedObj
                        Text {
                            text: {
                                var o = parent.parent.obj
                                if (!o) return ""
                                return (o.commonName || "") !== "" ? o.commonName : (o.name || "")
                            }
                            font.pixelSize: 22; font.bold: true; color: pal.windowText
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

                    Rectangle { width: parent.width; height: 1; color: pal.mid; visible: !!plannerWindow.selectedObj }

                    Rectangle {
                        width: typeLabel.implicitWidth + 16; height: 22; radius: 11
                        color: pal.highlight
                        visible: !!plannerWindow.selectedObj
                        Text {
                            id: typeLabel
                            anchors.centerIn: parent
                            text: (plannerWindow.selectedObj && plannerWindow.selectedObj.type) || ""
                            color: pal.highlightedText; font.pixelSize: 11; font.bold: true
                        }
                    }

                    Item {
                        width: parent.width
                        height: Math.max(statsGrid.implicitHeight, wikiThumb.visible ? wikiThumb.height : 0)
                        visible: !!plannerWindow.selectedObj
                        property var obj: parent.obj

                        Grid {
                            id: statsGrid
                            anchors { left: parent.left; top: parent.top }
                            columns: 2; columnSpacing: 20; rowSpacing: 8
                            property var obj: parent.obj

                            Text { text: "Magnitude";     color: pal.placeholderText; font.pixelSize: 12 }
                            Text { text: plannerWindow.fmtMag(statsGrid.obj.mag); color: pal.windowText; font.pixelSize: 12 }

                            Text { text: "Size";           color: pal.placeholderText; font.pixelSize: 12 }
                            Text { text: plannerWindow.fmtSize(statsGrid.obj.sizeArcmin); color: pal.windowText; font.pixelSize: 12 }

                            Text { text: "Peak Altitude";  color: pal.placeholderText; font.pixelSize: 12 }
                            Text { text: statsGrid.obj.peakAlt !== undefined
                                         ? plannerWindow.fmtAlt(statsGrid.obj.peakAlt) : "—"
                                   color: pal.windowText; font.pixelSize: 12 }

                            Text { text: "Visible Window"; color: pal.placeholderText; font.pixelSize: 12 }
                            Text { text: plannerWindow.fmtWindow(statsGrid.obj.circumpolar, statsGrid.obj.windowH)
                                   color: pal.windowText; font.pixelSize: 12 }

                            Text { text: plannerWindow.clockLabel() + " Visible"; color: pal.placeholderText; font.pixelSize: 12 }
                            Text { text: plannerWindow.fmtViewableUTC(statsGrid.obj.circumpolar,
                                             statsGrid.obj.riseUtcH, statsGrid.obj.setUtcH)
                                   color: pal.windowText; font.pixelSize: 12 }

                            Text { text: "RA  /  Dec";     color: pal.placeholderText; font.pixelSize: 12 }
                            Text { text: statsGrid.obj.raHours !== undefined
                                         ? (plannerWindow.fmtRA(statsGrid.obj.raHours) + "  ·  "
                                            + plannerWindow.fmtDec(statsGrid.obj.decDeg)) : "—"
                                   color: pal.windowText; font.pixelSize: 12 }
                        }

                        Image {
                            id: wikiThumb
                            anchors {
                                left: statsGrid.right; leftMargin: 12
                                right: parent.right
                                top: parent.top
                            }
                            height: Math.min(statsGrid.implicitHeight,
                                             Math.round(implicitHeight * width / Math.max(1, implicitWidth)))
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true; cache: true; clip: true
                            source: (plannerWindow.wikiData && plannerWindow.wikiData["thumbnailUrl"])
                                    ? plannerWindow.wikiData["thumbnailUrl"] : ""
                            visible: source !== "" || plannerWindow.wikiLoading

                            BusyIndicator {
                                anchors.centerIn: parent; width: 24; height: 24
                                running: plannerWindow.wikiLoading
                                visible: plannerWindow.wikiLoading && wikiThumb.status !== Image.Ready
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: pal.mid; visible: !!plannerWindow.selectedObj }

                    Item {
                        width: parent.width
                        height: 24
                        visible: !!plannerWindow.selectedObj

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: "Sky Arc  —  " + plannerWindow.nightLabel() + "   ·   drag to pan · scroll or +/− to zoom"
                            font.pixelSize: 12; color: pal.placeholderText
                        }

                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 4

                            Button {
                                text: "−"; flat: true; implicitWidth: 26; implicitHeight: 24
                                ToolTip.visible: hovered
                                ToolTip.delay: 500
                                ToolTip.text: "Zoom out the horizon."
                                onClicked: skyCanvas.zoom = Math.max(1.0, skyCanvas.zoom / 1.3)
                            }
                            Button {
                                text: "+"; flat: true; implicitWidth: 26; implicitHeight: 24
                                ToolTip.visible: hovered
                                ToolTip.delay: 500
                                ToolTip.text: "Zoom in on the horizon."
                                onClicked: skyCanvas.zoom = Math.min(12.0, skyCanvas.zoom * 1.3)
                            }
                            Button {
                                text: "Detailed View  ⤢"
                                flat: true
                                implicitHeight: 24
                                ToolTip.visible: hovered
                                ToolTip.delay: 500
                                ToolTip.text: "Open the full 360° interactive sky dome in its own window."
                                onClicked: plannerWindow.openSkyArcDetailed()
                            }
                        }
                    }

                    Canvas {
                        id: skyCanvas
                        width: parent.width
                        height: 240
                        visible: !!plannerWindow.selectedObj
                        onVisibleChanged: if (visible) Qt.callLater(requestPaint)

                        property var watchObj:    plannerWindow.selectedObj
                        property int watchNight:  plannerWindow.nightOffset
                        property real watchLat:   plannerWindow.latitude
                        property real watchLon:   plannerWindow.longitude
                        property bool watchClock: plannerWindow.clockLocal

                        property real focusAz: 0
                        property real zoom: 1.0
                        property bool needCenter: true
                        property real projScale: 100
                        property var  viewSectors: plannerWindow.viewSectors

                        onWatchObjChanged:   { needCenter = true; Qt.callLater(requestPaint) }
                        onWatchNightChanged: { needCenter = true; Qt.callLater(requestPaint) }
                        onWatchLatChanged:   Qt.callLater(requestPaint)
                        onWatchLonChanged:   Qt.callLater(requestPaint)
                        onWatchClockChanged: Qt.callLater(requestPaint)
                        onWidthChanged:      Qt.callLater(requestPaint)
                        onHeightChanged:     Qt.callLater(requestPaint)
                        onFocusAzChanged:    Qt.callLater(requestPaint)
                        onZoomChanged:       Qt.callLater(requestPaint)
                        onViewSectorsChanged: { clampFocusAz(); Qt.callLater(requestPaint) }

                        // Selected viewable-area band as { center, span } in degrees, or null when
                        // all (or no) directions are enabled (free 360° panning).
                        function azBand() {
                            var sel = []
                            for (var i = 0; i < 8; i++) if (viewSectors[i] === true) sel.push(i * 45)
                            if (sel.length === 0 || sel.length === 8) return null
                            sel.sort(function(a, b) { return a - b })
                            var maxGap = -1, gapAt = 0
                            for (var k = 0; k < sel.length; k++) {
                                var next = (k + 1 < sel.length) ? sel[k + 1] : sel[0] + 360
                                var gap = next - sel[k]
                                if (gap > maxGap) { maxGap = gap; gapAt = k }
                            }
                            var startAz = sel[(gapAt + 1) % sel.length]
                            var spanCenters = 360 - maxGap
                            return { center: startAz + spanCenters / 2, span: spanCenters + 45 }
                        }

                        function clampFocusAz() {
                            var band = azBand()
                            if (!band) { focusAz = ((focusAz % 360) + 360) % 360; return }
                            var half = (width / 2) / projScale * 180 / Math.PI
                            var d = focusAz - band.center
                            while (d >  180) d -= 360
                            while (d < -180) d += 360
                            var fa = band.center + d
                            var lo = band.center - band.span / 2 + half
                            var hi = band.center + band.span / 2 - half
                            if (lo > hi) fa = band.center
                            else if (fa < lo) fa = lo
                            else if (fa > hi) fa = hi
                            focusAz = fa
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            var o = plannerWindow.selectedObj
                            if (!o || !plannerWindow.hasLocation || height < 40) return

                            var DEG = Math.PI / 180, RAD = 180 / Math.PI
                            var lat = plannerWindow.latitude
                            var lon = plannerWindow.longitude
                            var bottomAxisH = 16
                            var topMargin = 12
                            var cx = width / 2
                            var cy = height - bottomAxisH
                            var scaleY = (cy - topMargin) / (Math.PI / 2)
                            var scaleX = scaleY * skyCanvas.zoom
                            var cMax = 2.0
                            projScale = scaleX

                            var transitAlt = plannerService.altitudeDeg(0, o.decDeg, lat, 0)
                            var transitAz  = plannerService.azimuthDeg(0, o.decDeg, lat, 0)
                            if (needCenter) {
                                skyCanvas.focusAz = ((transitAz % 360) + 360) % 360
                                needCenter = false
                                skyCanvas.clampFocusAz()
                            }
                            var az0 = skyCanvas.focusAz * DEG

                            function proj(altDeg, azDeg) {
                                var alt = altDeg * DEG, az = azDeg * DEG
                                var dAz = az - az0
                                var sa = Math.sin(alt), ca = Math.cos(alt)
                                var cosc = Math.max(-1, Math.min(1, ca * Math.cos(dAz)))
                                var c = Math.acos(cosc)
                                var k = (c < 1e-6) ? 1 : c / Math.sin(c)
                                return { x: cx + scaleX * k * ca * Math.sin(dAz), y: cy - scaleY * k * sa, c: c }
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
                            function drawPath(decDeg, color, lw) {
                                ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.setLineDash([])
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

                            var midnight = plannerWindow.localMidnightUTC()
                            var jdMid    = plannerService.toJD(midnight.getTime())
                            var lstMid   = plannerService.lst(jdMid, lon)
                            function clockAt(h) {
                                var t = new Date(midnight.getTime() + h * 3600000)
                                var utcH = t.getUTCHours() + t.getUTCMinutes() / 60.0 + t.getUTCSeconds() / 3600.0
                                return plannerWindow.fmtHHMM(utcH)
                            }
                            function altAt(h) {
                                return plannerService.altitudeDeg(o.raHours, o.decDeg, lat,
                                                                  plannerService.lst(jdMid + h / 24.0, lon))
                            }
                            function azAt(h) {
                                return plannerService.azimuthDeg(o.raHours, o.decDeg, lat,
                                                                 plannerService.lst(jdMid + h / 24.0, lon))
                            }

                            var pxPerDeg = scaleX * DEG
                            var tickStep = 45
                            if (skyCanvas.zoom > 1.2) {
                                var cand = [30, 15, 10, 5, 2, 1]
                                for (var ti = 0; ti < cand.length; ti++)
                                    if (cand[ti] * pxPerDeg >= 30) tickStep = cand[ti]
                            }
                            var halfSpanDeg = (width / 2) / scaleX * RAD + tickStep
                            var azStart = Math.floor((skyCanvas.focusAz - halfSpanDeg) / tickStep) * tickStep

                            ctx.setLineDash([2, 4])
                            for (var ringAlt = 15; ringAlt <= 75; ringAlt += 15) {
                                ctx.strokeStyle = pal.mid.toString(); ctx.lineWidth = 0.5
                                var ring = []
                                for (var ra = 0; ra <= 360; ra += 3) ring.push([ringAlt, ra])
                                strokeSky(ring)
                            }

                            for (var spk = azStart; spk <= skyCanvas.focusAz + halfSpanDeg; spk += tickStep) {
                                var spkMod = ((spk % 360) + 360) % 360
                                var isCardSpoke = (spkMod % 45 === 0)
                                var meridian = (spkMod === 0 || spkMod === 180)
                                ctx.setLineDash(meridian ? [] : [2, 4])
                                ctx.lineWidth = meridian ? 1.0 : (isCardSpoke ? 0.7 : 0.4)
                                ctx.strokeStyle = pal.mid.toString()
                                var spoke = []
                                for (var sa2 = 0; sa2 <= 88; sa2 += 2) spoke.push([sa2, spk])
                                strokeSky(spoke)
                            }
                            ctx.setLineDash([])

                            ctx.strokeStyle = pal.placeholderText.toString(); ctx.lineWidth = 1.3
                            var horizon = []
                            for (var hz = 0; hz <= 360; hz += 2) horizon.push([0, hz])
                            strokeSky(horizon)

                            ctx.fillStyle = pal.placeholderText.toString(); ctx.font = "9px sans-serif"; ctx.textAlign = "left"
                            for (var labAlt = 15; labAlt <= 75; labAlt += 15) {
                                var lp = proj(labAlt, skyCanvas.focusAz)
                                ctx.fillText(labAlt + "°", cx + 3, lp.y + 3)
                            }

                            var cardNames = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
                            ctx.textAlign = "center"
                            for (var az = azStart; az <= skyCanvas.focusAz + halfSpanDeg; az += tickStep) {
                                var azMod = ((az % 360) + 360) % 360
                                var cp = proj(0, az)
                                if (cp.x < 2 || cp.x > width - 2) continue
                                var card = (azMod % 45 === 0)
                                ctx.setLineDash([])
                                ctx.strokeStyle = pal.mid.toString(); ctx.lineWidth = card ? 1 : 0.5
                                ctx.beginPath(); ctx.moveTo(cp.x, cy); ctx.lineTo(cp.x, cy - (card ? 6 : 3)); ctx.stroke()
                                if (card) {
                                    var nm = cardNames[Math.round(azMod / 45) % 8]
                                    ctx.font = (nm.length === 1) ? "bold 11px sans-serif" : "10px sans-serif"
                                    ctx.fillStyle = (nm.length === 1) ? pal.windowText.toString() : pal.placeholderText.toString()
                                    ctx.fillText(nm, cp.x, cy + 13)
                                } else {
                                    ctx.font = "8px sans-serif"; ctx.fillStyle = pal.placeholderText.toString()
                                    ctx.fillText(azMod + "°", cp.x, cy + 12)
                                }
                            }

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
                            var tSet = null, tRise = null
                            var prevSun = sunAlt(jdMid + (-12) / 24.0)
                            for (var hh = -11.9; hh <= 12.0001; hh += 0.1) {
                                var ss = sunAlt(jdMid + hh / 24.0)
                                if (tSet === null && prevSun >= 0 && ss < 0) tSet = hh
                                else if (tSet !== null && tRise === null && prevSun < 0 && ss >= 0) tRise = hh
                                prevSun = ss
                            }
                            if (tSet === null)  tSet = -6
                            if (tRise === null) tRise = 6

                            var maxNightAlt = -999
                            for (var nk = 0; nk <= 48; nk++) {
                                var na = altAt(tSet + (tRise - tSet) * nk / 48)
                                if (na > maxNightAlt) maxNightAlt = na
                            }

                            if (maxNightAlt < 0) {
                                ctx.fillStyle = pal.placeholderText.toString()
                                ctx.font = "12px sans-serif"; ctx.textAlign = "center"
                                ctx.fillText((o.commonName && o.commonName !== "" ? o.commonName : o.name)
                                             + " stays below the horizon tonight.", cx, topMargin + 8)
                                return
                            }

                            drawPath(o.decDeg, pal.highlight.toString(), 2.5)

                            if (transitAlt >= 0) {
                                var tp = proj(transitAlt, transitAz)
                                if (tp.c <= cMax) {
                                    var lstToTransit = ((o.raHours * 15.0 - lstMid) % 360 + 360) % 360
                                    if (lstToTransit > 180) lstToTransit -= 360
                                    ctx.fillStyle = pal.highlight.toString()
                                    ctx.beginPath(); ctx.arc(tp.x, tp.y, 4, 0, 2 * Math.PI); ctx.fill()
                                    ctx.fillStyle = pal.windowText.toString(); ctx.font = "10px sans-serif"; ctx.textAlign = "center"
                                    ctx.fillText(transitAlt.toFixed(0) + "°  ·  " + clockAt(lstToTransit / 15.0),
                                                 tp.x, Math.max(tp.y - 8, topMargin + 4))
                                }
                            }

                            function marker(h, glyph) {
                                var ma = altAt(h)
                                if (ma < 0) return
                                var mp = proj(ma, azAt(h))
                                if (mp.c > cMax) return
                                ctx.fillStyle = pal.windowText.toString()
                                ctx.beginPath(); ctx.arc(mp.x, mp.y, 3, 0, 2 * Math.PI); ctx.fill()
                                ctx.font = "10px sans-serif"; ctx.textAlign = "center"
                                ctx.fillStyle = pal.placeholderText.toString()
                                ctx.fillText(glyph + " " + clockAt(h), mp.x, mp.y - 6)
                            }
                            marker(tSet, "▲")
                            marker(tRise, "▼")
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property real lastX: 0
                            onPressed: function(m) { lastX = m.x }
                            onPositionChanged: function(m) {
                                if (!pressed) return
                                var dDeg = (m.x - lastX) / skyCanvas.projScale * 180 / Math.PI
                                skyCanvas.focusAz = skyCanvas.focusAz - dDeg
                                skyCanvas.clampFocusAz()
                                lastX = m.x
                            }

                            HoverHandler { id: skyArcHover }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "Select an object to see its sky arc and details."
                        color: pal.placeholderText; font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        visible: !plannerWindow.selectedObj
                    }

                    Rectangle { width: parent.width; height: 1; color: pal.mid }

                    Row {
                        width: parent.width
                        height: 104
                        spacing: 0

                        Item {
                            width: parent.width / 2 - 1
                            height: parent.height

                            Column {
                                anchors { left: parent.left; top: parent.top; right: parent.right }
                                spacing: 5

                                Text {
                                    text: "Light Pollution"
                                    font.pixelSize: 11; font.bold: true; color: pal.placeholderText
                                }

                                Row {
                                    spacing: 4
                                    Repeater {
                                        model: 9
                                        Rectangle {
                                            width: 18; height: 18; radius: 9
                                            property int level: index + 1
                                            property bool active: lightPollutionService.available
                                                                  && level <= lightPollutionService.bortleClass
                                            color: active ? plannerWindow.bortleColor(lightPollutionService.bortleClass)
                                                          : "transparent"
                                            border.color: active
                                                          ? plannerWindow.bortleColor(lightPollutionService.bortleClass)
                                                          : pal.mid
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: (index + 1).toString()
                                                font.pixelSize: 8; font.bold: true
                                                color: parent.active ? "white" : pal.placeholderText
                                            }
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: lightPollutionService.available
                                          ? ("Bortle " + lightPollutionService.bortleClass
                                             + "  ·  " + lightPollutionService.bortleLabel)
                                          : lightPollutionService.status
                                    font.pixelSize: 11; color: pal.windowText
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: (lightPollutionService.available && lightPollutionService.sqm > 0)
                                          ? ("SQM  " + lightPollutionService.sqm.toFixed(2) + " mag/arcsec²"
                                             + "  ·  " + lightPollutionService.status)
                                          : lightPollutionService.status
                                    font.pixelSize: 10; color: pal.placeholderText
                                    elide: Text.ElideRight
                                    visible: lightPollutionService.available
                                }
                            }
                        }

                        Rectangle { width: 1; height: parent.height; color: pal.mid }

                        Item {
                            width: parent.width / 2 - 1
                            height: parent.height

                            Column {
                                anchors { left: parent.left; leftMargin: 12; top: parent.top; right: parent.right }
                                spacing: 6

                                Text {
                                    text: "Recommended Observation"
                                    font.pixelSize: 11; font.bold: true; color: pal.placeholderText
                                }

                                property var o: parent.parent.parent.obj || {}

                                Grid {
                                    columns: 2; columnSpacing: 10; rowSpacing: 5
                                    property var o: parent.o

                                    Text { text: "Transit";     font.pixelSize: 11; color: pal.placeholderText }
                                    Text {
                                        font.pixelSize: 11; color: pal.windowText
                                        text: {
                                            var o = parent.o
                                            if (!o || o.riseUtcH == null) return "—"
                                            if (o.circumpolar) return "All night"
                                            if (o.riseUtcH === 0 && o.setUtcH === 0) return "—"
                                            return plannerWindow.fmtHHMM(
                                                plannerWindow.transitHour(o.riseUtcH, o.setUtcH))
                                                + plannerWindow.clockSuffix()
                                        }
                                    }

                                    Text { text: "Best window"; font.pixelSize: 11; color: pal.placeholderText }
                                    Text {
                                        font.pixelSize: 11; color: pal.windowText
                                        text: {
                                            var o = parent.o
                                            if (!o || o.riseUtcH == null) return "—"
                                            return plannerWindow.recommendedWindow(
                                                o.circumpolar, o.riseUtcH, o.setUtcH)
                                        }
                                    }

                                    Text { text: "Peak alt";    font.pixelSize: 11; color: pal.placeholderText }
                                    Text {
                                        font.pixelSize: 11; color: pal.windowText
                                        text: {
                                            var o = parent.o
                                            if (!o || o.peakAlt == null) return "—"
                                            return plannerWindow.fmtAlt(o.peakAlt)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: pal.mid }

                    Column {
                        width: parent.width
                        spacing: 6
                        property real fieldH: 26

                        function clampAlt(v) { v = parseFloat(v); return isNaN(v) ? 15 : Math.max(0, Math.min(90, v)) }

                        Text {
                            text: "Viewable sky — tap the directions you can see"
                            font.pixelSize: 11; font.bold: true; color: pal.placeholderText
                        }

                        Row {
                            spacing: 4

                            Repeater {
                                model: plannerWindow.sectorNames
                                delegate: Rectangle {
                                    required property int index
                                    required property string modelData
                                    readonly property bool on: plannerWindow.viewSectors[index] === true

                                    width: 38; height: 26; radius: 4
                                    color: on ? pal.highlight
                                              : Qt.rgba(pal.windowText.r, pal.windowText.g, pal.windowText.b, 0.06)
                                    border.color: on ? pal.highlight : pal.mid
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: 11
                                        font.bold: parent.on
                                        color: parent.on ? pal.highlightedText : pal.windowText
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: plannerWindow.toggleSector(index)
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: 8

                            Text {
                                text: "Min altitude ≥"
                                font.pixelSize: 11; color: pal.windowText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            TextField {
                                id: altMinField
                                width: 46; implicitHeight: parent.parent.fieldH
                                font.pixelSize: 11; selectByMouse: true
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                text: Math.round(plannerWindow.viewMinAlt).toString()
                                onEditingFinished: plannerWindow.viewMinAlt = parent.parent.clampAlt(text)
                            }
                            Text {
                                text: "°  (trees, buildings)"
                                font.pixelSize: 11; color: pal.placeholderText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 12

                            CheckBox {
                                id: skyFilterCheck
                                text: "Show only objects in my sky"
                                font.pixelSize: 11
                                ToolTip.visible: hovered
                                ToolTip.delay: 500
                                ToolTip.text: "Filter the Observable Objects list to targets that rise\ninto your selected directions and above the altitude floor."
                                checked: plannerWindow.viewFilterEnabled
                                onToggled: plannerWindow.viewFilterEnabled = checked
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Button {
                                text: "All sky"
                                flat: true; implicitHeight: parent.parent.fieldH
                                anchors.verticalCenter: parent.verticalCenter
                                ToolTip.visible: hovered
                                ToolTip.delay: 500
                                ToolTip.text: "Reset the viewable area: enable all directions\nand the 15° minimum altitude."
                                enabled: plannerWindow.viewAreaActive
                                onClicked: {
                                    plannerWindow.viewSectors = [true, true, true, true, true, true, true, true]
                                    plannerWindow.viewMinAlt  = 15
                                    altMinField.text = "15"
                                }
                            }
                        }
                    }
                }
                }
            }
        }
            }
        }
    }

    SkyArcDetailedWindow {
        id: skyArcDetailedWindow
        visible: false
        selectedName: plannerWindow.selectedObj ? plannerWindow.selectedObj.name : ""
        onObjectSelected: function(entry) { plannerWindow.selectedObj = entry }
    }
}
