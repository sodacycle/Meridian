import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: prefs
    title: "Preferences — Meridian"
    width: 640; height: 800
    minimumWidth: 480; minimumHeight: 560
    color: "#1b1b1b"

    readonly property color card:    "#2a2a2a"
    readonly property color divider: "#3a3a3a"
    readonly property color primary: "#e8e8e8"
    readonly property color label:   "#cfcfcf"
    readonly property color muted:   "#9a9a9a"

    // Edits are held in this draft and only written to the live settings on Save,
    // so Close without saving discards them. Loaded from the current settings
    // each time the window opens.
    QtObject {
        id: draft
        property real stretchMin: 0.01
        property real stretchMax: 2.0
        property real clipMin:    90.0
        property real clipMax:    99.9
        property int  denoiseMax: 5
        property string cullSensitivity: "balanced"
        property bool cullStarCount:  true
        property bool cullBrightness: true
        property bool cullFwhm:       true
        property bool cullEcc:        true
        property bool cullNoise:      true
        property bool launchViewerOnSelect:   true
        property bool reuseViewerWindow:      true
        property bool rememberViewerGeometry: false
        property bool confirmRejectDelete:    true
        property string astroFolder:          ""
        property bool seestarAutoImport:      false

        // SettingsView calls this for its own reset; here it mirrors the Defaults
        // button's viewer-related portion so the shared component still works.
        function resetViewerDefaults() {
            stretchMin = 0.01; stretchMax = 2.0; clipMin = 90.0; clipMax = 99.9; denoiseMax = 5
            cullSensitivity = "balanced"
            cullStarCount = true; cullBrightness = true; cullFwhm = true; cullEcc = true; cullNoise = true
        }
    }

    function loadDraft() {
        draft.stretchMin = appSettings.stretchMin
        draft.stretchMax = appSettings.stretchMax
        draft.clipMin    = appSettings.clipMin
        draft.clipMax    = appSettings.clipMax
        draft.denoiseMax = appSettings.denoiseMax
        draft.cullSensitivity = appSettings.cullSensitivity
        draft.cullStarCount  = appSettings.cullStarCount
        draft.cullBrightness = appSettings.cullBrightness
        draft.cullFwhm       = appSettings.cullFwhm
        draft.cullEcc        = appSettings.cullEcc
        draft.cullNoise      = appSettings.cullNoise
        draft.launchViewerOnSelect   = appSettings.launchViewerOnSelect
        draft.reuseViewerWindow      = appSettings.reuseViewerWindow
        draft.rememberViewerGeometry = appSettings.rememberViewerGeometry
        draft.confirmRejectDelete    = appSettings.confirmRejectDelete
        draft.astroFolder            = appSettings.astroFolder
        draft.seestarAutoImport      = appSettings.seestarAutoImport
    }

    function commitDraft() {
        appSettings.stretchMin = draft.stretchMin
        appSettings.stretchMax = draft.stretchMax
        appSettings.clipMin    = draft.clipMin
        appSettings.clipMax    = draft.clipMax
        appSettings.denoiseMax = draft.denoiseMax
        appSettings.cullSensitivity = draft.cullSensitivity
        appSettings.cullStarCount  = draft.cullStarCount
        appSettings.cullBrightness = draft.cullBrightness
        appSettings.cullFwhm       = draft.cullFwhm
        appSettings.cullEcc        = draft.cullEcc
        appSettings.cullNoise      = draft.cullNoise
        appSettings.launchViewerOnSelect   = draft.launchViewerOnSelect
        appSettings.reuseViewerWindow      = draft.reuseViewerWindow
        appSettings.rememberViewerGeometry = draft.rememberViewerGeometry
        appSettings.confirmRejectDelete    = draft.confirmRejectDelete
        appSettings.astroFolder            = draft.astroFolder
        appSettings.seestarAutoImport      = draft.seestarAutoImport
    }

    function loadDefaultsIntoDraft() {
        draft.resetViewerDefaults()
        draft.launchViewerOnSelect   = true
        draft.reuseViewerWindow      = true
        draft.rememberViewerGeometry = false
        draft.confirmRejectDelete    = true
        draft.seestarAutoImport      = false
        // The default astrophotography folder is a user choice; Defaults leaves it as-is.
    }

    onVisibleChanged: if (visible) loadDraft()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top button bar.
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: "#232323"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 16
                spacing: 10

                Button {
                    text: "Save"
                    highlighted: true
                    onClicked: { prefs.commitDraft(); prefs.close() }
                }
                Button {
                    text: "Defaults"
                    onClicked: { prefs.loadDefaultsIntoDraft(); prefs.commitDraft() }
                    ToolTip.visible: hovered
                    ToolTip.text: "Load the default settings and save them (window stays open)."
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Close without saving"
                    onClicked: prefs.close()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: prefs.divider }

        ScrollView {
            id: prefsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: prefsScroll.availableWidth

                Column {
            width: parent.width
            spacing: 16
            padding: 24

            Text { text: "Preferences"; font.pixelSize: 20; font.bold: true; color: prefs.primary }

            Rectangle {
                width: parent.width - 48
                height: appCol.height + 32
                color: prefs.card; border.color: prefs.divider; border.width: 1; radius: 6

                Column {
                    id: appCol
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 10

                    Text { text: "Application"; font.pixelSize: 14; font.bold: true; color: prefs.primary }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "How Meridian behaves when you open and work with images."
                        color: prefs.muted; font.pixelSize: 11
                    }

                    CheckBox {
                        text: "Open the Image Viewer when a file is selected"
                        checked: draft.launchViewerOnSelect
                        onToggled: draft.launchViewerOnSelect = checked
                        font.pixelSize: 13
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap; leftPadding: 26
                        text: "Clicking a row in File-Level Details opens it straight away. Turn off to just select the row."
                        color: prefs.muted; font.pixelSize: 11
                    }

                    CheckBox {
                        text: "Reuse a single Image Viewer window"
                        checked: draft.reuseViewerWindow
                        onToggled: draft.reuseViewerWindow = checked
                        font.pixelSize: 13
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap; leftPadding: 26
                        text: "Open each file in the same window. Turn off to open every file in its own new window."
                        color: prefs.muted; font.pixelSize: 11
                    }

                    CheckBox {
                        text: "Remember the Image Viewer window size and position"
                        checked: draft.rememberViewerGeometry
                        onToggled: draft.rememberViewerGeometry = checked
                        font.pixelSize: 13
                    }

                    CheckBox {
                        text: "Confirm before rejecting or deleting frames"
                        checked: draft.confirmRejectDelete
                        onToggled: draft.confirmRejectDelete = checked
                        font.pixelSize: 13
                    }
                }
            }

            Rectangle {
                width: parent.width - 48
                height: libCol.height + 32
                color: prefs.card; border.color: prefs.divider; border.width: 1; radius: 6

                Column {
                    id: libCol
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 10

                    Text { text: "Library & Seestar"; font.pixelSize: 14; font.bold: true; color: prefs.primary }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "Where your astrophotography files live, and how new Seestar captures get there."
                        color: prefs.muted; font.pixelSize: 11
                    }

                    Text { text: "Default astrophotography folder"; color: prefs.label; font.pixelSize: 12 }
                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: parent.width - chooseBtn.width - clearBtn.width - 16
                            height: 30
                            color: "#1b1b1b"; border.color: prefs.divider; border.width: 1; radius: 4
                            Text {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                text: draft.astroFolder !== "" ? draft.astroFolder : "Not set"
                                color: draft.astroFolder !== "" ? prefs.primary : prefs.muted
                                font.pixelSize: 12; elide: Text.ElideMiddle
                            }
                        }
                        Button {
                            id: chooseBtn
                            text: "Choose…"
                            onClicked: {
                                var d = scanner.selectDirectory()
                                if (d !== "") draft.astroFolder = d
                            }
                        }
                        Button {
                            id: clearBtn
                            text: "Clear"
                            enabled: draft.astroFolder !== ""
                            onClicked: draft.astroFolder = ""
                        }
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WrapAnywhere
                        text: draft.astroFolder !== ""
                              ? ("Seestar files are copied directly into:  " + draft.astroFolder)
                              : "The contents of the Seestar's MyWorks folder are copied directly into the folder you choose (its subfolders are kept)."
                        color: prefs.muted; font.pixelSize: 11
                    }

                    CheckBox {
                        text: "Offer to import Seestar files to this folder when a Seestar is connected"
                        checked: draft.seestarAutoImport
                        enabled: draft.astroFolder !== ""
                        onToggled: draft.seestarAutoImport = checked
                        font.pixelSize: 13
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap; leftPadding: 26
                        text: "When a Seestar with a MyWorks folder is detected, Meridian asks before copying its contents into your default folder. Files already there are skipped."
                        color: prefs.muted; font.pixelSize: 11
                    }
                }
            }

            Text { text: "Image Viewer"; font.pixelSize: 14; font.bold: true; color: prefs.primary }
            Text {
                width: parent.width - 48; wrapMode: Text.WordWrap
                text: "The same stretch limits and Auto-Sort defaults shown on the Image Viewer's Settings tab."
                color: prefs.muted; font.pixelSize: 11
            }
                }

                SettingsView {
                    width: parent.width
                    model: draft
                    showHeading: false
                    showReset: false
                }
            }
        }
    }
}
