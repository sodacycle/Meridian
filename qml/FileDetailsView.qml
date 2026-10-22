import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    color:        window.sysPal.base
    border.color: window.sysPal.mid
    border.width: 1
    radius: 6

    property bool   jpgMode: false
    property var    jpgRows: []
    property bool   filtered: false
    property string sortCol: ""
    property bool   sortAsc: true

    property string selectedFilePath: ""
    property string selectedFileName: ""

    signal showAllRequested()
    signal fileOpenRequested(string path, string name)

    function applyCurrentSort() {
        if (!sortCol) return
        if (jpgMode) {
            var col = sortCol, asc = sortAsc
            var rows = jpgRows.slice()
            rows.sort(function(a, b) {
                var va = (a[col] !== undefined && a[col] !== null) ? a[col] : ""
                var vb = (b[col] !== undefined && b[col] !== null) ? b[col] : ""
                var na = parseFloat(va), nb = parseFloat(vb)
                var less = (!isNaN(na) && !isNaN(nb)) ? na < nb : String(va).localeCompare(String(vb)) < 0
                return asc ? (less ? -1 : 1) : (less ? 1 : -1)
            })
            jpgRows = rows
        } else {
            metadataModel.sortByColumn(sortCol, sortAsc)
        }
    }

    function headerClicked(col) {
        if (sortCol === col) sortAsc = !sortAsc
        else { sortCol = col; sortAsc = true }
        applyCurrentSort()
    }

    property var allColumns: [
        "Frame Type","File","Target","Start Time UTC","End Time UTC",
        "Exposure Time s","Number of Subs","Total Exposure Time s",
        "Telescope","Camera Model","Sensor Temperature C","RA","DEC",
        "Latitude","Longitude","Binning","Filter Used","Gain",
        "Focal Length mm","Aperture mm","Focus Position","Image Type","Stacking Software"
    ]
    property var colW: [100,200,150,180,180,110,110,140,150,150,130,100,100,100,100,80,120,80,120,100,120,100,150]
    property int totalW: { var w=0; for(var i=0;i<colW.length;i++) w+=colW[i]; return w }

    property int displayCount: jpgMode ? jpgRows.length : metadataModel.count

    function setJpgRows(rows) {
        jpgMode = true
        jpgRows = rows
        filtered = false
        showAllBtn.visible = false
        selectedFilePath = ""
        selectedFileName  = ""
        applyCurrentSort()
    }

    function showFits() {
        jpgMode = false
        jpgRows = []
        filtered = false
        showAllBtn.visible = false
    }

    function removeRow(path) {
        if (jpgMode)
            jpgRows = jpgRows.filter(function(r) { return r["Path"] !== path })
        else
            metadataModel.removeByPath(path)
    }

    function filterByCatalog(catalog) {
        jpgMode = false
        metadataModel.filterByCatalog(catalog)
        filtered = true; showAllBtn.visible = true
    }

    function filterByTarget(target) {
        jpgMode = false
        metadataModel.filterByTarget(target)
        filtered = true; showAllBtn.visible = true
    }

    function filterByTargetAndDate(target, date) {
        jpgMode = false
        metadataModel.filterByTargetAndDate(target, date)
        filtered = true; showAllBtn.visible = true
    }

    function showAll() {
        jpgMode = false
        metadataModel.showAll()
        filtered = false; showAllBtn.visible = false
        showAllRequested()
    }

    Column {
        anchors.fill: parent; anchors.margins: 16; spacing: 10

        Row {
            width: parent.width; height: 36; spacing: 8
            Text {
                text: "File-Level Details"
                font.pixelSize: 20; font.bold: true
                color: window.sysPal.windowText
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - showAllBtn.width - 8
            }
            Button {
                id: showAllBtn; text: "Show All"; visible: false
                anchors.verticalCenter: parent.verticalCenter
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Clear the active filter and show\nall scanned FITS files."
                onClicked: root.showAll()
            }
        }

        Item {
            width: parent.width
            height: parent.height - 46

            ScrollBar {
                id: hBar
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                orientation: Qt.Horizontal; policy: ScrollBar.AsNeeded
                size: Math.min(1.0, parent.width / root.totalW)
            }

            Item {
                id: pane
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.bottom: hBar.top
                clip: true
                property real hOffset: hBar.position * root.totalW

                Row {
                    x: -pane.hOffset; y: 0; spacing: 0; z: 2; height: 32
                    Repeater {
                        model: root.allColumns
                        Rectangle {
                            required property string modelData
                            required property int    index
                            width: root.colW[index]; height: 32
                            color: root.sortCol === modelData
                                   ? Qt.rgba(window.sysPal.highlight.r, window.sysPal.highlight.g,
                                             window.sysPal.highlight.b, 0.22)
                                   : window.sysPal.alternateBase
                            Row {
                                anchors { fill: parent; leftMargin: 6 }
                                spacing: 3
                                Text {
                                    text: modelData
                                    color: root.sortCol === modelData
                                           ? window.sysPal.highlight : window.sysPal.windowText
                                    font.pixelSize: 11; font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: root.sortAsc ? "▲" : "▼"
                                    color: window.sysPal.highlight
                                    font.pixelSize: 9
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                    visible: root.sortCol === modelData
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.headerClicked(modelData)
                            }
                        }
                    }
                }

                ListView {
                    id: detailsList
                    anchors { left: parent.left; right: parent.right
                              top: parent.top; topMargin: 32; bottom: parent.bottom }
                    clip: true
                    model: root.jpgMode ? root.jpgRows : metadataModel
                    reuseItems: true
                    cacheBuffer: 240
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Keys.onReturnPressed: {
                        if (currentIndex >= 0 && currentItem) {
                            var p = currentItem.rowObj["Path"] || ""
                            var n = currentItem.rowObj["File"] || ""
                            root.selectedFilePath = p
                            root.selectedFileName  = n
                            if (p !== "") root.fileOpenRequested(p, n)
                        }
                    }
                    Keys.onEnterPressed: Keys.returnPressed(event)

                    delegate: Item {
                        id: rowItem
                        required property var modelData
                        required property int index
                        readonly property var rowObj: modelData
                        width: detailsList.width; height: 30

                        readonly property bool isSelected: (rowObj["Path"] || "") === root.selectedFilePath
                        readonly property bool isCurrent:  ListView.isCurrentItem

                        Rectangle {
                            x: -pane.hOffset; width: root.totalW; height: parent.height
                            color: (rowItem.isSelected || rowItem.isCurrent)
                                   ? window.sysPal.highlight
                                   : (rowMouse.containsMouse ? window.sysPal.highlight
                                                             : (rowItem.index % 2 === 0 ? window.sysPal.alternateBase : "transparent"))
                            radius: 2
                        }
                        Row {
                            x: -pane.hOffset; y: 0; spacing: 0; height: parent.height
                            Repeater {
                                model: root.allColumns.length
                                Item {
                                    required property int index
                                    property string colKey: root.allColumns[index]
                                    width: root.colW[index]; height: 30
                                    Text {
                                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 4
                                        text: { var v = rowItem.rowObj[colKey]; return v !== undefined && v !== null ? v : "" }
                                        color: (rowMouse.containsMouse || rowItem.isSelected || rowItem.isCurrent)
                                               ? window.sysPal.highlightedText
                                               : window.sysPal.windowText
                                        font.pixelSize: 12
                                        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 600
                            ToolTip.text: "Click to select and open '" + (rowItem.rowObj["File"] || "") + "' in the Image Viewer"
                            onClicked: {
                                detailsList.currentIndex = rowItem.index
                                detailsList.forceActiveFocus()
                                var p = rowItem.rowObj["Path"] || ""
                                var n = rowItem.rowObj["File"] || ""
                                root.selectedFilePath = p
                                root.selectedFileName  = n
                                if (p !== "") root.fileOpenRequested(p, n)
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: "Scan FITS files to see file-level details."
            color: window.sysPal.placeholderText; font.pixelSize: 13
            visible: root.displayCount === 0
        }
    }
}
