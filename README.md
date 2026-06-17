# Meridian — Astrophotography Session Manager

Meridian is a desktop application for astrophotographers that organises FITS files, plans observing sessions, and tracks imaging history. It is built with Qt 6 / QML and runs natively on Linux and Windows.

**[Full documentation on the Wiki](https://github.com/sodacycle/Meridian/wiki)**

---

## Features

- **Multi-Folder FITS Scanner** — add any number of root directories; all are scanned in one pass with partial results appearing as each folder finishes. No Python or external tools required.
- **Image Rejection Persistence** — rejection marks are saved as `.mrj` sidecar files next to your FITS files so culling work survives app restarts. Pre-populated automatically on the next scan.
- **Target Summary** — aggregates sessions by target object, showing total exposure time, sub counts, filters used, and equipment.
- **Calibration Summary** — separate view for bias, dark, and flat frames grouped by type and settings, linked to each light-frame session.
- **Imaging Calendar** — month-view calendar showing historical sessions overlaid with moon phase and weather data (cloud cover, humidity, temperature) fetched from the Open-Meteo API.
- **Observation Planner** — computes tonight's (or any future night's) visible objects from your location. All astronomical math runs in C++ (Julian Date, GMST, LST, altitude, rise/set hour angles). Results are sorted by peak altitude and filtered by a configurable horizon limit.
- **DSO Catalog** — built-in NGC/IC/Messier catalog with 13 000+ objects. Supports Seestar S50 mode (auto-filters to objects the smart telescope can reach).
- **Seestar Integration** — status panel showing telescope connection, free space, and telescope file detection. When `MyWorks/` is found on the Seestar volume, it is automatically added to the scan directory list.
- **Wikipedia Lookup** — fetches and parses infobox data for any catalog object directly from Wikipedia.
- **FITS Image Viewer** — display and inspect individual FITS images with zoom, pan, asinh stretch, denoising, image rejection workflow, and a scrollable thumbnail strip of every image viewed this session. Also opens `.jpg` / `.jpeg` preview files (stretch and denoise controls are hidden; rejection workflow not applicable).
- **Catalog Breakdown** — organises your imaging history by catalog (Messier, NGC, IC, Caldwell, Sharpless, Barnard, LDN, LBN, Abell, PGC, UGC, and more).
- **File Organiser** — batch tools for organising stacked files, scanning/deleting JPG previews, preparing Siril folder structures, and removing empty directories — all operating across all scan directories simultaneously.
- **Native system theme** — automatically matches your KDE Plasma or GTK desktop. Wayland native rendering is supported.

---

## Features in Detail

### FITS Image Viewer

Click any file in the metadata table to open it in a dedicated dark-themed viewer. Supports both FITS (`.fit` / `.fits`) and JPEG (`.jpg` / `.jpeg`) files. All processing is done locally in C++ — no external tools needed.

**Navigation and zoom:**
- Zoom in/out, fit-to-window, and 1:1 pixel-perfect viewing
- Keyboard shortcuts — `←` / `→` to navigate between images in the current scan
- Mouse drag to pan large images
- File counter showing current position (e.g. 15 / 247)

**Image processing:**
- **Asinh stretch** — adjustable stretch parameter to reveal faint details while controlling aggressiveness
- **Clipping control** — percentile-based clip level (90–99.9%) to manage bright outlier handling
- **Denoising** — optional box blur (radius 0–5) to smooth noise without degrading star detail
- **Live preview** — all adjustments apply in real time and persist across image navigation
- **Reset button** — restore defaults (a=0.10, clip=99.0%, denoise=off) with one click

**Thumbnail strip:**
- Scrollable strip at the bottom of the image area showing every image viewed this session
- Current image highlighted with a blue border; rejected images show a red dot
- Click any thumbnail to jump directly to that image

**Image quality workflow:**
- **Reject / Unreject** — mark individual images as rejected with a visual red X overlay; the mark is written to a `.mrj` sidecar file immediately so it survives a restart
- **Persistence** — on the next scan, previously rejected images are pre-marked automatically
- **Finalize rejected images** — batch-move all rejected images to a `rejected/` subfolder without modifying FITS data; sidecars are cleaned up automatically
- **Live rejection counter** — shows how many images are currently marked

**Safety and file management:**
- Gracefully handles compressed FITS, missing pixel data, and large files (512 MB safety limit)
- Delete the current file directly from the viewer with a confirmation prompt
- Full file path shown with hover tooltip

---

### Metadata Table

The metadata table displays detailed information for every scanned FITS file:

