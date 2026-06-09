#include "catalogservice.h"
#include <QDirIterator>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QVariantMap>

static constexpr double MAG_LIMIT  = 12.5;
static constexpr double SIZE_LIMIT = 2.0; // arcminutes

// Object type whitelist (object_definition field values from the OpenNGC catalog)
static const QStringList ALLOWED_TYPES = {
    QStringLiteral("Galaxy"),
    QStringLiteral("Globular Cluster"),
    QStringLiteral("Open Cluster"),
    QStringLiteral("Planetary Nebula"),
    QStringLiteral("Supernova Remnant"),
    QStringLiteral("Emission Nebula"),
    QStringLiteral("Reflection Nebula"),
    QStringLiteral("Dark Nebula"),
    QStringLiteral("Nebula"),
    QStringLiteral("HII Ionized region"),
    QStringLiteral("Association of Stars"),
    QStringLiteral("Cluster of Stars"),
};

CatalogService::CatalogService(QObject *parent) : QObject(parent)
{
    // Locate the catalog in the Qt resource system — try the most likely paths
    // first, then fall back to a full resource-tree search.
    QFile f;
    const QString tryPaths[] = {
        QStringLiteral(":/Meridian/src/ngc-ic-messier-catalog.json"),
        QStringLiteral(":/qt/qml/Meridian/src/ngc-ic-messier-catalog.json"),
        QStringLiteral(":/src/ngc-ic-messier-catalog.json"),
        QStringLiteral(":/ngc-ic-messier-catalog.json"),
    };
    for (const QString &p : tryPaths) {
        if (QFile::exists(p)) { f.setFileName(p); break; }
    }
    if (f.fileName().isEmpty()) {
        QDirIterator it(QStringLiteral(":/"), QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString p = it.next();
            if (p.endsWith(QStringLiteral("catalog.json"))) {
                f.setFileName(p); break;
            }
        }
    }
    if (f.fileName().isEmpty() || !f.open(QIODevice::ReadOnly))
        return;

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isArray())
        return;

    const QJsonArray arr = doc.array();
    m_entries.reserve(256);

    for (const QJsonValue &val : arr) {
        const QVariantMap map = val.toObject().toVariantMap();
        if (!passesSeestarFilter(map)) continue;

        CatalogEntry entry;
        entry.name         = map.value(QStringLiteral("name")).toString();
        entry.commonName   = map.value(QStringLiteral("common_names")).toString();
        entry.type         = map.value(QStringLiteral("object_definition")).toString();
        entry.constellation = map.value(QStringLiteral("const")).toString();
        entry.mag          = parseMag(map);
        entry.sizeArcmin   = map.value(QStringLiteral("majax")).toDouble();
        entry.raHours      = parseRaHours(map.value(QStringLiteral("ra")).toString());
        entry.decDeg       = parseDecDeg(map.value(QStringLiteral("dec")).toString());
        m_entries.append(entry);
    }

    m_ready = true;
    emit catalogLoaded();
}

double CatalogService::parseMag(const QVariantMap &obj)
{
    QVariant v = obj.value("v_mag");
    if (!v.isNull() && !v.toString().isEmpty()) {
        const double d = v.toDouble();
        if (d != 0.0) return d;
    }
    v = obj.value("b_mag");
    if (!v.isNull() && !v.toString().isEmpty()) {
        const double d = v.toDouble();
        if (d != 0.0) return d;
    }
    return 99.0;
}

double CatalogService::parseRaHours(const QString &ra)
{
    // Format: "HH:MM:SS.ss"
    const QStringList p = ra.split(':');
    if (p.size() < 2) return 0.0;
    return p[0].toDouble()
         + p[1].toDouble() / 60.0
         + (p.size() > 2 ? p[2].toDouble() : 0.0) / 3600.0;
}

double CatalogService::parseDecDeg(const QString &dec)
{
    // Format: "[+-]DD:MM:SS.s"
    const bool neg = dec.startsWith('-');
    const QString abs = (neg || dec.startsWith('+')) ? dec.mid(1) : dec;
    const QStringList p = abs.split(':');
    if (p.size() < 2) return 0.0;
    double d = p[0].toDouble()
             + p[1].toDouble() / 60.0
             + (p.size() > 2 ? p[2].toDouble() : 0.0) / 3600.0;
    return neg ? -d : d;
}

bool CatalogService::passesSeestarFilter(const QVariantMap &obj)
{
    const QString def = obj.value("object_definition").toString();
    if (!ALLOWED_TYPES.contains(def)) return false;
    if (parseMag(obj) > MAG_LIMIT) return false;
    if (obj.value("majax").toDouble() < SIZE_LIMIT) return false;
    return true;
}
