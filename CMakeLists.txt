cmake_minimum_required(VERSION 3.16)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR
        "In-source builds are not supported.\n"
        "Run cmake with an explicit build directory:\n"
        "  cmake -S \"${CMAKE_SOURCE_DIR}\" -B \"${CMAKE_SOURCE_DIR}/build\"\n"
        "Or use the provided build.sh script.")
endif()

project(Meridian VERSION 1.0.2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Widgets Quick QuickControls2 Network Concurrent Positioning)

# Qt's QML module machinery creates a staging directory named after the target
# in CMAKE_BINARY_DIR.  Without this, the linker output path collides with that
# directory when the target and the QML URI share the same name ("Meridian").
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

# WIN32 prevents a console window appearing behind the app on Windows.
# On Linux/macOS this flag is ignored.
qt_add_executable(Meridian WIN32
    src/main.cpp
    src/fitsparser.h        src/fitsparser.cpp
    src/fitsscanner.h       src/fitsscanner.cpp
    src/fileorganizer.h     src/fileorganizer.cpp
    src/fitsimageprovider.h src/fitsimageprovider.cpp
    src/weatherservice.h    src/weatherservice.cpp
    src/metadatamodel.h     src/metadatamodel.cpp
    src/catalogservice.h    src/catalogservice.cpp
    src/plannerservice.h    src/plannerservice.cpp
    src/schedulerservice.h  src/schedulerservice.cpp
    src/locationservice.h         src/locationservice.cpp
    src/lightpollutionservice.h   src/lightpollutionservice.cpp
    src/wikiservice.h             src/wikiservice.cpp
    src/seestarservice.h          src/seestarservice.cpp
)

qt_add_qml_module(Meridian
    URI Meridian
    VERSION 1.0
    QML_FILES
        qml/main.qml
        qml/ControlsPanel.qml
        qml/AdvancedToolsPanel.qml
        qml/TargetSummaryView.qml
        qml/CatalogBreakdown.qml
        qml/ImagingCalendar.qml
        qml/CalibrationSummaryView.qml
        qml/FileDetailsView.qml
        qml/FitsImageViewer.qml
        qml/FitsViewerManager.qml
        qml/AboutDialog.qml
        qml/PlannerWindow.qml
        qml/components/ProgressIndicator.qml
    RESOURCES
        src/ngc-ic-messier-catalog.json
        resources/meridian.svg
)

target_link_libraries(Meridian PRIVATE
    Qt6::Core
    Qt6::Widgets
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    Qt6::Concurrent
    Qt6::Positioning
)

install(TARGETS Meridian
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
