#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# build-appimage.sh — Build a portable AppImage of Meridian
# Usage:  bash build-appimage.sh [--skip-build]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build-release"
APPDIR="$SCRIPT_DIR/AppDir"
TOOLS_DIR="$SCRIPT_DIR/tools"
BINARY_NAME="Meridian"
ARCH="$(uname -m)"

SKIP_BUILD=false
for arg in "$@"; do [[ "$arg" == "--skip-build" ]] && SKIP_BUILD=true; done

info()    { echo -e "\e[1;34m==> $*\e[0m"; }
success() { echo -e "\e[1;32m==> $*\e[0m"; }
warn()    { echo -e "\e[1;33mWARN: $*\e[0m"; }
die()     { echo -e "\e[1;31mERROR: $*\e[0m" >&2; exit 1; }

download() {
    local url="$1" dest="$2"
    if [[ -f "$dest" ]]; then info "Cached: $(basename "$dest")"; return; fi
    info "Downloading $(basename "$dest")..."
    curl -fsSL --progress-bar -o "$dest" "$url" || die "Failed to download $url"
    chmod +x "$dest"
}

# ── Download tools ────────────────────────────────────────────────────────────
mkdir -p "$TOOLS_DIR"
LINUXDEPLOY="$TOOLS_DIR/linuxdeploy-${ARCH}.AppImage"
LINUXDEPLOY_QT="$TOOLS_DIR/linuxdeploy-plugin-qt-${ARCH}.AppImage"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-${ARCH}.AppImage"

download "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-${ARCH}.AppImage"            "$LINUXDEPLOY"
download "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-${ARCH}.AppImage" "$LINUXDEPLOY_QT"
download "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"             "$APPIMAGETOOL"

# Symlink plugin so linuxdeploy finds it by the expected bare name
[[ -f "$TOOLS_DIR/linuxdeploy-plugin-qt" ]] || \
    ln -sf "linuxdeploy-plugin-qt-${ARCH}.AppImage" "$TOOLS_DIR/linuxdeploy-plugin-qt"

export PATH="$TOOLS_DIR:$PATH"

# Modern kernels (6+) use FUSE3; AppImage tools need FUSE2 to mount themselves.
# APPIMAGE_EXTRACT_AND_RUN=1 makes them self-extract instead, requiring no FUSE.
export APPIMAGE_EXTRACT_AND_RUN=1

# ── Find qmake6 — never use plain qmake (may be Qt5) ─────────────────────────
info "Locating qmake6..."
QMAKE6=""
for candidate in \
    "$(command -v qmake6 2>/dev/null)" \
    /usr/lib/qt6/bin/qmake \
    /usr/bin/qmake6 \
    /usr/local/bin/qmake6; do
    if [[ -x "$candidate" ]]; then
        if "$candidate" -query QT_VERSION 2>/dev/null | grep -q "^6\."; then
            QMAKE6="$candidate"
            break
        fi
    fi
done

if [[ -z "$QMAKE6" ]]; then
    while IFS= read -r qm; do
        if "$qm" -query QT_VERSION 2>/dev/null | grep -q "^6\."; then
            QMAKE6="$qm"; break
        fi
    done < <(find /usr -name "qmake*" -executable 2>/dev/null | sort)
fi

[[ -n "$QMAKE6" ]] || die "Could not find qmake6. Install qt6-base or qt6-tools."
info "Using qmake6: $QMAKE6 ($(${QMAKE6} -query QT_VERSION))"
export QMAKE="$QMAKE6"

QT_PLUGINS_DIR="$("$QMAKE6" -query QT_INSTALL_PLUGINS)"

