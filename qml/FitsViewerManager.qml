import QtQuick
import QtQuick.Controls

// Logic-only controller that owns the FITS viewer window and all
// rejection/navigation state.  main.qml binds displayRows and
// transientParent, calls openFile(), and handles removeRowRequested().
Item {
    id: manager
    width: 0; height: 0; visible: false

    // ── Public API ────────────────────────────────────────────────────────────

    // Bind to fileDetailsView.displayRows so navigation always uses the
    // current (possibly filtered) file list.
    property var displayRows: []

    // Forward to the inner Window so it appears as a child of the main window.
    property var transientParent: null

    // Emitted whenever a row must be removed from the file list model.
    // The caller (main.qml) handles the actual removeRow() call.
    signal removeRowRequested(string path)

    // Open the viewer for the given file path.  The path is looked up in
    // displayRows to set fileIndex / fileCount correctly.
    function openFile(path) {
        var rows = manager.displayRows
        var idx  = -1
        for (var i = 0; i < rows.length; i++) {
            if ((rows[i]["Path"] || "") === path) { idx = i; break }
        }
        fitsViewer.fileIndex  = idx
        fitsViewer.fileCount  = rows.length
        fitsViewer.isRejected = !!manager.rejectedSet[path]
        fitsViewer.openFile(path)

        // Track viewed paths — maintain insertion order, no duplicates.
        var vp = manager.viewedPaths.slice()
        if (vp.indexOf(path) === -1) {
            vp.push(path)
            manager.viewedPaths = vp
        }
    }

    // ── Internal state ────────────────────────────────────────────────────────

    // Keys are file paths; a key's presence means the file is marked rejected
    // for this session.  Files are not moved until Finalize is confirmed.
    property var rejectedSet: ({})

    // Ordered list of paths that have been opened in the viewer this session.
    property var viewedPaths: []

    // Pre-populate rejectedSet from persisted .mrj sidecars when the file list
    // is (re)loaded after a scan.
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

    // ── Viewer window ─────────────────────────────────────────────────────────
    FitsImageViewer {
        id: fitsViewer
        transientParent: manager.transientParent
        viewedPaths:     manager.viewedPaths
        rejectedSet:     manager.rejectedSet

        // File was deleted — viewer hides itself; we just clean up the lists.
        onFileDeleted: function(path) {
            organizer.writeSidecar(path, false)
            delete manager.rejectedSet[path]
            manager.rejectedSet = Object.assign({}, manager.rejectedSet)
            fitsViewer.rejectedCount = Object.keys(manager.rejectedSet).length
            manager.removeRowRequested(path)
        }

        // Toggle the rejected mark for the currently displayed image.
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

        // Move all session-marked images then navigate to the next valid file.
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

        // Navigate to any thumbnail the user clicks.
        onRequestOpenPath: function(path) { manager.openFile(path) }

        onRequestPrevious: {
            var idx  = fitsViewer.fileIndex - 1
            var rows = manager.displayRows
            if (idx >= 0 && idx < rows.length) {
                var p = rows[idx]["Path"] || ""
                fitsViewer.fileIndex  = idx
                fitsViewer.isRejected = !!manager.rejectedSet[p]
                fitsViewer.openFile(p)

                var vp = manager.viewedPaths.slice()
                if (vp.indexOf(p) === -1) { vp.push(p); manager.viewedPaths = vp }
            }
        }

        onRequestNext: {
            var idx  = fitsViewer.fileIndex + 1
            var rows = manager.displayRows
            if (idx >= 0 && idx < rows.length) {
                var p = rows[idx]["Path"] || ""
                fitsViewer.fileIndex  = idx
                fitsViewer.isRejected = !!manager.rejectedSet[p]
                fitsViewer.openFile(p)

                var vp = manager.viewedPaths.slice()
                if (vp.indexOf(p) === -1) { vp.push(p); manager.viewedPaths = vp }
            }
        }
    }
}
