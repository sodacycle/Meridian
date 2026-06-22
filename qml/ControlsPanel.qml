import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Rectangle {
    id: root
    height: col.height + 32
    color:        window.sysPal.base
    border.color: window.sysPal.mid
    border.width: 1
    radius: 6

    signal jpgScanned(var rows)
    signal jpgCleared()

    property alias advancedVisible: advancedPanel.visible
    property alias jpgScanDone:     advancedPanel.jpgScanDone
    property alias jpgCount:        advancedPanel.jpgCount

    function logToConsole(msg) { advancedPanel.log(msg) }
    function clearJpgData()    { advancedPanel.clearJpgData() }

    function setStatus(msg) { statusText.text = msg }

    Column {
        id: col
        anchors.top:     parent.top
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.margins: 16
        spacing: 12

        Text {
            text: "Meridian"
            font.pixelSize: 28; font.bold: true
            color: window.sysPal.windowText
            width: parent.width
        }
        Text {
            text: "Add one or more folders containing .fit files; all subdirectories are scanned automatically."
            color: window.sysPal.placeholderText
            font.pixelSize: 14
            wrapMode: Text.WordWrap; width: parent.width
        }
        Row {
            spacing: 8
            Button {
                text: "Add Folder"
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Add a folder to the scan list.\nSubdirectories are scanned automatically."
                onClicked: {
                    var dir = scanner.selectDirectory()
                    if (dir !== "")
                        window.selectedDirectory = dir
                }
            }
            Button {
                text: "Scan FIT"
                enabled: scanner.directories.length > 0 && !scanner.running
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Scan all added folders for FITS files\nand build metadata summaries."
                onClicked: {
                    statusText.text = ""
                    scanner.scanDirectories()
                }
            }
            Button {
                text: "Stop"
                enabled: scanner.running || organizer.running
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Cancel the current scan or file operation."
                onClicked: { scanner.cancel(); organizer.cancel() }
            }
            Button {
                text: advancedPanel.visible ? "Hide Advanced Tools" : "Advanced Tools"
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Show or hide file organisation tools such as\nSiril prep, stacked file sorting, and cleanup."
                onClicked: advancedPanel.visible = !advancedPanel.visible
            }
            Button {
                text: "Open Planner"
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Open the Observation Planner to plan your\nnext imaging session."
                onClicked: {
                    plannerWindow.latitude  = weatherService.latitude
                    plannerWindow.longitude = weatherService.longitude
                    plannerWindow.show()
                    plannerWindow.raise()
                }
            }
        }

        Column {
            id: dirList
            width: parent.width
            spacing: 4
            visible: scanner.directories.length > 0

            Repeater {
                model: scanner.directories
                delegate: Rectangle {
                    width: dirList.width
                    height: 28
                    color: index % 2 === 0 ? window.sysPal.alternateBase : "transparent"
                    radius: 3

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 4
                        spacing: 4

                        Text {
                            text: "▸"
                            color: window.sysPal.highlight
                            font.pixelSize: 11
                        }
                        Text {
                            text: modelData
                            color: window.sysPal.windowText
                            font.pixelSize: 12
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                        BusyIndicator {
                            implicitWidth: 20
                            implicitHeight: 20
                            running: scanner.running && scanner.currentScanDirectory === modelData
                            visible: running
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Button {
                            text: "✕"
                            flat: true
                            font.pixelSize: 11
                            implicitWidth: 24
                            implicitHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            ToolTip.visible: hovered
                            ToolTip.delay: 500
                            ToolTip.text: "Remove this folder from the scan list."
                            onClicked: scanner.removeDirectory(index)
                        }
                    }
                }
            }
        }

        Text {
            id: statusText
            text: ""
            color: window.sysPal.placeholderText; font.pixelSize: 13
            visible: text !== ""; width: parent.width
            wrapMode: Text.WordWrap
        }
        ProgressIndicator {
            width: parent.width
            visible: scanner.running || organizer.running
            scannerRunning:   scanner.running
            organizerRunning: organizer.running
        }
        AdvancedToolsPanel {
            id: advancedPanel
            width: parent.width
            visible:   false
            directories: scanner.directories
            scanReady: window.scanCompleted
            onJpgScanned: function(rows) { root.jpgScanned(rows) }
            onJpgCleared: root.jpgCleared()
        }
    }
}
