import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: window
    title: "Meridian"
    width: 1100
    height: 1000
    minimumWidth: 800
    minimumHeight: 600
    visible: true

    color: palette.window

    property string selectedDirectory: ""
    property var    fullMetadataList:  []
    property bool   scanCompleted:     false

    property string seestarAutoAddedPath: ""

    menuBar: MenuBar {

        Menu {
            title: "&File"

            Action {
                text: "Add Folder…"
                shortcut: "Ctrl+O"
                onTriggered: {
                    var dir = scanner.selectDirectory()
                    if (dir !== "")
                        window.selectedDirectory = dir
                }
            }
            Action {
                text: "Scan FITS Files"
                shortcut: "Ctrl+Shift+S"
                enabled: scanner.directories.length > 0 && !scanner.running && !organizer.running
                onTriggered: {
                    controlsPanel.setStatus("")
                    scanner.scanDirectories()
                }
            }
            MenuSeparator {}
            Action {
                text: "Stop"
                shortcut: "Ctrl+."
                enabled: scanner.running || organizer.running
                onTriggered: { scanner.cancel(); organizer.cancel() }
            }
            MenuSeparator {}
            Action {
                text: "Exit"
                shortcut: "Ctrl+Q"
                onTriggered: Qt.quit()
            }
        }

        Menu {
            title: "&Tools"

            Action {
                text: "Open Planner…"
                shortcut: "Ctrl+P"
                onTriggered: {
                    plannerWindow.latitude  = weatherService.latitude
                    plannerWindow.longitude = weatherService.longitude
                    plannerWindow.show()
                    plannerWindow.raise()
                }
            }

            MenuSeparator {}

            Menu {
                title: "Advanced Tools"

                Action {
                    id: advancedToolsAction
                    text: "Show Advanced Tools Panel"
                    checkable: true
                    checked: false
                    onTriggered: controlsPanel.advancedVisible = checked
                }
                Connections {
                    target: controlsPanel
                    function onAdvancedVisibleChanged() {
                        advancedToolsAction.checked = controlsPanel.advancedVisible
                    }
                }

                MenuSeparator {}

                Action {
                    text: "Organize Stacked Files"
                    enabled: scanner.directories.length > 0 && !scanner.running && !organizer.running
                    onTriggered: {
                        controlsPanel.advancedVisible = true
                        controlsPanel.logToConsole("Organizing stacked files…")
                        organizer.organizeStacked(scanner.directories)
                    }
                }
                Action {
                    text: "Siril Prep"
                    enabled: scanner.directories.length > 0 && !scanner.running && !organizer.running
                    onTriggered: {
                        controlsPanel.advancedVisible = true
                        controlsPanel.logToConsole("Running Siril prep…")
                        organizer.sirilPrep(scanner.directories)
                    }
                }
                Action {
                    text: "Remove Empty Folders"
                    enabled: scanner.directories.length > 0 && !scanner.running && !organizer.running
                    onTriggered: {
                        controlsPanel.advancedVisible = true
                        controlsPanel.logToConsole("Removing empty folders…")
                        organizer.removeEmptyFolders(scanner.directories)
                    }
                }

                MenuSeparator {}

                Menu {
                    title: "Scan for JPG Files"

                    Action {
                        text: "Scan for JPG Files"
                        enabled: scanner.directories.length > 0 && !scanner.running && !organizer.running
                        onTriggered: {
                            controlsPanel.advancedVisible = true
                            controlsPanel.logToConsole("Scanning for JPG files…")
                            organizer.scanJpg(scanner.directories)
                        }
                    }
                    MenuSeparator {}
                    Action {
                        text: "Delete JPG Files…"
                        enabled: controlsPanel.jpgScanDone && !organizer.running
                        onTriggered: menuDeleteJpgDialog.open()
                    }
                    Action {
                        text: "Clear JPG Results"
                        enabled: controlsPanel.jpgScanDone && !organizer.running
                        onTriggered: controlsPanel.clearJpgData()
                    }
                }
            }
        }

        Menu {
            title: "&View"

            Action {
                text: "Open in Viewer"
                enabled: fileDetailsView.selectedFilePath !== ""
                onTriggered: viewerManager.openFile(fileDetailsView.selectedFilePath)
            }
            Action {
                text: "Reject Selected File"
                enabled: fileDetailsView.selectedFilePath !== ""
                onTriggered: menuRejectFileDialog.open()
            }
            Action {
                text: "Delete Selected File…"
                enabled: fileDetailsView.selectedFilePath !== ""
                onTriggered: menuDeleteFileDialog.open()
            }
        }

        Menu {
            title: "&Help"

            Action {
                text: "About Meridian…"
                onTriggered: aboutDialog.open()
            }
        }
    }

    AboutDialog { id: aboutDialog }

    Dialog {
        id: menuRejectFileDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Reject File"
        standardButtons: Dialog.Ok | Dialog.Cancel

        Column {
            spacing: 10; width: 420
            Text {
                width: parent.width
                text: "Move to the rejected folder:\n" + fileDetailsView.selectedFileName
                color: window.sysPal.windowText
                wrapMode: Text.WordWrap; font.pixelSize: 13
            }
            Text {
                width: parent.width
                text: fileDetailsView.selectedFilePath
                color: window.sysPal.placeholderText
                font.pixelSize: 11; wrapMode: Text.WrapAnywhere
            }
        }

        onAccepted: {
            var path = fileDetailsView.selectedFilePath
            var newPath = organizer.rejectFile(path)
            if (newPath !== "") {
                fileDetailsView.removeRow(path)
                fileDetailsView.selectedFilePath = ""
                fileDetailsView.selectedFileName  = ""
            }
        }
    }

    Dialog {
        id: menuDeleteFileDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Delete File"
        standardButtons: Dialog.Ok | Dialog.Cancel

        Column {
            spacing: 10; width: 420
            Text {
                width: parent.width
                text: "Permanently delete:\n" + fileDetailsView.selectedFileName
                color: window.sysPal.windowText
                wrapMode: Text.WordWrap; font.pixelSize: 13
            }
            Text {
                width: parent.width
                text: fileDetailsView.selectedFilePath
                color: window.sysPal.placeholderText
                font.pixelSize: 11; wrapMode: Text.WrapAnywhere
            }
            Text {
                text: "This action cannot be undone."
                color: "#cc3300"; font.pixelSize: 13; font.bold: true
            }
        }

        onAccepted: {
            var path = fileDetailsView.selectedFilePath
            if (organizer.deleteFile(path)) {
                fileDetailsView.removeRow(path)
                fileDetailsView.selectedFilePath = ""
                fileDetailsView.selectedFileName  = ""
            }
        }
    }

    Dialog {
        id: menuDeleteJpgDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Delete JPG Files"
        standardButtons: Dialog.Ok | Dialog.Cancel

        Column {
            spacing: 10
            width: 380
            Text {
                width: parent.width
                text: "Permanently delete " + controlsPanel.jpgCount +
                      " JPG file(s) from " + scanner.directories.length + " folder(s)."
                color: window.sysPal.windowText
                wrapMode: Text.WordWrap; font.pixelSize: 13
            }
            Text {
                text: "This action cannot be undone."
                color: "#cc3300"; font.pixelSize: 13; font.bold: true
            }
        }

        onAccepted: {
            controlsPanel.logToConsole("Deleting " + controlsPanel.jpgCount + " JPG file(s)…")
            organizer.removeJpg(scanner.directories)
        }
    }

    SystemPalette {
        id: sysPalette
        colorGroup: SystemPalette.Active
    }

    readonly property SystemPalette sysPal: sysPalette

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: scrollView.width
            spacing: 8
            topPadding: 12
            bottomPadding: 16

            ControlsPanel {
                id: controlsPanel
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.margins: 12
                onJpgScanned: function(rows) {
                    fileDetailsView.allRows = rows
                }
                onJpgCleared: {
                    fileDetailsView.allRows = window.fullMetadataList
                    imagingCalendar.activeCatalogFilter = ""
                    imagingCalendar.activeTargetFilter  = ""
                    imagingCalendar.buildCalendar(window.fullMetadataList)
                }
            }
            Rectangle {
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.margins: 12
                height: seestarRow.implicitHeight + 20
                color:        window.sysPal.base
                border.color: window.sysPal.mid
                border.width: 1
                radius: 6

                Row {
                    id: seestarRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left:  parent.left
                    anchors.leftMargin: 16
                    spacing: 24

                    Text {
                        text: "Seestar"
                        font.pixelSize: 13; font.bold: true
                        color: window.sysPal.windowText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Detected:"; font.pixelSize: 12; color: window.sysPal.windowText; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: seestarService.connected ? "Yes" : "No"
                            font.pixelSize: 12
                            color: seestarService.connected ? "#66bb6a" : "#ef5350"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Telescope Files:"; font.pixelSize: 12; color: window.sysPal.windowText; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: !seestarService.connected ? "—"
                                  : seestarService.hasMyWorks ? "Added to scan" : "Not Found"
                            font.pixelSize: 12
                            color: !seestarService.connected   ? window.sysPal.placeholderText
                                   : seestarService.hasMyWorks ? "#66bb6a" : "#ef5350"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Free Space:"; font.pixelSize: 12; color: window.sysPal.windowText; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            readonly property double gb: seestarService.freeBytes / 1073741824
                            text: !seestarService.connected ? "—" : gb.toFixed(1) + " GB"
                            font.pixelSize: 12
                            color: !seestarService.connected ? window.sysPal.placeholderText
                                   : gb >= 32.0             ? "#66bb6a"
                                   : gb >= 12.0             ? "#ffd54f"
                                   :                          "#ef5350"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Item {
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.margins: 12
                height: Math.max(targetSummaryView.implicitHeight,
                                 catalogBreakdown.height + 8 + observedSkyDome.height)

                TargetSummaryView {
                    id: targetSummaryView
                    anchors.top:    parent.top
                    anchors.bottom: parent.bottom
                    anchors.left:   parent.left
                    onTargetSelected: function(name) {
                        catalogBreakdown.selectedTarget     = name
                        imagingCalendar.activeTargetFilter  = name
                        imagingCalendar.activeCatalogFilter = ""
                        imagingCalendar.buildCalendar(window.fullMetadataList)
                        fileDetailsView.filterByTarget(name)
                    }
                }

                CatalogBreakdown {
                    id: catalogBreakdown
                    anchors.top:         parent.top
                    anchors.left:        targetSummaryView.right
                    anchors.leftMargin:  2
                    anchors.right:       parent.right
                    onCatalogSelected: function(name) {
                        catalogBreakdown.selectedTarget     = ""
                        imagingCalendar.activeCatalogFilter = name
                        imagingCalendar.activeTargetFilter  = ""
                        imagingCalendar.buildCalendar(window.fullMetadataList)
                        fileDetailsView.filterByCatalog(name)
                    }
                }

                ObservedSkyDome {
                    id: observedSkyDome
                    anchors.top:        catalogBreakdown.bottom
                    anchors.topMargin:  8
                    anchors.left:       targetSummaryView.right
                    anchors.leftMargin: 2
                    anchors.right:      parent.right
                    metadataList: window.fullMetadataList
                }
            }
            ImagingCalendar {
                id: imagingCalendar
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.margins: 12
            }
            CalibrationSummaryView {
                id: calibrationSummaryView
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.margins: 12
            }
            FileDetailsView {
                id: fileDetailsView
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.margins: 12
                height: 500
                onShowAllRequested: {
                    catalogBreakdown.selectedTarget     = ""
                    imagingCalendar.activeCatalogFilter = ""
                    imagingCalendar.activeTargetFilter  = ""
                    imagingCalendar.buildCalendar(window.fullMetadataList)
                }
                onFileOpenRequested: function(path, name) {
                    viewerManager.openFile(path)
                }
            }
        }
    }

    PlannerWindow {
        id: plannerWindow
        visible: false
    }

    FitsViewerManager {
        id: viewerManager
        transientParent:    window
        displayRows:        fileDetailsView.displayRows
        onRemoveRowRequested: function(path) { fileDetailsView.removeRow(path) }
    }

    Component.onCompleted: {
        if (seestarService.hasMyWorks) {
            var myWorksPath = seestarService.mountPath + "/MyWorks"
            if (scanner.directories.indexOf(myWorksPath) === -1) {
                scanner.addDirectory(myWorksPath)
                window.seestarAutoAddedPath = myWorksPath
            }
        }
    }

    Connections {
        target: seestarService
        function onConnectedChanged() {
            var myWorksPath = seestarService.mountPath + "/MyWorks"
            if (seestarService.hasMyWorks) {
                if (scanner.directories.indexOf(myWorksPath) === -1) {
                    scanner.addDirectory(myWorksPath)
                    window.seestarAutoAddedPath = myWorksPath
                }
            } else {
                var idx = scanner.directories.indexOf(window.seestarAutoAddedPath)
                if (idx !== -1)
                    scanner.removeDirectory(idx)
                window.seestarAutoAddedPath = ""
            }
        }
    }

    Connections {
        target: scanner
        function onScanCompleted(metaList, targetList, calList) {
            window.fullMetadataList = metaList
            window.scanCompleted    = true
            controlsPanel.setStatus("Found " + metaList.length + " FITS files.")
            fileDetailsView.allRows = metaList
            imagingCalendar.buildCalendar(metaList)
        }
        function onScanError(error) {
            controlsPanel.setStatus("Scan error: " + error)
        }
    }
}