# ── Build ─────────────────────────────────────────────────────────────────────
export DISABLE_COPYRIGHT_FILES_DEPLOYMENT=1
export EXCLUDE_LIBS="libQt6VirtualKeyboard.so.6:libQt6VirtualKeyboardQml.so.6:libQt6VirtualKeyboardSettings.so.6:libQt6Pdf.so.6:libQt6PdfQuick.so.6:libQt6QuickTimeline.so.6:libQt6QuickTimelineBlendTrees.so.6:libQt6QuickVectorImage.so.6:libQt6QuickVectorImageGenerator.so.6:libQt6QuickVectorImageHelpers.so.6:libQt6PrintSupport.so.6:libQt6Sql.so.6:libQt6HunspellInputMethod.so.6:libQt6QmlXmlListModel.so.6:libQt6QmlLocalStorage.so.6"

if [[ "$SKIP_BUILD" == false ]]; then
    info "Fixing file timestamps to prevent clock-skew warnings..."
    find "$SCRIPT_DIR/src" "$SCRIPT_DIR/qml" "$SCRIPT_DIR/CMakeLists.txt" \
         -type f \( -name "*.cpp" -o -name "*.h" -o -name "*.qml" -o -name "CMakeLists.txt" \) \
         -exec touch {} + 2>/dev/null || true

    info "Configuring Release build..."
    cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr
    info "Building..."
    cmake --build "$BUILD_DIR" --parallel "$(nproc)"
else
    [[ -x "$BUILD_DIR/bin/$BINARY_NAME" ]] || \
        die "Executable $BUILD_DIR/bin/$BINARY_NAME not found. Run without --skip-build first."
    info "Skipping build."
    find "$SCRIPT_DIR/src" "$SCRIPT_DIR/qml" "$SCRIPT_DIR/CMakeLists.txt" \
         -type f \( -name "*.cpp" -o -name "*.h" -o -name "*.qml" -o -name "CMakeLists.txt" \) \
         -exec touch {} + 2>/dev/null || true
fi

# ── Install into AppDir ───────────────────────────────────────────────────────
info "Installing into AppDir..."
rm -rf "$APPDIR"
DESTDIR="$APPDIR" cmake --install "$BUILD_DIR"

# ── Desktop file and icon ─────────────────────────────────────────────────────
info "Copying desktop file and icon..."
[[ -f "$SCRIPT_DIR/resources/meridian.desktop" ]] || die "Missing meridian.desktop"
[[ -f "$SCRIPT_DIR/resources/meridian.svg"     ]] || die "Missing meridian.svg"

install -Dm644 "$SCRIPT_DIR/resources/meridian.desktop" \
    "$APPDIR/usr/share/applications/meridian.desktop"
install -Dm644 "$SCRIPT_DIR/resources/meridian.svg" \
    "$APPDIR/usr/share/icons/hicolor/scalable/apps/meridian.svg"

cp "$SCRIPT_DIR/resources/meridian.desktop" "$APPDIR/meridian.desktop"
cp "$SCRIPT_DIR/resources/meridian.svg"     "$APPDIR/meridian.svg"

APPDATA="$SCRIPT_DIR/appstream/app.meridian.Meridian.metainfo.xml"
if [[ -f "$APPDATA" ]]; then
    install -Dm644 "$APPDATA" "$APPDIR/usr/share/metainfo/app.meridian.Meridian.metainfo.xml"
else
    warn "appstream/app.meridian.Meridian.metainfo.xml not found — AppStream metadata will be missing."
fi

# ── Pass 1: Deploy ELF dependencies ──────────────────────────────────────────
info "Pass 1: deploying ELF dependencies..."
"$LINUXDEPLOY" \
    --appdir="$APPDIR" \
    --executable="$APPDIR/usr/bin/$BINARY_NAME" \
    --desktop-file="$APPDIR/usr/share/applications/meridian.desktop" \
    --icon-file="$SCRIPT_DIR/resources/meridian.svg" \
    2>&1 | grep -v "Strip call failed\|relr\.dyn\|Unable to recognise\|deferred operations\|unsupported GNU_PROPERTY" || true
