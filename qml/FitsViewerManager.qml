import QtQuick
import QtQuick.Controls

Item {
    id: manager
    width: 0; height: 0; visible: false

    property var displayRows: []

    property var transientParent: null

    signal removeRowRequested(string path)

    property var navList: []

    function openViewer() {
        fitsViewer.showFiles()
    }

    function openFile(path) {
        var list = []
        for (var i = 0; i < manager.displayRows.length; i++)
            list.push(manager.displayRows[i]["Path"] || "")
        manager.navList = list
        manager.openAt(path)
    }

    function openInList(path, paths) {
        manager.navList = paths
        manager.openAt(path)
    }

    function openAt(path) {
        fitsViewer.fileIndex  = manager.navList.indexOf(path)
        fitsViewer.fileCount  = manager.navList.length
        fitsViewer.isRejected = !!manager.rejectedSet[path]
        fitsViewer.openFile(path)

        var vp = manager.viewedPaths.slice()
        if (vp.indexOf(path) === -1) {
            vp.push(path)
            manager.viewedPaths = vp
        }
    }

    property var rejectedSet: ({})

    property var viewedPaths: []

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
        fitsViewer.rejectedCount = Object.keys(newSet).length
    }

    FitsImageViewer {
        id: fitsViewer
        transientParent: manager.transientParent
        viewedPaths:     manager.viewedPaths
        rejectedSet:     manager.rejectedSet
        displayRows:     manager.displayRows

        onFileDeleted: function(path) {
            organizer.writeSidecar(path, false)
            delete manager.rejectedSet[path]
            manager.rejectedSet = Object.assign({}, manager.rejectedSet)
            fitsViewer.rejectedCount = Object.keys(manager.rejectedSet).length
            manager.removeRowRequested(path)
        }

        onRequestToggleReject: {
            var path = fitsViewer.filePath
            if (manager.rejectedSet[path]) {
                delete manager.rejectedSet[path]
                manager.rejectedSet = Object.assign({}, manager.rejectedSet)
                fitsViewer.isRejected = false
                organizer.writeSidecar(path, false)
            } else {
                manager.rejectedSet[path] = true
                manager.rejectedSet = Object.assign({}, manager.rejectedSet)
                fitsViewer.isRejected = true
                organizer.writeSidecar(path, true)
            }
            fitsViewer.rejectedCount = Object.keys(manager.rejectedSet).length
        }

        onFinalizeAccepted: {
            var paths = Object.keys(manager.rejectedSet)
            for (var i = 0; i < paths.length; i++) {
                var newPath = organizer.rejectFile(paths[i])
                if (newPath !== "")
                    manager.removeRowRequested(paths[i])
            }
            manager.rejectedSet      = {}
            fitsViewer.rejectedCount = 0
            fitsViewer.isRejected    = false

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

        onRequestOpenPath: function(path) { manager.openFile(path) }

        onRequestOpenInList: function(path, paths) { manager.openInList(path, paths) }

        onRejectionsApplied: function(paths) {
            for (var i = 0; i < paths.length; i++)
                manager.rejectedSet[paths[i]] = true
            manager.rejectedSet = Object.assign({}, manager.rejectedSet)
            fitsViewer.rejectedCount = Object.keys(manager.rejectedSet).length
            if (manager.rejectedSet[fitsViewer.filePath])
                fitsViewer.isRejected = true
        }

        onUnrejectionsApplied: function(paths) {
            for (var i = 0; i < paths.length; i++)
                delete manager.rejectedSet[paths[i]]
            manager.rejectedSet = Object.assign({}, manager.rejectedSet)
            fitsViewer.rejectedCount = Object.keys(manager.rejectedSet).length
            if (!manager.rejectedSet[fitsViewer.filePath])
                fitsViewer.isRejected = false
        }

        onRequestPrevious: {
            var idx = fitsViewer.fileIndex - 1
            if (idx >= 0 && idx < manager.navList.length)
                manager.openAt(manager.navList[idx])
        }

        onRequestNext: {
            var idx = fitsViewer.fileIndex + 1
            if (idx >= 0 && idx < manager.navList.length)
                manager.openAt(manager.navList[idx])
        }
    }
}
