#include "plannerservice.h"
#include <QDateTime>
#include <algorithm>
#include <cmath>

// ── VisibleObjectsModel ───────────────────────────────────────────────────────

VisibleObjectsModel::VisibleObjectsModel(QObject *parent)
    : QAbstractListModel(parent)
{}

int VisibleObjectsModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_entries.size();
}

QHash<int, QByteArray> VisibleObjectsModel::roleNames() const
{
    return {
        { NameRole,          "name"          },
        { CommonNameRole,    "commonName"    },
        { TypeRole,          "type"          },
        { ConstellationRole, "constellation" },
        { MagRole,           "mag"           },
        { SizeArcminRole,    "sizeArcmin"    },
        { RaHoursRole,       "raHours"       },
        { DecDegRole,        "decDeg"        },
        { AltAtMidnightRole, "altAtMidnight" },
        { PeakAltRole,       "peakAlt"       },
        { WindowHRole,       "windowH"       },
        { CircumpolarRole,   "circumpolar"   },
    };
}

QVariant VisibleObjectsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size())
        return {};
    const PlannerEntry &e = m_entries.at(index.row());
    switch (role) {
    case NameRole:          return e.name;
    case CommonNameRole:    return e.commonName;
    case TypeRole:          return e.type;
    case ConstellationRole: return e.constellation;
    case MagRole:           return e.mag;
    case SizeArcminRole:    return e.sizeArcmin;
    case RaHoursRole:       return e.raHours;
    case DecDegRole:        return e.decDeg;
    case AltAtMidnightRole: return e.altAtMidnight;
    case PeakAltRole:       return e.peakAlt;
    case WindowHRole:       return e.windowH;
    case CircumpolarRole:   return e.circumpolar;
    default:                return {};
    }
}

void VisibleObjectsModel::setEntries(const QList<PlannerEntry> &entries)
{
    beginResetModel();
    m_entries = entries;
    endResetModel();
}

PlannerEntry VisibleObjectsModel::entryAt(int index) const
{
    if (index < 0 || index >= m_entries.size()) return {};
    return m_entries.at(index);
}

// ── PlannerService ────────────────────────────────────────────────────────────

PlannerService::PlannerService(CatalogService *catalog, QObject *parent)
    : QObject(parent)
    , m_catalog(catalog)
    , m_model(new VisibleObjectsModel(this))
{
    // If the catalog was already loaded synchronously before this service
    // was constructed, record that we're ready now.
    if (m_catalog->ready())
        m_ready = true;

    // Recompute whenever the catalog (re)loads — also handles async future loads.
    connect(m_catalog, &CatalogService::catalogLoaded, this, [this]() {
        if (!m_ready) {
            m_ready = true;
            emit readyChanged();
        }
        // Recompute if a location has already been set.
        if (m_lat != 0.0 || m_lon != 0.0)
            doCompute();
    });
}

void PlannerService::compute(double lat, double lon, int nightOffset)
{
    m_lat        = lat;
    m_lon        = lon;
    m_nightOffset = nightOffset;
    if (m_catalog->ready())
        doCompute();
}

// ── Astronomical math (ported from PlannerWindow.qml JS) ─────────────────────

double PlannerService::toJD(double epochMs) const
{
    return epochMs / 86400000.0 + 2440587.5;
}

double PlannerService::gmst(double jd) const
{
    const double T = (jd - 2451545.0) / 36525.0;
    double g = 280.46061837
             + 360.98564736629 * (jd - 2451545.0)
             + 0.000387933 * T * T
             - T * T * T / 38710000.0;
    return std::fmod(std::fmod(g, 360.0) + 360.0, 360.0);
}

double PlannerService::lst(double jd, double lonDeg) const
{
    const double l = gmst(jd) + lonDeg;
    return std::fmod(std::fmod(l, 360.0) + 360.0, 360.0);
}

double PlannerService::altitudeDeg(double raH, double decDeg, double latDeg, double lstDeg) const
{
    static constexpr double DEG2RAD = M_PI / 180.0;
    const double ha  = std::fmod(std::fmod(lstDeg - raH * 15.0, 360.0) + 360.0, 360.0);
    const double haR = ha  * DEG2RAD;
    const double dR  = decDeg * DEG2RAD;
    const double lR  = latDeg * DEG2RAD;
    const double sinAlt = std::sin(lR) * std::sin(dR)
                        + std::cos(lR) * std::cos(dR) * std::cos(haR);
    return std::asin(std::max(-1.0, std::min(1.0, sinAlt))) / DEG2RAD;
}

double PlannerService::riseSetHAHours(double decDeg, double latDeg, double horizonDeg) const
{
    static constexpr double DEG2RAD = M_PI / 180.0;
    const double h = horizonDeg * DEG2RAD;
    const double d = decDeg     * DEG2RAD;
    const double L = latDeg     * DEG2RAD;

    const double denom = std::cos(L) * std::cos(d);
    if (std::abs(denom) < 1e-10) {
        // At or near a pole — decide based on numerator sign
        return (std::sin(h) - std::sin(L) * std::sin(d)) > 0.0 ? -1.0 : 24.0;
    }
    const double cosHA = (std::sin(h) - std::sin(L) * std::sin(d)) / denom;
    if (cosHA >  1.0) return -1.0;  // never clears horizon
    if (cosHA < -1.0) return 24.0;  // circumpolar
    return std::acos(cosHA) / DEG2RAD / 15.0;
}

void PlannerService::doCompute()
{
    // Local midnight for the selected night (23:00 local time on that date)
    QDateTime localMidnight = QDateTime::currentDateTime();
    localMidnight.setTime(QTime(23, 0, 0));
    localMidnight = localMidnight.addDays(m_nightOffset);

    const double jd     = toJD(static_cast<double>(localMidnight.toMSecsSinceEpoch()));
    const double lstDeg = lst(jd, m_lon);

    QList<PlannerEntry> results;
    results.reserve(m_catalog->entries().size());

    for (const CatalogEntry &ce : m_catalog->entries()) {
        const double haH = riseSetHAHours(ce.decDeg, m_lat);
        if (haH < 0.0) continue; // never clears 15° at this latitude

        const double peakAlt = 90.0 - std::abs(m_lat - ce.decDeg);
        if (peakAlt < 15.0) continue; // never gets high enough

        PlannerEntry pe;
        pe.name          = ce.name;
        pe.commonName    = ce.commonName;
        pe.type          = ce.type;
        pe.constellation = ce.constellation;
        pe.mag           = ce.mag;
        pe.sizeArcmin    = ce.sizeArcmin;
        pe.raHours       = ce.raHours;
        pe.decDeg        = ce.decDeg;
        pe.peakAlt       = peakAlt;
        pe.circumpolar   = (haH >= 24.0);
        pe.windowH       = pe.circumpolar ? 24.0 : haH * 2.0;
        pe.altAtMidnight = altitudeDeg(ce.raHours, ce.decDeg, m_lat, lstDeg);

        results.append(pe);
    }

    std::sort(results.begin(), results.end(),
              [](const PlannerEntry &a, const PlannerEntry &b) {
                  return a.peakAlt > b.peakAlt;
              });

    m_model->setEntries(results);
}
