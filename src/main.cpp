#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDirIterator>

#include "fitsscanner.h"
#include "fileorganizer.h"
#include "fitsimageprovider.h"
#include "weatherservice.h"
#include "metadatamodel.h"
#include "catalogservice.h"
#include "plannerservice.h"
#include "schedulerservice.h"
#include "locationservice.h"
#include "lightpollutionservice.h"
#include "wikiservice.h"
#include "seestarservice.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName("Meridian");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("Meridian");
    app.setOrganizationDomain("meridian.app");

    // Register value types so they can travel through QVariant / signals
    qRegisterMetaType<WeatherData>();
    qRegisterMetaType<CatalogEntry>();
    qRegisterMetaType<PlannerEntry>();

    // ── Backend objects ───────────────────────────────────────────────────────
    // Declared before the engine so they outlive it. C++ destroys stack objects
    // in reverse declaration order, meaning the engine is destroyed first —
    // while all backend objects are still valid — preventing teardown errors.
    FitsScanner             scanner;
    FileOrganizer           organizer;
    WeatherService          weatherService;
    MetadataTableModel      metadataModel;
    TargetSummaryModel      targetSummaryModel;
    CalibrationSummaryModel calibrationSummaryModel;
    CatalogModel            catalogModel;
    CatalogService          catalogService;
    PlannerService          plannerService(&catalogService);
    SchedulerService        schedulerService;
    LocationService         locationService;
    LightPollutionService   lightPollutionService;
    WikiService             wikiService;
    SeestarService          seestarService;

    // OS location feeds directly into weather/planner location.
    QObject::connect(&locationService, &LocationService::locationObtained,
                     &weatherService,  &WeatherService::setLocation);

    // Light pollution lookup triggered by location.
    QObject::connect(&locationService, &LocationService::locationObtained,
                     &lightPollutionService, &LightPollutionService::fetch);

    // Request current position immediately — runs async, result arrives via signal.
    locationService.requestLocation();

    QQmlApplicationEngine engine;

    // Image provider must be registered before any QML image source references it.
    // The engine takes ownership of the provider.
    engine.addImageProvider(QStringLiteral("fitsprovider"), new FitsImageProvider());

    QQmlContext *ctx = engine.rootContext();
    ctx->setContextProperty("scanner",                 &scanner);
    ctx->setContextProperty("organizer",               &organizer);
    ctx->setContextProperty("weatherService",          &weatherService);
    ctx->setContextProperty("metadataModel",           &metadataModel);
    ctx->setContextProperty("targetSummaryModel",      &targetSummaryModel);
    ctx->setContextProperty("calibrationSummaryModel", &calibrationSummaryModel);
    ctx->setContextProperty("catalogModel",            &catalogModel);
    ctx->setContextProperty("catalogService",          &catalogService);
    ctx->setContextProperty("plannerService",          &plannerService);
    ctx->setContextProperty("schedulerService",        &schedulerService);
    ctx->setContextProperty("locationService",         &locationService);
    ctx->setContextProperty("lightPollutionService",   &lightPollutionService);
    ctx->setContextProperty("wikiService",             &wikiService);
    ctx->setContextProperty("seestarService",          &seestarService);

    // ── Populate models when a scan completes ─────────────────────────────────
    static const QStringList columns = {
        "Frame Type", "File", "Target", "Start Time UTC", "End Time UTC",
        "Exposure Time s", "Number of Subs", "Total Exposure Time s",
        "Telescope", "Camera Model", "Sensor Temperature C", "RA", "DEC",
        "Latitude", "Longitude", "Binning", "Filter Used", "Gain",
        "Focal Length mm", "Aperture mm", "Focus Position", "Image Type",
        "Stacking Software"
    };

    QObject::connect(&scanner, &FitsScanner::scanCompleted,
        [&](const QVariantList &meta, const QVariantList &targets, const QVariantList &cals)
        {
            metadataModel.setData(meta, columns);
            targetSummaryModel.setEntries(targets);
            calibrationSummaryModel.setEntries(cals);
            catalogModel.buildFromTargets(targets);

            QString minDate, maxDate;

            for (const QVariant &v : meta) {
                const QVariantMap map = v.toMap();

                // Only use FITS coordinates if OS location hasn't been obtained.
                // The user's current position (from OS) takes priority over where
                // they last observed.
                if (!locationService.located()) {
                    const double lat = map.value("Latitude").toString().toDouble();
                    const double lon = map.value("Longitude").toString().toDouble();
                    if (lat != 0.0 && lon != 0.0) {
                        weatherService.setLocation(lat, lon);
                        break;   // one location is enough; stop scanning FITS for it
                    }
                }

                const QString ds = map.value("Start Time UTC").toString().left(10);
                if (ds.length() == 10 && ds[0].isDigit()) {
                    if (minDate.isEmpty() || ds < minDate) minDate = ds;
                    if (maxDate.isEmpty() || ds > maxDate) maxDate = ds;
                }
            }

            if (!minDate.isEmpty())
                weatherService.fetchWeatherForDateRange(minDate, maxDate);
        });

    // ── Locate main.qml in the embedded resource system ───────────────────────
    QUrl mainQml;
    {
        QDirIterator it(QStringLiteral(":/"), QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString path = it.next();
            if (path.endsWith(QStringLiteral("/qml/main.qml"))) {
                mainQml = QUrl(QStringLiteral("qrc") + path);
                break;
            }
        }
    }

    if (mainQml.isEmpty()) {
        qCritical("Could not locate qml/main.qml in the Qt resource system.");
        return -1;
    }

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated,
        &app,
        [&mainQml](QObject *obj, const QUrl &url) {
            if (!obj && url == mainQml)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    engine.load(mainQml);
    return app.exec();
}
