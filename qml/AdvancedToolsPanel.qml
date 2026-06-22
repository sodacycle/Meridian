import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    height: outerCol.height + 32
    color:        window.sysPal.alternateBase
    border.color: window.sysPal.mid
    border.width: 1
    radius: 6

    property var    directories: []
    property bool   scanReady:   false
    property bool   jpgScanDone: false
    property int    jpgCount: 0

    property string consoleLog: ""

    signal jpgScanned(var rows)
    signal jpgCleared()

    function clearJpgData() {
        jpgScanDone = false
        jpgCount    = 0
        log("JPG data cleared.")
        jpgCleared()
    }

    function log(msg) {
        consoleLog += (consoleLog !== "" ? "\n" : "") + msg
        Qt.callLater(function() {
            consoleFlick.contentY = Math.max(0, consoleFlick.contentHeight - consoleFlick.height)
        })
    }

    Column {
        id: outerCol
        anchors.top:     parent.top
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.margins: 16
        spacing: 12

        Text {
            text: "Advanced Tools"
            font.pixelSize: 16; font.bold: true
            color: window.sysPal.windowText; width: parent.width
        }

        Row {
            id: mainRow
            width: parent.width
            spacing: 12

            readonly property int btnW: 196
            readonly property int leftW: btnW * 2 + 8

            Column {
                id: leftCol
                width: mainRow.leftW
                spacing: 8

                Grid {
                    columns: 2
                    columnSpacing: 8
                    rowSpacing:    8

                    Button {
                        width: mainRow.btnW
                        text: "Organize Stacked Files"
                        enabled: root.scanReady && root.directories.length > 0 && !organizer.running
                        ToolTip.visible: hovered; ToolTip.delay: 500
                        ToolTip.text: "Move stacked FITS files (detected by header keywords\nor filename prefix) into a 'Stacked' subfolder."
                        onClicked: {
                            root.log("Organizing stacked files…")
                            organizer.organizeStacked(root.directories)
                        }
                    }
                    Button {
                        width: mainRow.btnW
                        text: "Scan for .jpg Files"
                        enabled: root.scanReady && root.directories.length > 0 && !organizer.running
                        ToolTip.visible: hovered; ToolTip.delay: 500
                        ToolTip.text: "Search for JPG files in all scan folders.\nResults load into the File Details table below."
                        onClicked: {
                            root.log("Scanning for JPG files…")
                            organizer.scanJpg(root.directories)
                        }
                    }
                    Button {
                        width: mainRow.btnW
                        text: "Siril Prep"
                        enabled: root.scanReady && root.directories.length > 0 && !organizer.running
                        ToolTip.visible: hovered; ToolTip.delay: 500
                        ToolTip.text: "Rename and arrange FITS files into the folder\nstructure expected by Siril for preprocessing."
                        onClicked: {
                            root.log("Running Siril prep…")
                            organizer.sirilPrep(root.directories)
                        }
                    }
                    Button {
                        width: mainRow.btnW
                        text: "Remove Empty Folders"
                        enabled: root.scanReady && root.directories.length > 0 && !organizer.running
                        ToolTip.visible: hovered; ToolTip.delay: 500
                        ToolTip.text: "Delete any empty folders found within all\nscan directory trees."
                        onClicked: {
                            root.log("Removing empty folders…")
                            organizer.removeEmptyFolders(root.directories)
                        }
                    }
                }

                Row {
                    spacing: 8
                    visible: root.jpgScanDone

                    Text {
                        text: root.jpgCount + " JPG file(s) found —"
                        color: window.sysPal.windowText; font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Button {
                        text: "Delete JPG Files"
                        enabled: !organizer.running
                        ToolTip.visible: hovered; ToolTip.delay: 500
                        ToolTip.text: "Permanently delete all " + root.jpgCount + " JPG file(s).\nA confirmation prompt will appear first."
                        onClicked: confirmDeleteDialog.open()
                    }
                    Button {
                        text: "Clear JPG Data"
                        enabled: !organizer.running
                        ToolTip.visible: hovered; ToolTip.delay: 500
                        ToolTip.text: "Clear JPG results and restore FITS file data."
                        onClicked: {
                            root.jpgScanDone = false
                            root.jpgCount    = 0
                            root.log("JPG data cleared.")
                            root.jpgCleared()
                        }
                    }
                }
            }

            Rectangle {
                id: consolePanel
                width:  mainRow.width - mainRow.leftW - mainRow.spacing
                height: 200
                color:  "#111318"
                radius: 4
                border.color: "#2a2d3a"
                border.width: 1

                Rectangle {
                    id: consoleHeader
                    anchors.top:   parent.top
                    anchors.left:  parent.left
                    anchors.right: parent.right
                    height: 26
                    color:  "#1c1f2b"
                    radius: 4

                    Rectangle {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                        height: parent.radius
                        color:  parent.color
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 10
                        text: "Console"
                        color: "#6a7090"; font.pixelSize: 11; font.bold: true
                    }

                    Button {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 6
                        text: "Clear"
                        implicitHeight: 20; implicitWidth: 46
                        ToolTip.visible: hovered; ToolTip.delay: 500
                        ToolTip.text: "Clear the console log"
                        onClicked: root.consoleLog = ""
                    }
                }

                Flickable {
                    id: consoleFlick
                    anchors.top:    consoleHeader.bottom
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 6
                    clip: true
                    contentWidth:  width
                    contentHeight: Math.max(height, consoleText.implicitHeight)

                    Text {
                        id: consoleText
                        width: consoleFlick.width
                        text: root.consoleLog !== "" ? root.consoleLog
                                                     : "Ready — click an action to begin."
                        color: root.consoleLog !== "" ? "#a8d8a8" : "#3a3f55"
                        font.pixelSize: 12; font.family: "monospace"
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }
                }
            }
        }

        Item { width: 1; height: 4 }
    }

    Dialog {
        id: confirmDeleteDialog
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
                text: "Permanently delete " + root.jpgCount + " JPG file(s) from " + root.directories.length + " folder(s)."
                color: window.sysPal.windowText
                wrapMode: Text.WordWrap; font.pixelSize: 13
            }
            Text {
                text: "This action cannot be undone."
                color: "#cc3300"; font.pixelSize: 13; font.bold: true
            }
        }

        onAccepted: {
            root.log("Deleting " + root.jpgCount + " JPG file(s)…")
            organizer.removeJpg(root.directories)
        }
    }

    Connections {
        target: organizer

        function onFileProcessed(message) { root.log(message) }

        function onOperationCompleted(result) {
            var msg = result.message || ""
            if (msg !== "") root.log(msg)

            if (result.operation === "scanJpg") {
                var rows  = result.jpgFiles || []
                var count = rows.length || 0
                root.jpgCount    = count
                root.jpgScanDone = count > 0
                if (count === 0) {
                    root.log("No JPG files found.")
                } else {
                    root.log("Found " + count + " JPG file(s).")
                    root.jpgScanned(rows)
                }
            }

            if (result.operation === "removeJpg") {
                root.jpgScanDone = false
                root.jpgCount    = 0
                root.jpgCleared()
            }
        }

        function onOperationError(error) {
            root.log("Error: " + error)
        }
    }
}