[[ -x "$APPDIR/usr/bin/$BINARY_NAME" ]] || die "linuxdeploy failed — $BINARY_NAME not found in AppDir"

# ── Pass 2: Bundle Qt plugins and QML imports ─────────────────────────────────
info "Pass 2: bundling Qt plugins and QML imports..."
export QML_SOURCES_PATHS="$SCRIPT_DIR/qml"

"$LINUXDEPLOY_QT" --appdir="$APPDIR" \
    2>&1 | grep -v "Strip call failed\|relr\.dyn\|Unable to recognise\|deferred operations\|unsupported GNU_PROPERTY" || true

# ── Pass 3: Guarantee xcb platform plugin is present ─────────────────────────
# linuxdeploy-plugin-qt often fails to bundle libqxcb.so on Qt6/Arch systems.
info "Pass 3: verifying xcb platform plugin..."
XCB_DST="$APPDIR/usr/plugins/platforms/libqxcb.so"
if [[ ! -f "$XCB_DST" ]]; then
    XCB_SRC="$QT_PLUGINS_DIR/platforms/libqxcb.so"
    [[ -f "$XCB_SRC" ]] || die "Qt xcb platform plugin not found at $XCB_SRC — ensure qt6-base is installed"
    warn "  xcb plugin missing from AppDir — copying from $XCB_SRC"
    mkdir -p "$APPDIR/usr/plugins/platforms"
    cp "$XCB_SRC" "$XCB_DST"
    # Re-run linuxdeploy with --library so it walks xcb's ELF dependencies
    "$LINUXDEPLOY" \
        --appdir="$APPDIR" \
        --executable="$APPDIR/usr/bin/$BINARY_NAME" \
        --library="$XCB_DST" \
        2>&1 | grep -v "Strip call failed\|relr\.dyn\|Unable to recognise\|deferred operations\|unsupported GNU_PROPERTY" || true
else
    info "  xcb platform plugin present — OK"
fi

# ── Pass 4: Bundle Qt plugins and QML modules missed by linuxdeploy-plugin-qt ─
# On Qt6/Arch, linuxdeploy-plugin-qt routinely skips TLS, GL integrations, and
# QML modules. We always merge from the system Qt install (cp -r src/. dst/
# merges without clobbering existing files) so partial dirs are completed, then
# run linuxdeploy on ALL .so files in those dirs to resolve any missing deps.
info "Pass 4: ensuring TLS, GL integrations, and QML modules..."

QT_QML_DIR="$("$QMAKE6" -query QT_INSTALL_QML)"

_ensure_plugin() {
    local src="$1" dst_dir="$2"
    local base; base="$(basename "$src")"
    if [[ -f "$src" ]]; then
        mkdir -p "$dst_dir"
        if [[ ! -f "$dst_dir/$base" ]]; then
            cp "$src" "$dst_dir/$base"
            info "  copied plugin: $base"
        fi
    fi
}

_sync_qml_module() {
    local module="$1"
    local src="$QT_QML_DIR/$module"
    local dst="$APPDIR/usr/qml/$module"
    if [[ ! -d "$src" ]]; then
        warn "  QML module not on system: $module"
        return
    fi
    mkdir -p "$dst"
    # Always merge — fills files missing from an incomplete linuxdeploy-plugin-qt copy
    cp -r "$src/." "$dst/"
    info "  synced QML module: $module"
}

# TLS backend — required for HTTPS / qt.network.ssl
_ensure_plugin "$QT_PLUGINS_DIR/tls/libqopensslbackend.so"  "$APPDIR/usr/plugins/tls"
_ensure_plugin "$QT_PLUGINS_DIR/tls/libqcertonlybackend.so" "$APPDIR/usr/plugins/tls"

# XCB GL integrations — needed for hardware-accelerated OpenGL under XCB
_ensure_plugin "$QT_PLUGINS_DIR/xcbglintegrations/libqxcb-glx-integration.so" \
               "$APPDIR/usr/plugins/xcbglintegrations"
