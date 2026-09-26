import QtQuick
import QtQuick.Controls

Item {
    id: fileList

    property var paths: []
    property string currentPath: ""
    property var rejectedSet: ({})

    signal openRequested(string path)
    signal refreshRequested()

    function baseName(p) { return p.substring(p.lastIndexOf("/") + 1) }
    function dirName(p) {
        var i = p.lastIndexOf("/")
        return i > 0 ? p.substring(0, i) : ""
    }

    Rectangle { anchors.fill: parent; color: "#1b1b1b" }

    Rectangle {
        id: header
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48
        color: "#242424"

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#3a3a3a" }

        Column {
            anchors.left: parent.left; anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text { text: "Files"; color: "#e8e8e8"; font.pixelSize: 16; font.bold: true }
            Text {
                text: fileList.paths.length + " .fit file" + (fileList.paths.length === 1 ? "" : "s") + " in the scan folders"
                color: "#9a9a9a"; font.pixelSize: 11
            }
        }

        Button {
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "Refresh"
            ToolTip.visible: hovered; ToolTip.delay: 400
            ToolTip.text: "Re-read the .fit files from the selected scan folders."
            onClicked: fileList.refreshRequested()
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 8
        visible: fileList.paths.length === 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No .fit files found"
            color: "#777777"; font.pixelSize: 15
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Add a folder to the scan list on the main window, then press Refresh."
            color: "#5f5f5f"; font.pixelSize: 12
        }
    }

    ListView {
        id: list
        anchors.top: header.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        clip: true
        model: fileList.paths
        visible: fileList.paths.length > 0

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Rectangle {
            required property string modelData
            required property int index

            width: ListView.view.width
            height: 44
            readonly property bool isCurrent: modelData === fileList.currentPath
            color: isCurrent ? "#2a4a7a"
                  : rowHover.hovered ? "#242424"
                  : (index % 2 === 0 ? "#1b1b1b" : "#1e1e1e")

            HoverHandler { id: rowHover }

            Rectangle {
                visible: !!fileList.rejectedSet[modelData]
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: "#ee2020"; border.color: "#ffffff"; border.width: 1
            }

            Column {
                anchors.left: parent.left; anchors.leftMargin: 24
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: fileList.baseName(modelData)
                    color: isCurrent ? "#ffffff" : "#e0e0e0"
                    font.pixelSize: 13; font.bold: isCurrent
                    elide: Text.ElideMiddle
                }
                Text {
                    width: parent.width
                    text: fileList.dirName(modelData)
                    color: "#7a7a7a"; font.pixelSize: 10
                    elide: Text.ElideMiddle
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: fileList.openRequested(modelData)
            }
        }
    }
}