| Column | Description |
|---|---|
| Frame Type | Light / Dark / Flat / Bias |
| File | Filename |
| Target | Object name from FITS header |
| Start / End Time UTC | Observation timestamps |
| Exposure Time (s) | Per-sub exposure |
| Number of Subs | Sub-frame count |
| Total Exposure Time (s) | Accumulated integration |
| Telescope | Telescope name |
| Camera Model | Camera identifier |
| Sensor Temperature (°C) | Chip temperature |
| RA / DEC | Sky coordinates |
| Latitude / Longitude | Observation site |
| Binning | Camera binning setting |
| Filter Used | Filter wheel position |
| Gain | Camera gain |
| Focal Length (mm) | Imaging focal length |
| Aperture (mm) | Aperture diameter |
| Focus Position | Focuser position |
| Image Type | Image type header |
| Stacking Software | Software used for stacking |
| Rejected | `true` if a `.mrj` rejection sidecar is present |

**Filtering and navigation:**
- **Target filter** — select a target to see all exposures of that object
- **Catalog filter** — filter by catalog to explore specific regions
- **Calendar** — click any observation date to view all images from that night
- **Temperature toggle** — click the `°C / °F` button in the calendar header to switch units
- **Show All** — appears after filtering to quickly restore the full list
- **JPG integration** — scan for and view JPG preview files alongside FITS metadata
- Click any file row to open it instantly in the FITS Image Viewer

---

### Imaging Calendar

Month-view calendar showing every night you imaged with contextual overlays:

- **Moon phase** — automatically calculated and displayed for each date
- **Weather data** — cloud cover, humidity, and temperature fetched from Open-Meteo using coordinates extracted from your FITS headers (no API key required)
- **Weather code emojis** — at-a-glance sky condition summary per night
- **Temperature unit toggle** — switch between °C and °F in the calendar header
- Click a date to filter the metadata table to all images from that night

---

### Target Summary

Quick overview of all observation targets with aggregated statistics:

- Clickable target names that filter the metadata table
- Total FITS file count per target
- Combined integration time per target (useful for planning follow-up sessions)

---

### Calibration Summary

Automatically categorises calibration frames by type and settings:

- Separate sections for dark frames, flat fields, and bias frames
- Frames grouped by temperature, binning, and other key parameters to identify compatible calibration sets
- Frame counts per group to quickly locate matching calibration data

---

### Catalog Breakdown

Organises your imaging history by astronomical catalog:

- **Supported catalogs** — Messier, NGC, IC, Caldwell, Sharpless, Barnard, LDN, LBN, Abell, PGC, UGC, and Other
- Smart parsing automatically detects catalog designations from target names in FITS headers
- Clickable catalog entries filter the metadata table to those observations
- "Other" category captures objects not in standard catalogs

---

### Observation Planner

Plans tonight's session or any future night from your location:

- All astronomical math runs in C++ — Julian Date, GMST, LST, altitude, rise/set hour angles
- Objects sorted by peak altitude for the selected night
- Configurable minimum altitude horizon limit
- Supports Seestar S50 mode to filter to objects within the smart telescope's capabilities
- Night offset slider to plan sessions days ahead

---

### Advanced File Organiser Tools

Batch file operations accessible from the **Advanced Tools** panel. All tools operate across **every directory in the current scan list** simultaneously.

| Tool | Purpose |
|---|---|
| **Organise Stacked Files** | Detects and moves stacked FITS files into a `Stacked/` subfolder |
| **Scan for JPG Files** | Recursively finds all `.jpg` files and displays them in the file table |
| **Delete JPG Files** | Permanently removes all found JPG files after confirmation |
| **Siril Prep** | Renames and organises FITS files into the folder structure expected by Siril preprocessing (light/dark/flat/bias subfolders) |
| **Remove Empty Folders** | Recursively cleans up empty directories left after file operations |

All operations display real-time progress and are non-destructive to FITS data except where deletion is explicitly confirmed.

---

## Download