_ensure_plugin "$QT_PLUGINS_DIR/xcbglintegrations/libqxcb-egl-integration.so" \
               "$APPDIR/usr/plugins/xcbglintegrations"

# QML modules this app actually imports
for _module in \
    QtQuick \
    QtQuick/Controls \
    QtQuick/Layouts \
    QtQuick/Window \
    QtQuick/Templates \
    QtQml \
    QtQml/Models; do
    _sync_qml_module "$_module"
done

# Always re-run linuxdeploy over ALL .so files in these dirs so that every
# plugin (new or pre-existing) has its ELF dependencies deployed.
PASS4_LIBS=()
while IFS= read -r -d '' _so; do
    PASS4_LIBS+=("--library=$_so")
done < <(find \
    "$APPDIR/usr/plugins/tls" \
    "$APPDIR/usr/plugins/xcbglintegrations" \
    "$APPDIR/usr/qml" \
    -name "*.so" -print0 2>/dev/null)

if [[ ${#PASS4_LIBS[@]} -gt 0 ]]; then
    info "  resolving deps for ${#PASS4_LIBS[@]} plugin/QML .so files..."
    "$LINUXDEPLOY" \
        --appdir="$APPDIR" \
        --executable="$APPDIR/usr/bin/$BINARY_NAME" \
        "${PASS4_LIBS[@]}" \
        2>&1 | grep -v "Strip call failed\|relr\.dyn\|Unable to recognise\|deferred operations\|unsupported GNU_PROPERTY" || true
fi

# ── Bundle platform theme plugins ─────────────────────────────────────────────
# linuxdeploy-plugin-qt often omits these (they live in separate distro packages).
# We copy whichever are present on the build machine; the AppRun only activates
# a plugin when the file exists, so missing ones are silently skipped.
info "Bundling platform theme plugins..."
mkdir -p "$APPDIR/usr/plugins/platformthemes"

for theme_plugin in \
    "$QT_PLUGINS_DIR/platformthemes/libqgtk3.so" \
    "$QT_PLUGINS_DIR/platformthemes/libqxdgdesktopportal.so" \
    "$QT_PLUGINS_DIR/platformthemes/KDEPlasmaPlatformTheme6.so" \
    "$QT_PLUGINS_DIR/platformthemes/libqkde6.so" \
    "$QT_PLUGINS_DIR/platformthemes/libqkde.so"; do
    if [[ -f "$theme_plugin" ]]; then
        cp "$theme_plugin" "$APPDIR/usr/plugins/platformthemes/"
        info "  bundled: $(basename "$theme_plugin")"
    fi
done

# ── Remove unused QML modules ─────────────────────────────────────────────────
info "Removing unused QML modules..."
rm -rf \
    "$APPDIR/usr/qml/QtQuick/VirtualKeyboard" \
    "$APPDIR/usr/qml/QtQuick/Pdf" \
    "$APPDIR/usr/qml/QtQuick/Timeline" \
    "$APPDIR/usr/qml/QtQuick/VectorImage" \
    "$APPDIR/usr/qml/QtQuick/tooling" \
    "$APPDIR/usr/qml/QtQuick/LocalStorage" \
    "$APPDIR/usr/qml/QtQuick/Particles" \
    "$APPDIR/usr/qml/QtQuick/Shapes/DesignHelpers" \
    "$APPDIR/usr/qml/QtQuick/Controls/designer" \
    2>/dev/null || true

# ── Remove unused image format plugins ───────────────────────────────────────
info "Removing unused image format plugins..."
find "$APPDIR/usr/plugins/imageformats" -name "kimg_*" -delete 2>/dev/null || true

# ── Remove unused libraries ───────────────────────────────────────────────────
info "Removing unused libraries..."
for lib in \
    libQt6VirtualKeyboard libQt6Pdf libQt6PdfQuick libQt6PrintSupport \
    libQt6Sql libQt6HunspellInputMethod libQt6QmlXmlListModel \
    libQt6QmlLocalStorage libQt6QuickTimeline libQt6QuickTimelineBlendTrees \
    libQt6QuickVectorImage libQt6QuickVectorImageGenerator libQt6QuickVectorImageHelpers \
    libhunspell libOpenEXR libIex libIlmThread libOpenEXRCore \
    libraw libheif libde265 libaom libdav1d libSvtAv1Enc librav1e \
    libavif libjxl libjxl_cms libjxl_threads libhwy libsharpyuv \
    libwebp libwebpdemux libwebpmux libopenjp2 libopenjph libjpegxr libjxrglue \
    libjasper liblcms2 libyuv libmng libx264 libx265 libopenh264 \
    libdeflate libjbig libjpeg; do
    find "$APPDIR/usr/lib" -name "${lib}.so*" -delete 2>/dev/null || true
done

# ── Write AppRun ──────────────────────────────────────────────────────────────
info "Writing AppRun..."
cat > "$APPDIR/AppRun" << 'APPRUN'
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"

export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="$HERE/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QML_IMPORT_PATH="$HERE/usr/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
export QT_QPA_PLATFORM_PLUGIN_PATH="$HERE/usr/plugins/platforms"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# Always use XCB (XWayland on Wayland sessions). Qt 6 auto-detects
# WAYLAND_DISPLAY and crashes if a Wayland platform plugin is not bundled,
# so we pin xcb here for a reliable, zero-complexity platform choice.
# XWayland is transparent to the user for a desktop app like this.
export QT_QPA_PLATFORM=xcb

# Apply the matching desktop theme plugin for native file pickers and colours.
# Each plugin is only activated if its file was bundled at build time.
if [ -z "$QT_QPA_PLATFORMTHEME" ]; then
    _DESKTOP="${XDG_CURRENT_DESKTOP:-}:${DESKTOP_SESSION:-}"
    _DESKTOP_LOWER="$(echo "$_DESKTOP" | tr '[:upper:]' '[:lower:]')"
    case "$_DESKTOP_LOWER" in
        *gnome*|*unity*|*cinnamon*|*mate*|*xfce*|*budgie*|*deepin*|*dde*|*pantheon*|*lxde*)
            [ -f "$HERE/usr/plugins/platformthemes/libqxdgdesktopportal.so" ] && \
                export QT_QPA_PLATFORMTHEME=xdgdesktopportal || \
            [ -f "$HERE/usr/plugins/platformthemes/libqgtk3.so" ] && \
                export QT_QPA_PLATFORMTHEME=gtk3
            ;;
        *kde*|*plasma*|*lxqt*)
            if [ -f "$HERE/usr/plugins/platformthemes/KDEPlasmaPlatformTheme6.so" ] || \
               [ -f "$HERE/usr/plugins/platformthemes/libqkde6.so" ]; then
                export QT_QPA_PLATFORMTHEME=kde6
            elif [ -f "$HERE/usr/plugins/platformthemes/libqkde.so" ]; then
                export QT_QPA_PLATFORMTHEME=kde
            fi
            ;;
    esac
fi

exec "$HERE/usr/bin/Meridian" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# ── Produce AppImage ──────────────────────────────────────────────────────────
info "Producing AppImage..."
export ARCH="$ARCH"
OUTPUT="$SCRIPT_DIR/Meridian-${ARCH}.AppImage"
rm -f "$OUTPUT"

if command -v appimagetool &>/dev/null && \
   appimagetool --version 2>&1 | grep -qv "^/tmp/"; then
    appimagetool "$APPDIR" "$OUTPUT"
else
    APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" "$APPDIR" "$OUTPUT"
fi

echo ""
if [[ -f "$OUTPUT" ]]; then
    success "AppImage created: $OUTPUT"
    ls -lh "$OUTPUT"
else
    die "AppImage was not created. Check output above for errors."
fi
