import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width:  colW[0] + colW[1] + colW[2] + 32
    implicitHeight: 16 + titleText.implicitHeight + 10
                    + (root.rowCount > 0 ? (32 + 10 + root.listContentH) : placeholder.implicitHeight)
                    + 16
    color:  window.sysPal.base
    border.color: window.sysPal.mid
    border.width: 1
    radius: 6

    property int    rowCount: 0
    property string sortCol:  ""
    property bool   sortAsc:  true
    signal targetSelected(string targetName)

    property var colW: [220, 110, 200]
    property var colL: ["Target","FITS Count","Total Integration Time"]
    readonly property int listContentH: root.rowCount > 0 ? Math.min(300, root.rowCount * 36 + 2) : 0

    function headerClicked(col) {
        if (sortCol === col) {
            sortAsc = !sortAsc
        } else {
            sortCol = col
            sortAsc = (col === "Target")
        }
        targetSummaryModel.sortBy(sortCol, sortAsc)
    }

    Connections {
        target: targetSummaryModel
        function onModelReset()   { root.rowCount = targetSummaryModel.rowCount() }
        function onRowsInserted() { root.rowCount = targetSummaryModel.rowCount() }
        function onRowsRemoved()  { root.rowCount = targetSummaryModel.rowCount() }
    }

    Text {
        id: titleText
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
        text: "Target Summary" + (root.rowCount > 0 ? " - Observed Targets: " + root.rowCount + "  |" : "")
        font.pixelSize: 20; font.bold: true
        color: window.sysPal.windowText
    }

    Row {
        id: headerRow
        anchors { top: titleText.bottom; topMargin: 10; left: parent.left; leftMargin: 16 }
        spacing: 0
        height: 32
        visible: root.rowCount > 0
        Repeater {
            model: root.colL
            Rectangle {
                required property string modelData
                required property int    index
                width: root.colW[index]; height: 32
                color: root.sortCol === modelData
                       ? Qt.rgba(window.sysPal.highlight.r, window.sysPal.highlight.g,
                                 window.sysPal.highlight.b, 0.22)
                       : window.sysPal.alternateBase
                Row {
                    anchors { fill: parent; leftMargin: 8 }
                    spacing: 3
                    Text {
                        text: modelData
                        color: root.sortCol === modelData
                               ? window.sysPal.highlight : window.sysPal.windowText
                        font.pixelSize: 13; font.bold: true
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

    Item {
        id: listArea
        anchors {
            top: headerRow.bottom; topMargin: 10
            left: parent.left; leftMargin: 16
            right: parent.right; rightMargin: 16
            bottom: parent.bottom; bottomMargin: 16
        }
        visible: root.rowCount > 0

        ListView {
            id: targetList
            anchors.fill: parent
            clip: true
            model: targetSummaryModel
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Keys.onReturnPressed: {
                if (currentIndex >= 0 && currentItem)
                    root.targetSelected(currentItem.targetName)
            }
            Keys.onEnterPressed: Keys.returnPressed(event)

            delegate: Rectangle {
                required property int    index
                required property string targetName
                required property int    fitsCount
                required property string integrationTime

                readonly property bool isCurrent: ListView.isCurrentItem

                width: targetList.width; height: 36
                color: (rowMouse.containsMouse || isCurrent)
                       ? window.sysPal.highlight
                       : (index % 2 === 0 ? window.sysPal.alternateBase : "transparent")
                radius: 3

                Row {
                    anchors.fill: parent

                    Rectangle {
                        width: root.colW[0]; height: parent.height; color: "transparent"
                        Text {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4
                            text: targetName
                            color: (rowMouse.containsMouse || isCurrent) ? window.sysPal.highlightedText : window.sysPal.windowText
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        width: root.colW[1]; height: parent.height; color: "transparent"
                        Text {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4
                            text: fitsCount
                            color: (rowMouse.containsMouse || isCurrent) ? window.sysPal.highlightedText : window.sysPal.windowText
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        width: root.colW[2]; height: parent.height; color: "transparent"
                        Text {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4
                            text: integrationTime
                            color: (rowMouse.containsMouse || isCurrent) ? window.sysPal.highlightedText : window.sysPal.windowText
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        targetList.currentIndex = index
                        targetList.forceActiveFocus()
                        root.targetSelected(targetName)
                    }
                    ToolTip.visible: containsMouse
                    ToolTip.delay: 500
                    ToolTip.text: "Filter calendar and file list to show only '" + targetName + "'"
                }
            }
        }
    }

    Text {
        id: placeholder
        anchors { top: titleText.bottom; topMargin: 10; left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 16 }
        text: "Scan FITS files to populate the target summary."
        color: window.sysPal.placeholderText; font.pixelSize: 13
        visible: root.rowCount === 0
    }
}