Pre-built AppImages for Linux are available on the [Releases page](https://github.com/sodacycle/Meridian/releases/).

| Platform | Download |
|---|---|
| Linux x86-64 | [Meridian-x86_64.AppImage](https://github.com/sodacycle/Meridian/releases/download/1.0.1a/Meridian-x86_64.AppImage) |

Download, make executable, and run — no Qt installation required:

```bash
chmod +x Meridian-x86_64.AppImage
./Meridian-x86_64.AppImage
```

---

## Requirements

| Dependency | Minimum version |
|---|---|
| Qt | 6.4 |
| CMake | 3.16 |
| C++ compiler | C++17 (GCC 10 / Clang 13 or later) |
| Qt modules | Core, Widgets, Quick, QuickControls2, Network, Concurrent |

### Arch Linux / CachyOS

```bash
sudo pacman -S qt6-base qt6-declarative qt6-quickcontrols2 cmake gcc
```

### Ubuntu 24.04+

```bash
sudo apt install qt6-base-dev qt6-declarative-dev qt6-quickcontrols2-dev \
                 cmake g++
```

---

## Building

### Linux — development build

```bash
git clone https://github.com/youruser/Meridian.git
cd Meridian
cmake --preset default        # configures Release build in ./build
cmake --build build --parallel
./build/bin/Meridian
```

A `debug` preset is also provided:

```bash
cmake --preset debug
cmake --build build-debug --parallel
```

### Linux — portable AppImage

```bash
bash build-appimage.sh
```

The script downloads `linuxdeploy` and `appimagetool` on first run (cached in `tools/`), compiles a Release binary, bundles all Qt libraries and QML modules, and produces `Meridian-x86_64.AppImage` in the project root.

```bash
bash build-appimage.sh --skip-build   # repackage without recompiling
```

### Windows

The application compiles on Windows without code changes. Qt handles all platform differences: the native Windows file picker, title bar, and networking APIs are used automatically.

**Prerequisites:** Qt 6.6+ (MSVC or MinGW 64-bit) and CMake 3.16+.

```powershell
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel --config Release
```

Run `windeployqt6` on the output binary to copy all required Qt DLLs and QML modules alongside the executable for distribution.

---

## Desktop Environment Compatibility

| Desktop | Package to install | What it provides |
|---|---|---|
| KDE Plasma | *(built-in)* | Full Breeze theming, native file picker |
| GNOME | `qt6-platformtheme-gtk3` (Arch) / `qt6-gtk-platformtheme` (Ubuntu) | GTK colour scheme, native GNOME file picker |
| XFCE / Cinnamon / MATE | same as GNOME above | GTK colour scheme, native file picker |
| Other / none | *(nothing required)* | Qt Fusion style — functional but not themed |

Meridian detects the running desktop at startup and automatically applies the correct theme plugin if available. No manual configuration is required.

### Wayland

Meridian supports Wayland natively if `qt6-wayland` is installed (`qt6-wayland` on Arch, `qt6-wayland` on Ubuntu). Without it the app runs under XWayland, which works correctly but without native HiDPI scaling and input handling. The session type is detected automatically.

---

## Project Structure

```
Meridian/
├── src/                    C++ backend
│   ├── main.cpp
│   ├── fitsparser.*        FITS header parser
│   ├── fitsscanner.*       Recursive file scanner
│   ├── fitsimageprovider.* QML image provider for FITS data
│   ├── fileorganizer.*     Batch file organiser
│   ├── metadatamodel.*     Table and summary models
│   ├── catalogservice.*    NGC/IC/Messier catalog loader
│   ├── plannerservice.*    Observation planner + astronomical math
│   ├── weatherservice.*    Open-Meteo weather fetcher
│   └── wikiservice.*       Wikipedia infobox fetcher
├── qml/                    QML/UI layer
│   ├── main.qml
│   ├── PlannerWindow.qml
│   ├── ImagingCalendar.qml
│   ├── TargetSummaryView.qml
│   ├── CalibrationSummaryView.qml
│   ├── FitsImageViewer.qml
│   ├── CatalogBreakdown.qml
│   └── components/         Reusable QML sub-components
├── appstream/              AppStream metadata
├── resources/              Icons and configuration
│   ├── meridian.desktop
│   └── meridian.svg
├── CMakeLists.txt
├── CMakePresets.json
└── build-appimage.sh
```

---

## Notes

- **Persistent settings** — temperature unit preference, last-used directory, and other options are stored via `QSettings` in the standard platform location (`~/.config/Meridian/` on Linux).
- **Async operations** — all batch operations (scanning, organising, deleting) run asynchronously with real-time progress feedback. The UI stays responsive throughout.
- **Moon phase** — calculated locally for each calendar date without any external API.
- **Weather** — fetched from [Open-Meteo](https://open-meteo.com/) using coordinates from your FITS headers. No API key required.
- **Wikipedia** — object infobox data is fetched and parsed on demand. No API key required.
- **Safe deletion** — all file deletion operations require explicit confirmation before proceeding.
- **Helpful tooltips** — hover over buttons and controls for contextual hints.

---

## License

MIT License. See `LICENSE` for details.
