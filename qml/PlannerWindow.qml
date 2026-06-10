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
    property int weatherRevision: 0
    property int scheduleRevision: 0
    property bool showManualEntry: false

    // Sort state for the Observable Objects list
    property string sortCol:    "Peak Alt"
    property bool   sortAsc:    false
    property string searchText: ""

    onSearchTextChanged: plannerService.objects.setFilter(searchText)

    function applySort() {
        plannerService.objects.sortBy(plannerWindow.sortCol, plannerWindow.sortAsc)
    }
    function headerClicked(col) {
        if (plannerWindow.sortCol === col) {
            plannerWindow.sortAsc = !plannerWindow.sortAsc
        } else {
            plannerWindow.sortCol = col
            // String columns default ascending; numeric columns default descending
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

    // Date string ("yyyy-MM-dd") for the night currently shown in the list.
    readonly property string currentNightDateStr: {
        var d = new Date()
        d.setDate(d.getDate() + nightOffset)
        var y = d.getFullYear()
        var m = d.getMonth() + 1
        var day = d.getDate()
        return y + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day
    }

    // Calendar navigation state (follows nightOffset, also navigable independently)
    property int calendarYear:  (new Date()).getFullYear()
    property int calendarMonth: (new Date()).getMonth() + 1  // 1–12

    // ── Helpers ────────────────────────────────────────────────────────────────

    function localMidnightUTC() {
        var d = new Date()
        d.setHours(23, 0, 0, 0)
        d.setDate(d.getDate() + nightOffset)
        return d
    }

    function nightLabel() {
        if (nightOffset === 0) return "Tonight"
        if (nightOffset === 1) return "Tomorrow"
        var d = new Date()
        d.setDate(d.getDate() + nightOffset)
        return d.toLocaleDateString(Qt.locale(), "ddd d MMM")
    }

    // ── Calendar math ─────────────────────────────────────────────────────────

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

    // ── Formatters ────────────────────────────────────────────────────────────

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
        var hh = ((Math.floor(h) % 24) + 24) % 24
        var mm = Math.round((h - Math.floor(h)) * 60)
        if (mm === 60) { hh = (hh + 1) % 24; mm = 0 }
        return (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm
    }
    function fmtViewableUTC(circ, riseH, setH) {
        if (circ) return "All night"
        if (riseH === 0 && setH === 0) return "—"
        return fmtHHMM(riseH) + "–" + fmtHHMM(setH)
    }
    // ── Session-length helpers ────────────────────────────────────────────────

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

    // ── Light pollution / observation time helpers ────────────────────────────

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
        return fmtHHMM((t - half + 24) % 24) + " – " + fmtHHMM((t + half) % 24) + " UTC"
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

    // ── Reactivity ────────────────────────────────────────────────────────────

    onNightOffsetChanged: {
        var d = new Date()
        d.setDate(d.getDate() + nightOffset)
        plannerWindow.calendarYear  = d.getFullYear()
        plannerWindow.calendarMonth = d.getMonth() + 1
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
                font.pixelSize: 17; font.bold: true; color: pal.windowText
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle { width: 1; height: 28; color: pal.mid; anchors.verticalCenter: parent.verticalCenter }

            // Location display
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
                checked: plannerWindow.showManualEntry
                onClicked: plannerWindow.showManualEntry = !plannerWindow.showManualEntry
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 4
            Button {
                text: "‹"; flat: true; enabled: plannerWindow.nightOffset > 0
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
                onClicked: plannerWindow.nightOffset++
                implicitWidth: 28; implicitHeight: 28
            }
        }
    }

    // ── Body ─────────────────────────────────────────────────────────────────

    Item {
        id: body
        anchors { top: headerBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }

        // ── Manual location entry bar (slides in below header) ────────────────

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
                    onClicked: plannerWindow.applyManualLocation()
                }

                Button {
                    text: "Cancel"
                    flat: true
                    implicitHeight: 32
                    anchors.verticalCenter: parent.verticalCenter
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

        // ── Observation summary band (between detail panel and calendar) ────────

        Rectangle {
            id: obsBar
            anchors { left: parent.left; right: parent.right; bottom: calSection.top }
            height: plannerWindow.selectedObj ? 82 : 0
            clip: true
            color: Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.04)

            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // top separator line
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: pal.mid
                visible: plannerWindow.selectedObj !== null
            }

            Row {
                anchors { fill: parent; topMargin: 1; leftMargin: 16; rightMargin: 16 }
                spacing: 0
                visible: plannerWindow.selectedObj !== null

                // ── Left: recommended session length ─────────────────────────
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

                // vertical divider
                Rectangle { width: 1; height: parent.height; color: pal.mid; anchors.verticalCenter: parent.verticalCenter }

                // ── Right: observed to date (from FITS data) ─────────────────
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
                                font.pixelSize: 18; font.bold: true; color: pal.windowText
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

                        // Progress bar: observed / recommended-minimum
                        Item {
                            width: parent.width; height: 8

                            Rectangle {
                                anchors.fill: parent; radius: 4
                                color: Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.18)
                            }
                            Rectangle {
                                height: parent.height; radius: 4
                                color: pal.highlight
                                width: {
                                    var o = plannerWindow.selectedObj
                                    if (!o) return 0
                                    var observed = targetSummaryModel.integrationSecondsForTarget(o.name)
                                    if (observed <= 0) return 0
                                    var recMin = plannerWindow.recommendedSessionHours(o.type).min * 3600
                                    return Math.min(parent.width, parent.width * (observed / recMin))
                                }
                                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }
        }

        // ── Full-width calendar at the bottom ─────────────────────────────────

        Item {
            id: calSection
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            // Height grows with scheduled objects; rows expand to show names.
            height: calTopBorder.height + calNav.height + calDayNames.height + calGrid.totalHeight

            Rectangle {
                id: calTopBorder
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: pal.mid
            }

            // Month nav: "‹  June 2026  ›"
            Row {
                id: calNav
                anchors { top: calTopBorder.bottom; left: parent.left; right: parent.right }
                height: 28
                Button {
                    text: "‹"; flat: true; implicitWidth: 32; implicitHeight: 28
                    onClicked: {
                        if (plannerWindow.calendarMonth === 1) {
                            plannerWindow.calendarMonth = 12; plannerWindow.calendarYear--
                        } else {
                            plannerWindow.calendarMonth--
                        }
                    }
                }
                Text {
                    width: parent.width - 64
                    text: plannerWindow.monthName(plannerWindow.calendarMonth) + " " + plannerWindow.calendarYear
                    font.pixelSize: 12; font.bold: true; color: pal.windowText
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                }
                Button {
                    text: "›"; flat: true; implicitWidth: 32; implicitHeight: 28
                    onClicked: {
                        if (plannerWindow.calendarMonth === 12) {
                            plannerWindow.calendarMonth = 1; plannerWindow.calendarYear++
                        } else {
                            plannerWindow.calendarMonth++
                        }
                    }
                }
            }

            // Day-of-week header
            Row {
                id: calDayNames
                anchors { top: calNav.bottom; left: parent.left; right: parent.right }
                height: 18
                Repeater {
                    model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                    Text {
                        width: calDayNames.width / 7
                        text: modelData
                        font.pixelSize: 10; font.bold: true; color: pal.placeholderText
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Grid — rows grow to show scheduled object names
            Item {
                id: calGrid
                anchors { top: calDayNames.bottom; left: parent.left; right: parent.right }
                height: totalHeight
                clip: true

                readonly property real cellW: width / 7
                readonly property int numWeeks: plannerWindow.weeksInMonth(plannerWindow.calendarYear, plannerWindow.calendarMonth)

                // Per-row heights: 42px base + 13px per scheduled object name (max 5 shown).
                // Each row takes the height needed by its most-scheduled cell.
                readonly property var rowHeights: {
                    var _sr = plannerWindow.scheduleRevision
                    var cy  = plannerWindow.calendarYear
                    var cm  = plannerWindow.calendarMonth
                    var nw  = plannerWindow.weeksInMonth(cy, cm)
                    var fw  = plannerWindow.firstWeekdayOfMonth(cy, cm)
                    var dim = plannerWindow.daysInMonth(cy, cm)
                    var heights = []
                    for (var r = 0; r < nw; r++) {
                        var maxObjs = 0
                        for (var c = 0; c < 7; c++) {
                            var dn = r * 7 + c - fw + 1
                            if (dn >= 1 && dn <= dim) {
                                var ds = cy + "-" + (cm < 10 ? "0" : "") + cm
                                             + "-" + (dn < 10 ? "0" : "") + dn
                                var n = schedulerService.countForDate(ds)
                                if (n > maxObjs) maxObjs = n
                            }
                        }
                        heights.push(42 + Math.min(maxObjs, 5) * 13)
                    }
                    return heights
                }

                // Cumulative y offsets: rowOffsets[i] = top of row i
                readonly property var rowOffsets: {
                    var h = rowHeights; var o = [0]
                    for (var i = 0; i < h.length; i++) o.push(o[i] + h[i])
                    return o
                }

                readonly property real totalHeight: rowOffsets.length > 1
                    ? rowOffsets[rowOffsets.length - 1] : 210

                Repeater {
                    model: 42

                    delegate: Rectangle {
                        required property int index

                        readonly property int col:    index % 7
                        readonly property int rowIdx: Math.floor(index / 7)
                        readonly property int dayNum: index
                            - plannerWindow.firstWeekdayOfMonth(plannerWindow.calendarYear, plannerWindow.calendarMonth)
                            + 1
                        readonly property bool isValid: dayNum >= 1
                            && dayNum <= plannerWindow.daysInMonth(plannerWindow.calendarYear, plannerWindow.calendarMonth)
                            && rowIdx < calGrid.numWeeks

                        readonly property int cy: plannerWindow.calendarYear
                        readonly property int cm: plannerWindow.calendarMonth

                        readonly property string dateStr: isValid
                            ? cy + "-" + (cm < 10 ? "0" : "") + cm
                                  + "-" + (dayNum < 10 ? "0" : "") + dayNum
                            : ""

                        readonly property int daysFromToday: {
                            if (!isValid) return -9999
                            var today = new Date(); today.setHours(0, 0, 0, 0)
                            return Math.round((new Date(cy, cm - 1, dayNum) - today) / 86400000)
                        }

                        readonly property var wd: {
                            var _ = plannerWindow.weatherRevision
                            if (!isValid) return null
                            return weatherService.weatherForDate(dateStr)
                        }

                        readonly property bool isSelected:   isValid && daysFromToday === plannerWindow.nightOffset
                        readonly property bool isToday:      isValid && daysFromToday === 0
                        readonly property bool isPast:       isValid && daysFromToday < 0
                        readonly property bool isSelectable: isValid && daysFromToday >= 0

                        x: col * calGrid.cellW
                        y: calGrid.rowOffsets.length > rowIdx ? calGrid.rowOffsets[rowIdx] : rowIdx * 42
                        width:  calGrid.cellW
                        height: calGrid.rowHeights.length > rowIdx ? calGrid.rowHeights[rowIdx] : 42
                        visible: isValid

                        color: isSelected
                               ? pal.highlight
                               : (isToday
                                  ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.22)
                                  : (cellMouse.containsMouse && isSelectable
                                     ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.13)
                                     : "transparent"))

                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 1; color: pal.mid; opacity: 0.35
                        }
                        Rectangle {
                            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                            width: 1; color: pal.mid; opacity: 0.35; visible: col < 6
                        }

                        Item {
                            anchors { fill: parent; margins: 3 }
                            opacity: isPast ? 0.5 : 1.0

                            // Day number (top-left)
                            Text {
                                id: cellDayNum
                                anchors { top: parent.top; left: parent.left }
                                text: dayNum; font.pixelSize: 11
                                font.bold: isToday || isSelected
                                color: isSelected ? pal.highlightedText : pal.windowText
                            }

                            // Moon phase (top-right)
                            Text {
                                anchors { top: parent.top; right: parent.right }
                                text: {
                                    if (!isValid) return ""
                                    var d = new Date(cy, cm - 1, dayNum); d.setHours(0, 0, 0, 0)
                                    return weatherService.getMoonPhase(d)
                                }
                                font.pixelSize: 12
                            }

                            // Scheduled object names (below day number)
                            Column {
                                anchors { top: cellDayNum.bottom; topMargin: 1; left: parent.left; right: parent.right }
                                spacing: 0

                                Repeater {
                                    model: {
                                        var _ = plannerWindow.scheduleRevision
                                        if (!isValid) return []
                                        var objs = schedulerService.objectsForDate(dateStr)
                                        return objs.length > 5 ? objs.slice(0, 4) : objs
                                    }
                                    Text {
                                        required property string modelData
                                        width: parent.width; text: modelData
                                        font.pixelSize: 10
                                        color: isSelected ? pal.highlightedText : pal.highlight
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: {
                                        var _ = plannerWindow.scheduleRevision
                                        if (!isValid) return ""
                                        var extra = schedulerService.countForDate(dateStr) - 4
                                        return extra > 0 ? "+" + extra + " more" : ""
                                    }
                                    font.pixelSize: 10; font.italic: true
                                    color: isSelected ? pal.highlightedText : pal.placeholderText
                                    visible: text !== ""
                                }
                            }

                            // Weather (bottom-left)
                            Text {
                                anchors { bottom: parent.bottom; left: parent.left }
                                text: (wd && wd.valid)
                                      ? weatherService.getWeatherEmoji(wd.weatherCode, wd.avgCloud)
                                        + " " + Math.round(wd.avgCloud) + "%"
                                      : ""
                                font.pixelSize: 10
                                color: isSelected ? pal.highlightedText : pal.windowText
                                elide: Text.ElideRight
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

        // ── Top section: list + detail, above the calendar ────────────────────

        Item {
            id: topSection
            anchors { top: manualEntryBar.bottom; left: parent.left; right: parent.right; bottom: obsBar.top }

            // ── Left panel: object list ───────────────────────────────────────

            Item {
                id: listPanel
                anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
                width: parent.width * 0.55

                // Title row: "Observable Objects" + search box on the right
                Item {
                    id: listTitleRow
                    anchors { top: parent.top; topMargin: 8; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12 }
                    height: 28

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: "Observable Objects"
                        font.pixelSize: 13; font.bold: true; color: pal.windowText
                    }

                    // Search box
                    Rectangle {
                        id: searchBox
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 200; height: 26; radius: 4
                        color: pal.base
                        border.color: searchField.activeFocus ? pal.highlight : pal.mid
                        border.width: searchField.activeFocus ? 2 : 1

                        // ⌕ icon
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

                        // ✕ clear button
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
                }

                // Column headers (clickable — click to sort, click again to reverse)
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
                                    text: modelData.label
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

                // Scrollable object list
                ListView {
                    id: objList
                    anchors {
                        top: listHeader.bottom; left: parent.left; leftMargin: 12
                        right: parent.right; bottom: listButtons.top
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
                        required property double riseUtcH
                        required property double setUtcH
                        required property int    index
                        width: objList.width
                        height: 28

                        readonly property bool isSelected:
                            plannerWindow.selectedObj !== null &&
                            plannerWindow.selectedObj.name === name

                        readonly property bool isScheduled: {
                            var _ = plannerWindow.scheduleRevision
                            return schedulerService.isScheduled(plannerWindow.currentNightDateStr, name)
                        }

                        property color textColor:
                            (isSelected || rowMouse.containsMouse)
                            ? pal.highlightedText : pal.windowText

                        Rectangle {
                            anchors.fill: parent; radius: 2
                            color: row.isSelected
                                   ? pal.highlight
                                   : (row.isScheduled
                                      ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.18)
                                      : (rowMouse.containsMouse
                                         ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.35)
                                         : (row.index % 2 === 0 ? pal.alternateBase : "transparent")))
                        }

                        // Scheduled indicator dot (left edge)
                        Rectangle {
                            anchors { left: parent.left; leftMargin: 3; verticalCenter: parent.verticalCenter }
                            width: 6; height: 6; radius: 3
                            color: pal.highlight
                            visible: row.isScheduled && !row.isSelected
                        }

                        Row {
                            anchors.fill: parent; spacing: 0
                            // 10px indent so dot doesn't overlap text
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
                            onClicked: plannerWindow.selectedObj = plannerService.objects.entryAt(index)
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

                // Add / Remove buttons (bottom-right of list panel)
                Row {
                    id: listButtons
                    anchors { bottom: parent.bottom; right: parent.right; rightMargin: 12; bottomMargin: 8 }
                    spacing: 8

                    Button {
                        text: "Remove"
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

            // Divider
            Rectangle {
                id: divider
                anchors { top: parent.top; bottom: parent.bottom; left: listPanel.right }
                width: 1; color: pal.mid
            }

            // ── Detail panel (right ~45 %) ────────────────────────────────────

            Item {
                anchors { top: parent.top; left: divider.right; right: parent.right; bottom: parent.bottom }
                property var obj: plannerWindow.selectedObj

                Text {
                    anchors.centerIn: parent
                    text: "Select an object to see details"
                    color: pal.placeholderText; font.pixelSize: 13
                    visible: !parent.obj
                }

                Column {
                    anchors { fill: parent; margins: 18 }
                    spacing: 12
                    visible: !!parent.obj
                    property var obj: parent.obj || {}

                    Column {
                        spacing: 3
                        Text {
                            text: parent.parent.obj.commonName !== ""
                                  ? parent.parent.obj.commonName : parent.parent.obj.name || ""
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

                    Grid {
                        id: statsGrid
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

                        Text { text: "UTC Visible";    color: pal.placeholderText; font.pixelSize: 12 }
                        Text { text: plannerWindow.fmtViewableUTC(statsGrid.obj.circumpolar,
                                         statsGrid.obj.riseUtcH, statsGrid.obj.setUtcH)
                               color: pal.windowText; font.pixelSize: 12 }

                        Text { text: "RA  /  Dec";     color: pal.placeholderText; font.pixelSize: 12 }
                        Text { text: statsGrid.obj.raHours !== undefined
                                     ? (plannerWindow.fmtRA(statsGrid.obj.raHours) + "  ·  "
                                        + plannerWindow.fmtDec(statsGrid.obj.decDeg)) : "—"
                               color: pal.windowText; font.pixelSize: 12 }
                    }

                    Rectangle { width: parent.width; height: 1; color: pal.mid }

                    Text {
                        text: "Sky Arc  —  " + plannerWindow.nightLabel()
                        font.pixelSize: 12; color: pal.placeholderText
                    }

                    Canvas {
                        id: skyCanvas
                        width: parent.width
                        height: Math.min(200, topSection.height - 500)

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
                            var r  = cy - 4

                            ctx2d.strokeStyle = pal.mid.toString()
                            ctx2d.lineWidth = 1; ctx2d.setLineDash([])
                            ctx2d.beginPath(); ctx2d.moveTo(0, cy); ctx2d.lineTo(width, cy); ctx2d.stroke()

                            ctx2d.setLineDash([2, 4]); ctx2d.lineWidth = 0.5
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

                            ctx2d.fillStyle = pal.placeholderText.toString()
                            ctx2d.textAlign = "center"; ctx2d.font = "10px sans-serif"
                            ctx2d.fillText("−6h", cx - r / 2, cy + 12)
                            ctx2d.fillText("midnight", cx, cy + 12)
                            ctx2d.fillText("+6h", cx + r / 2, cy + 12)

                            var midnight = plannerWindow.localMidnightUTC()
                            var jdMid   = plannerService.toJD(midnight.getTime())
                            var lstMid  = plannerService.lst(jdMid, plannerWindow.longitude)

                            ctx2d.beginPath()
                            var started = false
                            for (var step = 0; step <= 96; step++) {
                                var h = -12.0 + step * 0.25
                                var jd = jdMid + h / 24.0
                                var lstH = plannerService.lst(jd, plannerWindow.longitude)
                                var altH = plannerService.altitudeDeg(o.raHours, o.decDeg, plannerWindow.latitude, lstH)
                                var px = cx + (h / 12.0) * r
                                var py = cy - (altH / 90.0) * r
                                if (altH < 15.0) { started = false; continue }
                                if (!started) { ctx2d.moveTo(px, py); started = true }
                                else ctx2d.lineTo(px, py)
                            }
                            ctx2d.strokeStyle = pal.highlight.toString()
                            ctx2d.lineWidth = 2.5; ctx2d.stroke()

                            var altMid = plannerService.altitudeDeg(o.raHours, o.decDeg, plannerWindow.latitude, lstMid)
                            if (altMid >= 15.0) {
                                var dotY = cy - (altMid / 90.0) * r
                                ctx2d.fillStyle = pal.highlight.toString()
                                ctx2d.beginPath(); ctx2d.arc(cx, dotY, 4, 0, 2 * Math.PI); ctx2d.fill()
                            }
                        }
                    }

                    // ── Bottom info row: light pollution + recommended time ────

                    Rectangle { width: parent.width; height: 1; color: pal.mid }

                    Row {
                        width: parent.width
                        height: 104
                        spacing: 0

                        // ── Left: Light pollution / Bortle scale ─────────────
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

                                // 9 Bortle-class dots
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

                        // vertical divider
                        Rectangle { width: 1; height: parent.height; color: pal.mid }

                        // ── Right: Recommended observation time ───────────────
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

                                property var o: parent.parent.parent.parent.parent.obj || {}

                                Grid {
                                    columns: 2; columnSpacing: 10; rowSpacing: 5
                                    property var o: parent.o

                                    Text { text: "Transit";     font.pixelSize: 11; color: pal.placeholderText }
                                    Text {
                                        font.pixelSize: 11; color: pal.windowText
                                        text: {
                                            var o = parent.o
                                            if (!o || !o.riseUtcH) return "—"
                                            if (o.circumpolar) return "All night"
                                            if (o.riseUtcH === 0 && o.setUtcH === 0) return "—"
                                            return plannerWindow.fmtHHMM(
                                                plannerWindow.transitHour(o.riseUtcH, o.setUtcH)) + " UTC"
                                        }
                                    }

                                    Text { text: "Best window"; font.pixelSize: 11; color: pal.placeholderText }
                                    Text {
                                        font.pixelSize: 11; color: pal.windowText
                                        text: {
                                            var o = parent.o
                                            if (!o || !o.riseUtcH) return "—"
                                            return plannerWindow.recommendedWindow(
                                                o.circumpolar, o.riseUtcH, o.setUtcH)
                                        }
                                    }

                                    Text { text: "Peak alt";    font.pixelSize: 11; color: pal.placeholderText }
                                    Text {
                                        font.pixelSize: 11; color: pal.windowText
                                        text: {
                                            var o = parent.o
                                            if (!o || o.peakAlt === undefined) return "—"
                                            return plannerWindow.fmtAlt(o.peakAlt)
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
