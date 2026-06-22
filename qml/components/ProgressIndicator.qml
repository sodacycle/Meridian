import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    implicitHeight: content.implicitHeight
    implicitWidth: 200

    property bool scannerRunning: false
    property bool organizerRunning: false

    ColumnLayout {
        id: content
        width: parent.width
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ProgressBar {
                Layout.fillWidth: true
                indeterminate: root.scannerRunning || root.organizerRunning
                value: 0
                from: 0
                to: 1
            }

            Text {
                text: root.scannerRunning
                      ? "Scanning… " + scanner.filesProcessed + " files"
                      : root.organizerRunning
                        ? organizer.statusText
                        : ""
                color: "#b2bac2"
                font.pixelSize: 12
                visible: root.scannerRunning || root.organizerRunning
            }
        }

        Text {
            Layout.fillWidth: true
            text: scanner.currentFile
            color: "#7f8895"
            font.pixelSize: 11
            elide: Text.ElideMiddle
            visible: root.scannerRunning && scanner.currentFile !== ""
        }
    }
}
