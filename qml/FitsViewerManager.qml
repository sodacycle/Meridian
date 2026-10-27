import QtQuick
import QtQuick.Controls

Item {
    id: manager
    width: 0; height: 0; visible: false

    property var displayRows: []

    property var transientParent: null

    signal removeRowRequested(string path)

    // Rejected frames are an application-wide fact, so the set lives here and
    // every open viewer binds to it. Navigation and the thumbnail strip are
    // per-window state and live on each viewer instance instead.
    property var rejectedSet: ({})

    // The single reused window (created on demand). When "Reuse a single Image
    // Viewer window" is off, each open spawns its own instance, destroyed on close.
    property var reusedViewer: null

    function dirOf(path) {
        return path.substring(0, path.lastIndexOf("/"))
    }

    function pathList() {
        var list = []
        for (var i = 0; i < manager.displayRows.length; i++)
            list.push(manager.displayRows[i]["Path"] || "")
        return list
    }

    function makeViewer() {
        return viewerComponent.createObject(manager)
    }

    function primaryViewer() {
        if (!manager.reusedViewer)
            manager.reusedViewer = makeViewer()
        return manager.reusedViewer
    }

    function acquireViewer() {
        if (appSettings.reuseViewerWindow)
            return primaryViewer()
        return makeViewer()
    }

    function loadInto(v, path, paths) {
        v.navList = paths
        manager.openAt(v, path)
    }

    function openViewer() {
        primaryViewer().showFiles()
    }

    function openFile(path) {
        manager.loadInto(acquireViewer(), path, manager.pathList())
    }

    function openInList(path, paths) {
        manager.loadInto(acquireViewer(), path, paths)
    }

    function openAt(v, path) {
        // Moving into a different folder starts a fresh thumbnail strip.
        if (v.viewedPaths.length > 0 && dirOf(v.viewedPaths[0]) !== dirOf(path))
            v.viewedPaths = []

        v.fileIndex = v.navList.indexOf(path)
        v.fileCount = v.navList.length
        v.openFile(path)

        var vp = v.viewedPaths.slice()
        if (vp.indexOf(path) === -1) {
            vp.push(path)
            v.viewedPaths = vp
        }
    }

    function resetViewer() {
        if (!manager.reusedViewer) return
        manager.reusedViewer.navList     = []
        manager.reusedViewer.viewedPaths = []
        manager.reusedViewer.fileIndex   = -1
        manager.reusedViewer.fileCount   = 0
        manager.reusedViewer.filePath    = ""
        manager.reusedViewer.visible     = false
    }

    function handleViewerHidden(v) {
        if (v === manager.reusedViewer) return
        Qt.callLater(function() { if (v) v.destroy() })
    }

    onDisplayRowsChanged: {
        var newSet = {}
        for (var i = 0; i < displayRows.length; i++) {
            var row = displayRows[i]
            if (row["Rejected"] === true) {
                var p = row["Path"] || ""
                if (p) newSet[p] = true
            }
        }
        manager.rejectedSet = newSet
    }

    Component {
        id: viewerComponent

        FitsImageViewer {
            id: fitsViewer

            property var navList: []

            transientParent: manager.transientParent
            displayRows:     manager.displayRows
            rejectedSet:     manager.rejectedSet
            rejectedCount:   Object.keys(manager.rejectedSet).length
            isRejected:      !!manager.rejectedSet[filePath]

            onVisibleChanged: if (!visible) manager.handleViewerHidden(fitsViewer)

            onFileDeleted: function(path) {
                organizer.writeSidecar(path, false)
                delete manager.rejectedSet[path]
                manager.rejectedSet = Object.assign({}, manager.rejectedSet)
                manager.removeRowRequested(path)
            }

            onRequestToggleReject: {
                var path = fitsViewer.filePath
                if (manager.rejectedSet[path]) {
                    delete manager.rejectedSet[path]
                    manager.rejectedSet = Object.assign({}, manager.rejectedSet)
                    organizer.writeSidecar(path, false)
                } else {
                    manager.rejectedSet[path] = true
                    manager.rejectedSet = Object.assign({}, manager.rejectedSet)
                    organizer.writeSidecar(path, true)
                }
            }

            onFinalizeAccepted: {
                var paths = Object.keys(manager.rejectedSet)
                for (var i = 0; i < paths.length; i++) {
                    var newPath = organizer.rejectFile(paths[i])
                    if (newPath !== "")
                        manager.removeRowRequested(paths[i])
                }
                manager.rejectedSet = {}

                var rows = manager.displayRows
                fitsViewer.fileCount = rows.length
                var idx = Math.min(fitsViewer.fileIndex, rows.length - 1)
                if (idx >= 0 && idx < rows.length) {
                    fitsViewer.fileIndex = idx
                    fitsViewer.openFile(rows[idx]["Path"] || "")
                } else {
                    fitsViewer.visible = false
                }
            }

            onRequestOpenPath: function(path) {
                manager.loadInto(fitsViewer, path, manager.pathList())
            }

            onRequestOpenInList: function(path, paths) {
                manager.loadInto(fitsViewer, path, paths)
            }

            onRejectionsApplied: function(paths) {
                for (var i = 0; i < paths.length; i++)
                    manager.rejectedSet[paths[i]] = true
                manager.rejectedSet = Object.assign({}, manager.rejectedSet)
                fitsViewer.viewedPaths = fitsViewer.filePath !== "" ? [fitsViewer.filePath] : []
            }

            onUnrejectionsApplied: function(paths) {
                for (var i = 0; i < paths.length; i++)
                    delete manager.rejectedSet[paths[i]]
                manager.rejectedSet = Object.assign({}, manager.rejectedSet)
            }

            onRequestPrevious: {
                var idx = fitsViewer.fileIndex - 1
                if (idx >= 0 && idx < fitsViewer.navList.length)
                    manager.openAt(fitsViewer, fitsViewer.navList[idx])
            }

            onRequestNext: {
                var idx = fitsViewer.fileIndex + 1
                if (idx >= 0 && idx < fitsViewer.navList.length)
                    manager.openAt(fitsViewer, fitsViewer.navList[idx])
            }
        }
    }
}
