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

    function openSkyArcDetailed() {
        skyArcDetailedWindow.latitude    = plannerWindow.latitude
        skyArcDetailedWindow.longitude   = plannerWindow.longitude
        skyArcDetailedWindow.nightOffset = plannerWindow.nightOffset
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

    property int calendarYear:  (new Date()).getFullYear()
    property int calendarMonth: (new Date()).getMonth() + 1

    property string calendarDensity: "Normal"
    readonly property int calDensityIndex: calendarDensity === "Compact" ? 0 : (calendarDensity === "Detailed" ? 2 : 1)
    readonly property int calBaseRowH: [34, 42, 54][calDensityIndex]
    readonly property int calPerObjH:  [11, 13, 15][calDensityIndex]
    readonly property int calMaxObjs:  [3, 5, 8][calDensityIndex]

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

        Rectangle {
            id: obsBar
            anchors { left: parent.left; right: parent.right; bottom: calSection.top }
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
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: calTopBorder.height + calNav.height + calDayNames.height + calGrid.totalHeight

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
                    onClicked: {
                        if (plannerWindow.calendarMonth === 1) {
                            plannerWindow.calendarMonth = 12; plannerWindow.calendarYear--
                        } else {
                            plannerWindow.calendarMonth--
                        }
                    }
                }
                Text {
                    width: parent.width - 64 - calDensityCombo.width
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
                ComboBox {
                    id: calDensityCombo
                    model: ["Compact", "Normal", "Detailed"]
                    currentIndex: 1
                    font.pixelSize: 10; implicitWidth: 100; implicitHeight: 26
                    anchors.verticalCenter: parent.verticalCenter
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: "Balance how many scheduled targets are shown\nper night against calendar readability."
                    onActivated: plannerWindow.calendarDensity = currentText
                }
            }

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

            Item {
                id: calGrid
                anchors { top: calDayNames.bottom; left: parent.left; right: parent.right }
                height: totalHeight
                clip: true

                readonly property real cellW: width / 7
                readonly property int numWeeks: plannerWindow.weeksInMonth(plannerWindow.calendarYear, plannerWindow.calendarMonth)

                readonly property var rowHeights: {
                    var _sr          = plannerWindow.scheduleRevision
                    var year         = plannerWindow.calendarYear
                    var month        = plannerWindow.calendarMonth
                    var numWeeks     = plannerWindow.weeksInMonth(year, month)
                    var firstWeekday = plannerWindow.firstWeekdayOfMonth(year, month)
                    var daysInMonth  = plannerWindow.daysInMonth(year, month)
                    var heights = []
                    for (var week = 0; week < numWeeks; week++) {
                        var maxScheduled = 0
                        for (var weekday = 0; weekday < 7; weekday++) {
                            var dayNum = week * 7 + weekday - firstWeekday + 1
                            if (dayNum >= 1 && dayNum <= daysInMonth) {
                                var dateStr = year + "-" + (month < 10 ? "0" : "") + month
                                                   + "-" + (dayNum < 10 ? "0" : "") + dayNum
                                var count = schedulerService.countForDate(dateStr)
                                if (count > maxScheduled) maxScheduled = count
                            }
                        }
                        heights.push(plannerWindow.calBaseRowH
                                     + Math.min(maxScheduled, plannerWindow.calMaxObjs) * plannerWindow.calPerObjH)
                    }
                    return heights
                }

                readonly property var rowOffsets: {
                    var heights = rowHeights; var offsets = [0]
                    for (var i = 0; i < heights.length; i++) offsets.push(offsets[i] + heights[i])
                    return offsets
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

                            Text {
                                id: cellDayNum
                                anchors { top: parent.top; left: parent.left }
                                text: dayNum; font.pixelSize: 11
                                font.bold: isToday || isSelected
                                color: isSelected ? pal.highlightedText : pal.windowText
                            }

                            Text {
                                anchors { top: parent.top; right: parent.right }
                                text: {
                                    if (!isValid) return ""
                                    var d = new Date(cy, cm - 1, dayNum); d.setHours(0, 0, 0, 0)
                                    return weatherService.getMoonPhase(d)
                                }
                                font.pixelSize: 12
                            }

                            Column {
                                anchors { top: cellDayNum.bottom; topMargin: 1; left: parent.left; right: parent.right }
                                spacing: 0

                                Repeater {
                                    model: {
                                        var _ = plannerWindow.scheduleRevision
                                        if (!isValid) return []
                                        var objs = schedulerService.objectsForDate(dateStr)
                                        var cap = plannerWindow.calMaxObjs
                                        return objs.length > cap ? objs.slice(0, cap - 1) : objs
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
                                        var extra = schedulerService.countForDate(dateStr) - (plannerWindow.calMaxObjs - 1)
                                        return extra > 0 ? "+" + extra + " more" : ""
                                    }
                                    font.pixelSize: 10; font.italic: true
                                    color: isSelected ? pal.highlightedText : pal.placeholderText
                                    visible: text !== ""
                                }
                            }

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

        Item {
            id: topSection
            anchors { top: manualEntryBar.bottom; left: parent.left; right: parent.right; bottom: obsBar.top }

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

            Rectangle {
                id: divider
                anchors { top: parent.top; bottom: parent.bottom; left: listPanel.right }
                width: 1; color: pal.mid
            }

            Item {
                anchors { top: parent.top; left: divider.right; right: parent.right; bottom: parent.bottom }
                clip: true

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
                            text: "Sky Arc  —  " + plannerWindow.nightLabel()
                            font.pixelSize: 12; color: pal.placeholderText
                        }

                        Button {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: "Detailed View  ⤢"
                            flat: true
                            implicitHeight: 24
                            onClicked: plannerWindow.openSkyArcDetailed()
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
                            var compassStripH = 13
                            var horizonY = height - 16 - compassStripH
                            var altScale = horizonY - 4
                            var plotW = Math.max(1, width - padL - padR)

                            var midnight = plannerWindow.localMidnightUTC()
                            var jdMid    = plannerService.toJD(midnight.getTime())
                            var lstMid   = plannerService.lst(jdMid, lon)

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

                            function clockAt(h) {
                                var t = new Date(midnight.getTime() + h * 3600000)
                                var utcH = t.getUTCHours() + t.getUTCMinutes() / 60.0
                                         + t.getUTCSeconds() / 3600.0
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
                            function yForAlt(alt) { return horizonY - (alt / 90.0) * altScale }

                            var hStart = -6, hEnd = 6
                            var span = hEnd - hStart
                            function xOf(h) { return padL + (h - hStart) / span * plotW }

                            var shadeSteps = Math.max(48, Math.round(plotW / 2))
                            for (var i = 0; i < shadeSteps; i++) {
                                var segStartH = hStart + span * i / shadeSteps
                                var segEndH   = hStart + span * (i + 1) / shadeSteps
                                var sa = sunAlt(jdMid + (segStartH + segEndH) / 2 / 24.0)
                                var twilightColor = null
                                if      (sa >= 0)   twilightColor = "rgba(160,110,50,0.20)"
                                else if (sa >= -6)  twilightColor = "rgba(160,100,40,0.13)"
                                else if (sa >= -12) twilightColor = "rgba(60,80,140,0.10)"
                                else if (sa >= -18) twilightColor = "rgba(30,50,100,0.07)"
                                if (twilightColor) {
                                    ctx.fillStyle = twilightColor
                                    ctx.fillRect(xOf(segStartH), 0, xOf(segEndH) - xOf(segStartH) + 0.5, horizonY)
                                }
                            }

                            if (plannerWindow.viewSectors.indexOf(false) >= 0) {
                                for (var j = 0; j < shadeSteps; j++) {
                                    var sampleH = hStart + span * (j + 0.5) / shadeSteps
                                    if (!plannerWindow.azInSweep(azAt(sampleH))) {
                                        ctx.fillStyle = "rgba(150,90,90,0.11)"
                                        ctx.fillRect(xOf(hStart + span * j / shadeSteps), 0,
                                                     plotW / shadeSteps + 0.5, horizonY)
                                    }
                                }
                            }
                            if (plannerWindow.viewMinAlt > 15) {
                                var floorBandY = yForAlt(plannerWindow.viewMinAlt)
                                ctx.fillStyle = "rgba(150,90,90,0.09)"
                                ctx.fillRect(padL, floorBandY, plotW, horizonY - floorBandY)
                            }

                            ctx.strokeStyle = pal.mid.toString()
                            ctx.lineWidth = 1; ctx.setLineDash([])
                            ctx.beginPath(); ctx.moveTo(padL, horizonY); ctx.lineTo(width - padR, horizonY); ctx.stroke()

                            ctx.font = "10px sans-serif"
                            ctx.fillStyle = pal.placeholderText.toString()
                            ctx.textAlign = "left"

                            var planningLimitY = yForAlt(15.0)
                            ctx.strokeStyle = pal.mid.toString()
                            ctx.setLineDash([2, 6]); ctx.lineWidth = 0.5
                            ctx.beginPath(); ctx.moveTo(padL, planningLimitY); ctx.lineTo(width - padR, planningLimitY); ctx.stroke()
                            ctx.fillText("15°", 2, planningLimitY + 4)

                            for (var gridAlt = 30; gridAlt <= 80; gridAlt += 30) {
                                var gridY = yForAlt(gridAlt)
                                ctx.setLineDash([2, 4]); ctx.lineWidth = 0.5
                                ctx.strokeStyle = pal.mid.toString()
                                ctx.beginPath(); ctx.moveTo(padL, gridY); ctx.lineTo(width - padR, gridY); ctx.stroke()
                                ctx.fillText(gridAlt + "°", 2, gridY + 4)
                            }
                            ctx.setLineDash([])

                            if (plannerWindow.viewMinAlt > 15) {
                                var floorLineY = yForAlt(plannerWindow.viewMinAlt)
                                ctx.strokeStyle = "rgba(210,130,130,0.9)"
                                ctx.setLineDash([4, 4]); ctx.lineWidth = 1
                                ctx.beginPath(); ctx.moveTo(padL, floorLineY); ctx.lineTo(width - padR, floorLineY); ctx.stroke()
                                ctx.setLineDash([])
                                ctx.fillStyle = pal.placeholderText.toString(); ctx.textAlign = "left"
                                ctx.fillText(plannerWindow.viewMinAlt.toFixed(0) + "°", 2, floorLineY - 2)
                            }

                            ctx.fillStyle = pal.placeholderText.toString()
                            ctx.font = "10px sans-serif"
                            var hourStep = span > 14 ? 2 : 1
                            var firstHour = Math.ceil(hStart), lastHour = Math.floor(hEnd)
                            for (var labelH = firstHour; labelH <= lastHour; labelH += hourStep) {
                                var labelX = xOf(labelH)
                                ctx.strokeStyle = pal.mid.toString()
                                ctx.setLineDash([2, 5]); ctx.lineWidth = 0.5
                                ctx.beginPath(); ctx.moveTo(labelX, 0); ctx.lineTo(labelX, horizonY); ctx.stroke()
                                ctx.setLineDash([])
                                ctx.textAlign = (labelH === firstHour) ? "left" : (labelH === lastHour ? "right" : "center")
                                ctx.fillText(clockAt(labelH), labelX, horizonY + 11)
                            }

                            ctx.font = "9px sans-serif"
                            ctx.textAlign = "center"
                            for (var compassH = firstHour; compassH <= lastHour; compassH += hourStep) {
                                var compassAlt = altAt(compassH)
                                if (compassAlt < 0) continue
                                var compassAz = azAt(compassH)
                                ctx.fillStyle = plannerWindow.inView(compassAz, compassAlt) ? pal.highlight.toString()
                                                                                            : pal.placeholderText.toString()
                                ctx.fillText(plannerWindow.compass16(compassAz), xOf(compassH), horizonY + 24)
                            }

                            var lstToTransit = ((o.raHours * 15.0 - lstMid) % 360 + 360) % 360
                            if (lstToTransit > 180) lstToTransit -= 360
                            var transitH    = lstToTransit / 15.0
                            var showTransit = transitH >= hStart && transitH <= hEnd
                            var transitX    = xOf(transitH)
                            var transitAlt  = -999
                            if (showTransit) {
                                transitAlt = altAt(transitH)
                                if (transitAlt >= 15) {
                                    ctx.strokeStyle = pal.mid.toString()
                                    ctx.setLineDash([3, 5]); ctx.lineWidth = 1
                                    ctx.beginPath()
                                    ctx.moveTo(transitX, 0); ctx.lineTo(transitX, horizonY)
                                    ctx.stroke(); ctx.setLineDash([])
                                }
                            }

                            var riseX = -1, riseH = 0
                            var setX  = -1, setH  = 0
                            var prevAlt = null, prevX = null, prevY = null, prevH = null
                            var arcSteps = 180
                            var inViewColor    = pal.highlight.toString()
                            var outOfViewColor = pal.placeholderText.toString()

                            for (var step = 0; step <= arcSteps; step++) {
                                var h   = hStart + span * step / arcSteps
                                var alt = altAt(h)
                                var x   = xOf(h)
                                var y   = yForAlt(alt)

                                if (prevAlt !== null) {
                                    if (prevAlt < 15.0 && alt >= 15.0) {
                                        var riseFrac = (15.0 - prevAlt) / (alt - prevAlt)
                                        riseX = prevX + riseFrac * (x - prevX)
                                        riseH = prevH + riseFrac * (h - prevH)
                                    } else if (prevAlt >= 15.0 && alt < 15.0) {
                                        var setFrac = (prevAlt - 15.0) / (prevAlt - alt)
                                        setX = prevX + setFrac * (x - prevX)
                                        setH = prevH + setFrac * (h - prevH)
                                    }
                                    if (prevAlt >= 15.0 && alt >= 15.0) {
                                        var segInView = plannerWindow.inView(azAt(h), alt)
                                        ctx.beginPath()
                                        ctx.moveTo(prevX, prevY); ctx.lineTo(x, y)
                                        ctx.strokeStyle = segInView ? inViewColor : outOfViewColor
                                        ctx.lineWidth   = segInView ? 2.5 : 1.3
                                        ctx.stroke()
                                    }
                                }
                                prevAlt = alt; prevX = x; prevY = y; prevH = h
                            }

                            var midnightAlt = altAt(0)
                            if (midnightAlt >= 15.0 && hStart <= 0 && hEnd >= 0) {
                                ctx.fillStyle = plannerWindow.inView(azAt(0), midnightAlt) ? inViewColor : outOfViewColor
                                ctx.beginPath()
                                ctx.arc(xOf(0), yForAlt(midnightAlt), 4, 0, 2 * Math.PI)
                                ctx.fill()
                            }

                            if (showTransit && transitAlt >= 15) {
                                var transitLabelY = yForAlt(transitAlt)
                                ctx.font = "10px sans-serif"
                                ctx.fillStyle = pal.placeholderText.toString()
                                ctx.textAlign = "center"
                                ctx.fillText(transitAlt.toFixed(0) + "°  ·  " + clockAt(transitH)
                                             + "  " + plannerWindow.compass16(azAt(transitH)),
                                             transitX, Math.max(transitLabelY - 7, 11))
                            }

                            ctx.font = "10px sans-serif"
                            ctx.fillStyle = pal.placeholderText.toString()
                            if (riseX >= 0) {
                                ctx.textAlign = riseX < padL + plotW * 0.2 ? "left" : "center"
                                ctx.fillText("▲ " + clockAt(riseH) + " " + plannerWindow.compass16(azAt(riseH)),
                                             Math.max(riseX, padL), horizonY - 5)
                            }
                            if (setX >= 0) {
                                ctx.textAlign = setX > padL + plotW * 0.8 ? "right" : "center"
                                ctx.fillText("▼ " + clockAt(setH) + " " + plannerWindow.compass16(azAt(setH)),
                                             Math.min(setX, width - padR), horizonY - 5)
                            }
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

    SkyArcDetailedWindow {
        id: skyArcDetailedWindow
        visible: false
    }
}
