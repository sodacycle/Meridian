import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: help
    title: "Meridian Help"
    width: 1080; height: 720
    minimumWidth: 760; minimumHeight: 480
    color: "#1b1b1b"

    readonly property color panel:   "#202020"
    readonly property color card:    "#2a2a2a"
    readonly property color divider: "#3a3a3a"
    readonly property color primary: "#e8e8e8"
    readonly property color label:   "#cfcfcf"
    readonly property color muted:   "#9a9a9a"
    readonly property color accent:  "#5a9fd4"
    readonly property color sel:     "#34506a"

    // Each entry is one help article. Order here is the order shown in the
    // topic list; the list groups consecutive entries by their section.
    readonly property var topics: [
        {
            section: "Getting Started",
            title: "Welcome to Meridian",
            body: "<p>Meridian is a local astrophotography session manager. It scans the folders where your FITS files live, reads their headers, and builds summaries of what you have imaged — then helps you plan new sessions, review and cull frames, and stack them into a final image.</p>"
                + "<p>Everything runs on your own computer and your image data stays on your machine. The only network use is optional weather, location, light-pollution and Wikipedia lookups.</p>"
                + "<p><b>A typical flow:</b></p>"
                + "<ul>"
                + "<li>Add the folders that hold your captures and <b>Scan FITS Files</b>.</li>"
                + "<li>Review the Target, Calibration and Catalog summaries to see what you have.</li>"
                + "<li>Plan upcoming nights with the Imaging Calendar and Observation Planner.</li>"
                + "<li>Open a frame in the Image Viewer to inspect, cull, and stack it.</li>"
                + "</ul>"
        },
        {
            section: "Getting Started",
            title: "Scanning FITS Files",
            body: "<p>Use <b>File ▸ Add Folder…</b> (Ctrl+O) to add one or more directories. Subfolders are scanned automatically, so adding the top of your image library is usually enough.</p>"
                + "<p>Then choose <b>File ▸ Scan FITS Files</b> (Ctrl+Shift+S). Meridian reads each file's header and builds the metadata table and every summary view.</p>"
                + "<ul>"
                + "<li><b>Incremental re-scanning:</b> files that have not changed (same size and modification time) are skipped, so re-scanning a large library is fast.</li>"
                + "<li><b>Sessions are remembered:</b> on the next launch Meridian can resume the last scan instead of starting fresh.</li>"
                + "<li>Press <b>Ctrl+.</b> (File ▸ Stop) to cancel a long scan while keeping the results gathered so far.</li>"
                + "</ul>"
        },
        {
            section: "Getting Started",
            title: "Preferences",
            body: "<p>Open <b>File ▸ Preferences…</b> (Ctrl+,) to set application-wide options and Image Viewer defaults in one place.</p>"
                + "<p><b>Application</b></p>"
                + "<ul>"
                + "<li><b>Open the Image Viewer when a file is selected</b> — turn off to just highlight a row in File-Level Details without launching the viewer.</li>"
                + "<li><b>Reuse a single Image Viewer window</b> — off opens every file in its own new window.</li>"
                + "<li><b>Remember the Image Viewer window size and position</b> across launches.</li>"
                + "<li><b>Confirm before rejecting or deleting frames.</b></li>"
                + "</ul>"
                + "<p><b>Image Viewer</b> — the same stretch limits and Auto-Sort defaults found on the viewer's own Settings tab. Changes here and there are always in sync.</p>"
        },
        {
            section: "Image Viewer",
            title: "Viewing & Stretching",
            body: "<p>The Image Viewer opens a FITS frame and renders it with an automatic screen stretch — the data on disk is never changed.</p>"
                + "<ul>"
                + "<li><b>Stretch (a):</b> an asinh curve that lifts faint detail. Lower values lift harder.</li>"
                + "<li><b>Clip (p):</b> sets the black/white points from a percentile of the pixel values.</li>"
                + "<li><b>Denoise:</b> an optional box-blur radius for a quick noise preview.</li>"
                + "</ul>"
                + "<p>The slider ranges come from the stretch limits in Preferences. Use the thumbnail strip and the Previous/Next controls to step through the frames in the current list, and save the current view as a JPEG when you want to share it.</p>"
        },
        {
            section: "Image Viewer",
            title: "Frame Culling (Auto-Sort)",
            body: "<p>The <b>Culling</b> tab scores your frames so you can drop the weak ones before stacking. Pick a control image, and Meridian measures each compatible frame and sorts it into PASS, BORDERLINE or REJECT.</p>"
                + "<ul>"
                + "<li><b>Metrics:</b> star count, star brightness, FWHM (sharpness), star eccentricity (roundness) and background noise. Toggle which ones to weigh in Preferences ▸ Auto-Sort defaults.</li>"
                + "<li><b>Sensitivity:</b> Conservative, Balanced or Aggressive presets, or Custom per-metric thresholds edited on the Analyze screen.</li>"
                + "<li><b>Review:</b> step through frames with Keep/Reject overrides, then apply the approved rejections. Rejections are written as sidecar files so they carry over between sessions.</li>"
                + "<li><b>Mosaics</b> are detected by pointing so each panel is culled against its own control frame.</li>"
                + "</ul>"
        },
        {
            section: "Image Viewer",
            title: "Stacking",
            body: "<p>The <b>Stacking</b> tab integrates the frames compatible with the open image (rejected frames are excluded) into a single 32-bit float FITS. The pipeline is calibrate → register → resample → combine.</p>"
                + "<ul>"
                + "<li><b>Registration</b> is rotation-aware: stars are detected and matched with an affine fit, then each frame is resampled with sub-pixel interpolation.</li>"
                + "<li><b>Combination:</b> Average or sigma-clipped (which rejects outliers like satellite trails).</li>"
                + "<li><b>Output:</b> Mono, full-colour (demosaiced) RGB, or a single channel, with optional grey-world auto colour balance.</li>"
                + "<li><b>Calibration:</b> darks, flats and bias are auto-matched from folders beside your lights and combined into sigma-clipped masters.</li>"
                + "</ul>"
                + "<p>The result is linear data — open it in the viewer to stretch it, or hand it to another tool for final processing.</p>"
        },
        {
            section: "Image Viewer",
            title: "Mosaic Stacking",
            body: "<p>When the selected frames span several pointings, Meridian detects a <b>mosaic</b> and offers a choice: assemble all panels into one wide image, or focus on a single panel and ignore the rest.</p>"
                + "<ul>"
                + "<li>Panels are placed on one enlarged canvas by registering each through the stars it shares with its neighbours.</li>"
                + "<li>Panels are <b>background-matched</b> so they do not leave brightness steps where they overlap.</li>"
                + "<li>Panels that do not overlap any other are reported and left out.</li>"
                + "</ul>"
                + "<p>The mosaic result has empty (no-data) borders; the viewer's stretch ignores those so the sky still renders correctly.</p>"
        },
        {
            section: "Planning",
            title: "Imaging Calendar",
            body: "<p>The Imaging Calendar overlays your sessions on a month, 7-day or 3-day view, with weather and moon-phase information for upcoming nights.</p>"
                + "<p>Each night cell summarises what you imaged or plan to image. Filter by target or catalog to focus the calendar on a single object's history.</p>"
        },
        {
            section: "Planning",
            title: "Observation Planner",
            body: "<p>The Observation Planner shows tonight's visible objects and when they are best placed. A <b>Sky Arc</b> visualises each target's path across the sky for the night.</p>"
                + "<ul>"
                + "<li>The sky view is filtered to your <b>viewable area</b> so it only suggests objects you can actually reach from your site.</li>"
                + "<li>The Detailed Sky View is a full 360° dome with a RA/Dec grid and a sunset-to-sunrise night window.</li>"
                + "<li>The Detailed planner view blocks the night into a timeline so you can schedule targets back to back.</li>"
                + "</ul>"
        },
        {
            section: "Planning",
            title: "Night Scheduler & Light Pollution",
            body: "<p>The Night Scheduler helps order a night's targets into a workable plan around their visibility windows.</p>"
                + "<p>The Light Pollution lookup reports the sky brightness at your location, so you can weigh how realistic a faint target is from home versus a darker site.</p>"
        },
        {
            section: "Your Data",
            title: "Target Summary",
            body: "<p>The Target Summary groups every scanned light frame by object and reports the sessions, sub counts and total integration time per target — a quick answer to “how much data do I have on this one?”</p>"
                + "<p>Select a target to filter the other views to just that object.</p>"
        },
        {
            section: "Your Data",
            title: "Calibration Summary",
            body: "<p>The Calibration Summary inventories your darks, flats and bias frames so you can see which calibration you hold for each camera, exposure and temperature — and spot what is missing before a stack.</p>"
        },
        {
            section: "Your Data",
            title: "Catalog Breakdown & DSO Catalog",
            body: "<p>The Catalog Breakdown sorts your imaged objects by catalog (Messier, NGC, IC and more). The built-in DSO catalog of 13,000+ objects powers lookups, planning and a Wikipedia summary for the selected object.</p>"
        },
        {
            section: "Your Data",
            title: "Export & Reports",
            body: "<p>From <b>File ▸ Export</b> you can save your library as data or a report:</p>"
                + "<ul>"
                + "<li><b>Target Summary (CSV)</b> — targets, sessions and integration time.</li>"
                + "<li><b>Session History (CSV)</b> — every scanned frame's metadata.</li>"
                + "<li><b>Report (HTML)</b> — a printable summary of targets and session history.</li>"
                + "</ul>"
        },
        {
            section: "Your Data",
            title: "File Organiser & Seestar",
            body: "<p>The File Organiser provides multi-directory batch tools for tidying captures, including JPG cleanup and preparing a set for external processing.</p>"
                + "<p><b>Seestar integration:</b> when a Seestar volume is mounted, Meridian detects it, shows its connection status and free space, and adds its <b>MyWorks</b> folder to the scan automatically.</p>"
        }
    ]

    property int currentIndex: 0
    readonly property var current: (currentIndex >= 0 && currentIndex < topics.length) ? topics[currentIndex] : null

    function matches(topic, q) {
        if (q === "") return true
        var s = q.toLowerCase()
        return topic.title.toLowerCase().indexOf(s) !== -1
            || topic.section.toLowerCase().indexOf(s) !== -1
            || topic.body.toLowerCase().indexOf(s) !== -1
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Content pane (left), like a Wikipedia article.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: help.panel

            ScrollView {
                anchors.fill: parent
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Column {
                    width: help.width - sidebar.width - 48
                    x: 24; y: 24
                    spacing: 12

                    Text {
                        width: parent.width
                        text: help.current ? help.current.title : ""
                        color: help.primary; font.pixelSize: 26; font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        text: help.current ? help.current.section : ""
                        color: help.accent; font.pixelSize: 12; font.bold: true
                    }
                    Rectangle { width: parent.width; height: 1; color: help.divider }
                    Text {
                        width: parent.width
                        text: help.current ? help.current.body : ""
                        textFormat: Text.RichText
                        color: help.label; font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        lineHeight: 1.25
                        onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                    }
                    Item { width: 1; height: 24 }
                }
            }
        }

        Rectangle { Layout.fillHeight: true; width: 1; color: help.divider }

        // Topic list (right).
        Rectangle {
            id: sidebar
            Layout.fillHeight: true
            width: 280
            color: "#232323"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text { text: "Help Topics"; color: help.primary; font.pixelSize: 15; font.bold: true }

                TextField {
                    id: search
                    Layout.fillWidth: true
                    placeholderText: "Search help…"
                    color: help.primary
                    font.pixelSize: 13
                    background: Rectangle {
                        color: "#1b1b1b"; radius: 4
                        border.color: search.activeFocus ? help.accent : help.divider; border.width: 1
                    }
                }

                ListView {
                    id: topicList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: help.topics
                    currentIndex: help.currentIndex

                    section.property: "section"
                    section.criteria: ViewSection.FullString
                    section.delegate: Text {
                        width: topicList.width
                        text: section
                        color: help.muted; font.pixelSize: 11; font.bold: true
                        topPadding: 10; bottomPadding: 4
                    }

                    delegate: ItemDelegate {
                        required property int index
                        required property var modelData
                        width: topicList.width
                        height: visible ? 34 : 0
                        visible: help.matches(modelData, search.text)
                        highlighted: index === help.currentIndex
                        onClicked: help.currentIndex = index

                        background: Rectangle {
                            color: parent.highlighted ? help.sel
                                 : (parent.hovered ? "#2d2d2d" : "transparent")
                            radius: 4
                        }
                        contentItem: Text {
                            text: modelData.title
                            color: help.primary; font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
