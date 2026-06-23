#include "catalogservice.h"
#include <QDirIterator>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QVariantMap>

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

QVariantList CatalogService::brightStars()
{
    if (!m_brightStars.isEmpty())
        return m_brightStars;

    QFile f;
    const QString tryPaths[] = {
        QStringLiteral(":/Meridian/src/bright-stars.json"),
        QStringLiteral(":/qt/qml/Meridian/src/bright-stars.json"),
        QStringLiteral(":/src/bright-stars.json"),
        QStringLiteral(":/bright-stars.json"),
    };
    for (const QString &p : tryPaths) {
        if (QFile::exists(p)) { f.setFileName(p); break; }
    }
    if (f.fileName().isEmpty()) {
        QDirIterator it(QStringLiteral(":/"), QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString p = it.next();
            if (p.endsWith(QStringLiteral("bright-stars.json"))) { f.setFileName(p); break; }
        }
    }
    if (f.fileName().isEmpty() || !f.open(QIODevice::ReadOnly))
        return m_brightStars;

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isArray())
        return m_brightStars;

    const QJsonArray arr = doc.array();
    m_brightStars.reserve(arr.size());
    for (const QJsonValue &v : arr) {
        const QJsonArray s = v.toArray();
        if (s.size() < 3) continue;
        m_brightStars.append(QVariantList{ s.at(0).toDouble(), s.at(1).toDouble(), s.at(2).toDouble() });
    }
    return m_brightStars;
}

CatalogService::CatalogService(QObject *parent) : QObject(parent)
{
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
    m_entries.reserve(8192);

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
    const QStringList p = ra.split(':');
    if (p.size() < 2) return 0.0;
    return p[0].toDouble()
         + p[1].toDouble() / 60.0
         + (p.size() > 2 ? p[2].toDouble() : 0.0) / 3600.0;
}

double CatalogService::parseDecDeg(const QString &dec)
{
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
    return ALLOWED_TYPES.contains(def);
}
