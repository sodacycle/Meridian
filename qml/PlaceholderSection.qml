import QtQuick

Item {
    id: placeholder

    property string title: ""
    property string body: ""

    Rectangle { anchors.fill: parent; color: "#1b1b1b" }

    Column {
        anchors.centerIn: parent
        width: Math.min(360, parent.width - 48)
        spacing: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: placeholder.title
            color: "#e8e8e8"; font.pixelSize: 20; font.bold: true
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: placeholder.body
            color: "#9a9a9a"; font.pixelSize: 13
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: tag.implicitWidth + 20; height: tag.implicitHeight + 10
            radius: 4; color: "#2a2a2a"; border.color: "#3a3a3a"; border.width: 1
            Text {
                id: tag
                anchors.centerIn: parent
                text: "Planned"
                color: "#8a8a8a"; font.pixelSize: 11
            }
        }
    }
}
