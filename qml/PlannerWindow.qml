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

    // Clock display for arc + list times: false = UTC (24-hour), true = the
    // observing location's local time shown as 12-hour AM/PM. Session-only.
    property bool clockLocal: false

    // Viewable sky window for narrowing the planning scope (session-only).
    // The sky is split into 8 compass sectors (N, NE, E, SE, S, SW, W, NW),
    // each spanning 45°.  A sector is true when that direction is unobstructed
    // from the observing site.  An object counts as "in view" when its azimuth
    // falls in an enabled sector AND its altitude ≥ viewMinAlt.
    property var  viewSectors: [true, true, true, true, true, true, true, true]
    property real viewMinAlt:  15   // horizon-obstruction altitude floor
    readonly property var  sectorNames: ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    readonly property bool viewAreaActive: viewSectors.indexOf(false) >= 0 || viewMinAlt > 15

    // When true, the Observable Objects list is restricted to objects that pass
    // through an enabled sector above the altitude floor on the selected night.
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

    // Sort state for the Observable Objects list
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
        // Anchor the sky-arc window to the observing location's local time,
        // derived from its longitude — NOT the computer's timezone — so the
        // timeframe is correct even when the PC clock is in a different zone.
        // Local mean solar time = UTC + longitude/15  ⇒  UTC = local − lon/15.
        var now = new Date()
        var da  = now.getDate() + nightOffset
        var ms  = Date.UTC(now.getFullYear(), now.getMonth(), da, 23, 0, 0)
                  - (longitude / 15.0) * 3600000
        return new Date(ms)
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
    // Format a UTC hour-of-day per the selected clock mode.
    // UTC  → 24-hour "HH:MM"   |   Local → 12-hour "H:MM AM/PM" (UTC + lon/15).
    function fmtHHMM(h) {
        if (clockLocal) h += longitude / 15.0
        var hh = ((Math.floor(h) % 24) + 24) % 24
        var mm = Math.round((h - Math.floor(h)) * 60)
        if (mm === 60) { hh = (hh + 1) % 24; mm = 0 }
        if (clockLocal) {
            var ap  = hh < 12 ? "AM" : "PM"
            var h12 = hh % 12; if (h12 === 0) h12 = 12
            return h12 + ":" + (mm < 10 ? "0" : "") + mm + " " + ap
        }
        return (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm
    }
    // Suffix / short label for the active clock mode.
    function clockSuffix() { return clockLocal ? "" : " UTC" }
    function clockLabel()  { return clockLocal ? "Local" : "UTC" }
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

    // Returns a red/yellow/green color based on observed vs recommended-minimum hours.
    // < 50 % of min → red   |   50–99 % → yellow   |   ≥ 100 % → green
    function obsProgressColor(observedSeconds, type) {
        if (observedSeconds <= 0) return pal.placeholderText
        var recMin = recommendedSessionHours(type).min * 3600
        var ratio  = observedSeconds / recMin
        if (ratio >= 1.0) return "#66bb6a"
        if (ratio >= 0.5) return "#ffd54f"
        return "#ef5350"
    }

    // ── Cardinal direction / viewable-area helpers ────────────────────────────

    // 16-point compass abbreviation for a bearing in degrees from North.
    function compass16(az) {
        var pts = ["N","NNE","NE","ENE","E","ESE","SE","SSE",
                   "S","SSW","SW","WSW","W","WNW","NW","NNW"]
        return pts[Math.round(((az % 360) + 360) % 360 / 22.5) % 16]
    }

    // Compass sector index (0=N, 1=NE, … 7=NW) for a bearing in degrees.
    function sectorOf(az) {
        return Math.round((((az % 360) + 360) % 360) / 45) % 8
    }

    // Is the sky in this bearing's direction marked as viewable?
    function azInSweep(az) {
        return viewSectors[sectorOf(az)] === true
    }

    // Object is observable from this site when its direction is unobstructed
    // and it is above the obstruction altitude floor.
    function inView(az, alt) {
        return alt >= viewMinAlt && azInSweep(az)
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

                        // Progress bar: observed / recommended-minimum
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
                // Never wider than the rightmost column: left margin (12) + the eight
                // column widths (626) + room for the scrollbar (16).
                readonly property int contentWidth: 12 + 626 + 16
                width: Math.min(parent.width * 0.55, contentWidth)

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

                    // Clock display toggle: UTC (24h) vs the location's local AM/PM.
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
                clip: true

                // Scroll the whole detail panel (like the FITS viewer) so the Sky Arc
                // keeps a usable minimum size on any window — scrollbars appear when the
                // content is taller or wider than the available space.
                Flickable {
                    id: detailFlick
                    anchors.fill: parent
                    clip: true
                    contentWidth:  Math.max(width,  detailColumn.width  + 36)
                    contentHeight: Math.max(height, detailColumn.height + 36)
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical:   ScrollBar { policy: ScrollBar.AsNeeded }
                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                    Column {
                        id: detailColumn
                        x: 18; y: 18
                        width: Math.max(detailFlick.width - 36, 360)   // minimum content width
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

                    // Stats + Wikipedia thumbnail side-by-side
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

                        // Wikipedia thumbnail — right of stats, vertically centred
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

                    Text {
                        text: "Sky Arc  —  " + plannerWindow.nightLabel()
                        font.pixelSize: 12; color: pal.placeholderText
                        visible: !!plannerWindow.selectedObj
                    }

                    Canvas {
                        id: skyCanvas
                        width: parent.width                 // ≥ 360 via detailColumn min width
                        height: 240                         // fixed minimum; panel scrolls if needed
                        visible: !!plannerWindow.selectedObj
                        onVisibleChanged: if (visible) Qt.callLater(requestPaint)

                        property var watchObj:    plannerWindow.selectedObj
                        property int watchNight:  plannerWindow.nightOffset
                        property real watchLat:   plannerWindow.latitude
                        property real watchLon:   plannerWindow.longitude
                        property var  watchSectors: plannerWindow.viewSectors
                        property real watchVMinAlt: plannerWindow.viewMinAlt
                        property bool watchClock:   plannerWindow.clockLocal

                        onWatchObjChanged:     Qt.callLater(requestPaint)
                        onWatchNightChanged:   Qt.callLater(requestPaint)
                        onWatchLatChanged:     Qt.callLater(requestPaint)
                        onWatchLonChanged:     Qt.callLater(requestPaint)
                        onWatchSectorsChanged: Qt.callLater(requestPaint)
                        onWatchVMinAltChanged: Qt.callLater(requestPaint)
                        onWatchClockChanged:   Qt.callLater(requestPaint)
                        onWidthChanged:        Qt.callLater(requestPaint)
                        onHeightChanged:       Qt.callLater(requestPaint)

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            var o = plannerWindow.selectedObj
                            if (!o || !plannerWindow.hasLocation || height < 40) return

                            var lat  = plannerWindow.latitude
                            var lon  = plannerWindow.longitude
                            var padL = 26, padR = 8
                            var stripH = 13                         // compass strip under the axis
                            var cy   = height - 16 - stripH
                            var rTop = cy - 4                       // pixels for 0°→90° altitude
                            var plotW = Math.max(1, width - padL - padR)

                            var midnight = plannerWindow.localMidnightUTC()
                            var jdMid    = plannerService.toJD(midnight.getTime())
                            var lstMid   = plannerService.lst(jdMid, lon)

                            // Approximate sun altitude at a given JD (±1° accuracy)
                            function sunAlt(jd) {
                                var T   = (jd - 2451545.0) / 36525.0
                                var M   = (357.52911 + 35999.05029 * T) * Math.PI / 180
                                var lam = (280.46646 + 36000.76983 * T
                                           + (1.914602 - 0.004817 * T) * Math.sin(M)
                                           + 0.019993 * Math.sin(2 * M)) * Math.PI / 180
                                var eps = (23.439291 - 0.013004 * T) * Math.PI / 180
                                var raH = (Math.atan2(Math.cos(eps) * Math.sin(lam), Math.cos(lam))
                                           * 180 / Math.PI / 15 + 24) % 24
                                var dec = Math.asin(Math.sin(eps) * Math.sin(lam)) * 180 / Math.PI
                                return plannerService.altitudeDeg(raH, dec, lat, plannerService.lst(jd, lon))
                            }

                            // UTC time string from hour offset around midnight
                            // Clock label for an hour offset around the reference midnight,
                            // honouring the UTC / local-AM·PM toggle.
                            function toUTC(h) {
                                var t = new Date(midnight.getTime() + h * 3600000)
                                var utcH = t.getUTCHours() + t.getUTCMinutes() / 60.0
                                         + t.getUTCSeconds() / 3600.0
                                return plannerWindow.fmtHHMM(utcH)
                            }

                            // Object altitude / azimuth at an hour offset around midnight
                            function altAt(h) {
                                return plannerService.altitudeDeg(o.raHours, o.decDeg, lat,
                                                                  plannerService.lst(jdMid + h / 24.0, lon))
                            }
                            function azAt(h) {
                                return plannerService.azimuthDeg(o.raHours, o.decDeg, lat,
                                                                 plannerService.lst(jdMid + h / 24.0, lon))
                            }

                            // ── Night window: fixed 18:00–06:00 local time ────────────────
                            // Always centred on local midnight with ±6 hour half-window.
                            var hStart = -6, hEnd = 6
                            var span = hEnd - hStart
                            function xOf(h) { return padL + (h - hStart) / span * plotW }

                            // ── Twilight shading ──────────────────────────────────────────
                            var nSh = Math.max(48, Math.round(plotW / 2))
                            for (var s = 0; s < nSh; s++) {
                                var hA = hStart + span * s / nSh
                                var hB = hStart + span * (s + 1) / nSh
                                var sa = sunAlt(jdMid + (hA + hB) / 2 / 24.0)
                                var col = null
                                if      (sa >= 0)   col = "rgba(160,110,50,0.20)"
                                else if (sa >= -6)  col = "rgba(160,100,40,0.13)"
                                else if (sa >= -12) col = "rgba(60,80,140,0.10)"
                                else if (sa >= -18) col = "rgba(30,50,100,0.07)"
                                if (col) { ctx.fillStyle = col; ctx.fillRect(xOf(hA), 0, xOf(hB) - xOf(hA) + 0.5, cy) }
                            }

                            // ── Viewable-area shading ─────────────────────────────────────
                            // Dim the times the object's azimuth falls outside the sweep, and
                            // the altitude band below the horizon-obstruction floor.
                            if (plannerWindow.viewSectors.indexOf(false) >= 0) {
                                for (var sv = 0; sv < nSh; sv++) {
                                    var hAz = hStart + span * (sv + 0.5) / nSh
                                    if (!plannerWindow.azInSweep(azAt(hAz))) {
                                        ctx.fillStyle = "rgba(150,90,90,0.11)"
                                        ctx.fillRect(xOf(hStart + span * sv / nSh), 0,
                                                     plotW / nSh + 0.5, cy)
                                    }
                                }
                            }
                            if (plannerWindow.viewMinAlt > 15) {
                                var yFloorBand = cy - (plannerWindow.viewMinAlt / 90.0) * rTop
                                ctx.fillStyle = "rgba(150,90,90,0.09)"
                                ctx.fillRect(padL, yFloorBand, plotW, cy - yFloorBand)
                            }

                            // ── Horizon baseline ──────────────────────────────────────────
                            ctx.strokeStyle = pal.mid.toString()
                            ctx.lineWidth = 1; ctx.setLineDash([])
                            ctx.beginPath(); ctx.moveTo(padL, cy); ctx.lineTo(width - padR, cy); ctx.stroke()

                            // ── Altitude grid lines ───────────────────────────────────────
                            ctx.font = "10px sans-serif"
                            ctx.fillStyle = pal.placeholderText.toString()
                            ctx.textAlign = "left"

                            // 15° planning limit
                            var y15 = cy - (15.0 / 90.0) * rTop
                            ctx.strokeStyle = pal.mid.toString()
                            ctx.setLineDash([2, 6]); ctx.lineWidth = 0.5
                            ctx.beginPath(); ctx.moveTo(padL, y15); ctx.lineTo(width - padR, y15); ctx.stroke()
                            ctx.fillText("15°", 2, y15 + 4)

                            for (var alt = 30; alt <= 80; alt += 30) {
                                var ytick = cy - (alt / 90.0) * rTop
                                ctx.setLineDash([2, 4]); ctx.lineWidth = 0.5
                                ctx.strokeStyle = pal.mid.toString()
                                ctx.beginPath(); ctx.moveTo(padL, ytick); ctx.lineTo(width - padR, ytick); ctx.stroke()
                                ctx.fillText(alt + "°", 2, ytick + 4)
                            }
                            ctx.setLineDash([])

                            // ── Viewable min-altitude floor line ──────────────────────────
                            if (plannerWindow.viewMinAlt > 15) {
                                var yFl = cy - (plannerWindow.viewMinAlt / 90.0) * rTop
                                ctx.strokeStyle = "rgba(210,130,130,0.9)"
                                ctx.setLineDash([4, 4]); ctx.lineWidth = 1
                                ctx.beginPath(); ctx.moveTo(padL, yFl); ctx.lineTo(width - padR, yFl); ctx.stroke()
                                ctx.setLineDash([])
                                ctx.fillStyle = pal.placeholderText.toString(); ctx.textAlign = "left"
                                ctx.fillText(plannerWindow.viewMinAlt.toFixed(0) + "°", 2, yFl - 2)
                            }

                            // ── Hourly grid + time axis labels ────────────────────────────
                            ctx.fillStyle = pal.placeholderText.toString()
                            ctx.font = "10px sans-serif"
                            var hStep  = span > 14 ? 2 : 1
                            var firstH = Math.ceil(hStart), lastH = Math.floor(hEnd)
                            for (var hh = firstH; hh <= lastH; hh += hStep) {
                                var hx = xOf(hh)
                                ctx.strokeStyle = pal.mid.toString()
                                ctx.setLineDash([2, 5]); ctx.lineWidth = 0.5
                                ctx.beginPath(); ctx.moveTo(hx, 0); ctx.lineTo(hx, cy); ctx.stroke()
                                ctx.setLineDash([])
                                ctx.textAlign = (hh === firstH) ? "left" : (hh === lastH ? "right" : "center")
                                ctx.fillText(toUTC(hh), hx, cy + 11)
                            }

                            // ── Compass strip: object bearing through the night ───────────
                            ctx.font = "9px sans-serif"
                            ctx.textAlign = "center"
                            for (var hc = firstH; hc <= lastH; hc += hStep) {
                                var altc = altAt(hc)
                                if (altc < 0) continue                 // below horizon — nothing to point at
                                var azc = azAt(hc)
                                ctx.fillStyle = plannerWindow.inView(azc, altc) ? pal.highlight.toString()
                                                                               : pal.placeholderText.toString()
                                ctx.fillText(plannerWindow.compass16(azc), xOf(hc), cy + 24)
                            }

                            // ── Meridian crossing ─────────────────────────────────────────
                            // Transit when HA = 0 → LST = RA; use sidereal rate ≈ 15°/hr
                            var dLST      = ((o.raHours * 15.0 - lstMid) % 360 + 360) % 360
                            if (dLST > 180) dLST -= 360
                            var hTransit   = dLST / 15.0
                            var showTransit = hTransit >= hStart && hTransit <= hEnd
                            var pxTransit  = xOf(hTransit)
                            var altTransit = -999
                            if (showTransit) {
                                altTransit = altAt(hTransit)
                                if (altTransit >= 15) {
                                    ctx.strokeStyle = pal.mid.toString()
                                    ctx.setLineDash([3, 5]); ctx.lineWidth = 1
                                    ctx.beginPath()
                                    ctx.moveTo(pxTransit, 0); ctx.lineTo(pxTransit, cy)
                                    ctx.stroke(); ctx.setLineDash([])
                                }
                            }

                            // ── Object arc (night only, segmented by in-view) ─────────────
                            // Solid highlight where the object is inside the viewable area,
                            // dimmed where its azimuth/altitude falls outside it.
                            var riseX = -1, riseH = 0
                            var setX  = -1, setH  = 0
                            var prevAlt = null, prevPx = null, prevPy = null, prevH = null
                            var nArc = 180
                            var hiCol  = pal.highlight.toString()
                            var dimCol = pal.placeholderText.toString()

                            for (var step = 0; step <= nArc; step++) {
                                var h    = hStart + span * step / nArc
                                var altH = altAt(h)
                                var px   = xOf(h)
                                var py   = cy - (altH / 90.0) * rTop

                                if (prevAlt !== null) {
                                    // rise/set crossings at the 15° planning limit
                                    if (prevAlt < 15.0 && altH >= 15.0) {
                                        var fR = (15.0 - prevAlt) / (altH - prevAlt)
                                        riseX = prevPx + fR * (px - prevPx)
                                        riseH = prevH  + fR * (h - prevH)
                                    } else if (prevAlt >= 15.0 && altH < 15.0) {
                                        var fS = (prevAlt - 15.0) / (prevAlt - altH)
                                        setX = prevPx + fS * (px - prevPx)
                                        setH = prevH  + fS * (h - prevH)
                                    }
                                    // draw the segment only where both ends clear the limit
                                    if (prevAlt >= 15.0 && altH >= 15.0) {
                                        var inv = plannerWindow.inView(azAt(h), altH)
                                        ctx.beginPath()
                                        ctx.moveTo(prevPx, prevPy); ctx.lineTo(px, py)
                                        ctx.strokeStyle = inv ? hiCol : dimCol
                                        ctx.lineWidth   = inv ? 2.5 : 1.3
                                        ctx.stroke()
                                    }
                                }
                                prevAlt = altH; prevPx = px; prevPy = py; prevH = h
                            }

                            // ── Midnight dot ──────────────────────────────────────────────
                            var altMid = altAt(0)
                            if (altMid >= 15.0 && hStart <= 0 && hEnd >= 0) {
                                ctx.fillStyle = plannerWindow.inView(azAt(0), altMid) ? hiCol : dimCol
                                ctx.beginPath()
                                ctx.arc(xOf(0), cy - (altMid / 90.0) * rTop, 4, 0, 2 * Math.PI)
                                ctx.fill()
                            }

                            // ── Transit / peak annotation (with bearing) ──────────────────
                            if (showTransit && altTransit >= 15) {
                                var pyTransit = cy - (altTransit / 90.0) * rTop
                                ctx.font = "10px sans-serif"
                                ctx.fillStyle = pal.placeholderText.toString()
                                ctx.textAlign = "center"
                                ctx.fillText(altTransit.toFixed(0) + "°  ·  " + toUTC(hTransit)
                                             + "  " + plannerWindow.compass16(azAt(hTransit)),
                                             pxTransit, Math.max(pyTransit - 7, 11))
                            }

                            // ── Rise / set annotations (with bearing) ─────────────────────
                            ctx.font = "10px sans-serif"
                            ctx.fillStyle = pal.placeholderText.toString()
                            if (riseX >= 0) {
                                ctx.textAlign = riseX < padL + plotW * 0.2 ? "left" : "center"
                                ctx.fillText("▲ " + toUTC(riseH) + " " + plannerWindow.compass16(azAt(riseH)),
                                             Math.max(riseX, padL), cy - 5)
                            }
                            if (setX >= 0) {
                                ctx.textAlign = setX > padL + plotW * 0.8 ? "right" : "center"
                                ctx.fillText("▼ " + toUTC(setH) + " " + plannerWindow.compass16(azAt(setH)),
                                             Math.min(setX, width - padR), cy - 5)
                            }
                        }
                    }

                    // Placeholder shown in the object area until something is selected.
                    Text {
                        width: parent.width
                        text: "Select an object to see its sky arc and details."
                        color: pal.placeholderText; font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        visible: !plannerWindow.selectedObj
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

                                // parent → right-half Item → Row → outer Column (has obj)
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

                    // ── Viewable-area controls: narrow the planning scope ─────────
                    // Always visible (independent of the selected object), shown below
                    // the light-pollution panel: toggle the compass directions you can
                    // see, set the obstruction floor, and optionally filter the list.
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
                                checked: plannerWindow.viewFilterEnabled
                                onToggled: plannerWindow.viewFilterEnabled = checked
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Button {
                                text: "All sky"
                                flat: true; implicitHeight: parent.parent.fieldH
                                anchors.verticalCenter: parent.verticalCenter
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
