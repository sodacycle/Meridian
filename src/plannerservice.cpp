#include "plannerservice.h"
#include <QDateTime>
#include <algorithm>
#include <cmath>

static constexpr double kDeg2Rad = M_PI / 180.0;

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
        { RiseUtcHRole,      "riseUtcH"      },
        { SetUtcHRole,       "setUtcH"       },
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
    case RiseUtcHRole:      return e.riseUtcH;
    case SetUtcHRole:       return e.setUtcH;
    default:                return {};
    }
}

void VisibleObjectsModel::setEntries(const QList<PlannerEntry> &entries)
{
    m_allEntries = entries;
    rebuild();
}

PlannerEntry VisibleObjectsModel::entryAt(int index) const
{
    if (index < 0 || index >= m_entries.size()) return {};
    return m_entries.at(index);
}

void VisibleObjectsModel::setFilter(const QString &text)
{
    if (m_filter == text) return;
    m_filter = text;
    rebuild();
}

void VisibleObjectsModel::sortBy(const QString &column, bool ascending)
{
    m_sortCol = column;
    m_sortAsc = ascending;
    rebuild();
}

void VisibleObjectsModel::rebuild()
{
    beginResetModel();

    if (m_filter.isEmpty()) {
        m_entries = m_allEntries;
    } else {
        const QString f = m_filter.toLower();
        m_entries.clear();
        for (const PlannerEntry &e : m_allEntries) {
            if (e.name.toLower().contains(f) || e.commonName.toLower().contains(f))
                m_entries.append(e);
        }
    }

    if (!m_sortCol.isEmpty()) {
        const QString col = m_sortCol;
        const bool    asc = m_sortAsc;
        std::stable_sort(m_entries.begin(), m_entries.end(),
            [&](const PlannerEntry &a, const PlannerEntry &b) {
                bool less = false;
                if      (col == QLatin1String("Name"))    {
                    const QString na = a.commonName.isEmpty() ? a.name : a.commonName;
                    const QString nb = b.commonName.isEmpty() ? b.name : b.commonName;
                    less = na.compare(nb, Qt::CaseInsensitive) < 0;
                } else if (col == QLatin1String("Type"))       { less = a.type.compare(b.type, Qt::CaseInsensitive) < 0; }
                  else if (col == QLatin1String("Con"))        { less = a.constellation.compare(b.constellation, Qt::CaseInsensitive) < 0; }
                  else if (col == QLatin1String("Mag"))        { less = a.mag < b.mag; }
                  else if (col == QLatin1String("Size"))       { less = a.sizeArcmin < b.sizeArcmin; }
                  else if (col == QLatin1String("Peak Alt"))   { less = a.peakAlt < b.peakAlt; }
                  else if (col == QLatin1String("Window"))     { less = a.windowH < b.windowH; }
                  else if (col == QLatin1String("UTC Visible")){ less = a.riseUtcH < b.riseUtcH; }
                return asc ? less : !less;
            });
    }

    endResetModel();
}

PlannerService::PlannerService(CatalogService *catalog, QObject *parent)
    : QObject(parent)
    , m_catalog(catalog)
    , m_model(new VisibleObjectsModel(this))
{
    if (m_catalog->ready())
        m_ready = true;

    connect(m_catalog, &CatalogService::catalogLoaded, this, [this]() {
        if (!m_ready) {
            m_ready = true;
            emit readyChanged();
        }
        if (m_lat != 0.0 || m_lon != 0.0)
            doCompute();
    });
}

void PlannerService::compute(double lat, double lon, int nightOffset)
{
    m_lat         = lat;
    m_lon         = lon;
    m_nightOffset = nightOffset;
    if (m_catalog->ready())
        doCompute();
}

void PlannerService::setViewFilter(const QVariantList &sectors, double minAltDeg, bool enabled)
{
    m_viewFilter = enabled;
    m_viewMinAlt = minAltDeg;
    if (sectors.size() == 8) {
        for (int i = 0; i < 8; ++i)
            m_viewSectors[i] = sectors.at(i).toBool();
    }
    if (m_catalog->ready() && (m_lat != 0.0 || m_lon != 0.0))
        doCompute();
}

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
    const double haDeg  = std::fmod(std::fmod(lstDeg - raH * 15.0, 360.0) + 360.0, 360.0);
    const double haRad  = haDeg  * kDeg2Rad;
    const double decRad = decDeg * kDeg2Rad;
    const double latRad = latDeg * kDeg2Rad;
    const double sinAlt = std::sin(latRad) * std::sin(decRad)
                        + std::cos(latRad) * std::cos(decRad) * std::cos(haRad);
    return std::asin(std::max(-1.0, std::min(1.0, sinAlt))) / kDeg2Rad;
}

double PlannerService::azimuthDeg(double raH, double decDeg, double latDeg, double lstDeg) const
{
    const double haDeg      = std::fmod(std::fmod(lstDeg - raH * 15.0, 360.0) + 360.0, 360.0);
    const double haRad      = haDeg  * kDeg2Rad;
    const double decRad     = decDeg * kDeg2Rad;
    const double latRad     = latDeg * kDeg2Rad;
    const double azSouthRad = std::atan2(std::sin(haRad),
                                         std::cos(haRad) * std::sin(latRad) - std::tan(decRad) * std::cos(latRad));
    return std::fmod(azSouthRad / kDeg2Rad + 540.0, 360.0);
}

double PlannerService::riseSetHAHours(double decDeg, double latDeg, double horizonDeg) const
{
    const double horizonRad = horizonDeg * kDeg2Rad;
    const double decRad     = decDeg     * kDeg2Rad;
    const double latRad     = latDeg     * kDeg2Rad;

    const double denom = std::cos(latRad) * std::cos(decRad);
    if (std::abs(denom) < 1e-10)
        return (std::sin(horizonRad) - std::sin(latRad) * std::sin(decRad)) > 0.0 ? -1.0 : 24.0;

    const double cosHA = (std::sin(horizonRad) - std::sin(latRad) * std::sin(decRad)) / denom;
    if (cosHA >  1.0) return -1.0;
    if (cosHA < -1.0) return 24.0;
    return std::acos(cosHA) / kDeg2Rad / 15.0;
}

void PlannerService::doCompute()
{
    static constexpr qint64 kDayMs                   = Q_INT64_C(86400000);
    static constexpr double kNightHalfHours           = 6.0;
    static constexpr double kSiderealDegPerSolarHour  = 15.04107;

    const qint64 utcNowMs    = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    const qint64 lonOffsetMs = static_cast<qint64>(m_lon / 15.0 * 3600000.0);
    const qint64 localNowMs  = utcNowMs + lonOffsetMs;
    const qint64 midnightMs  = (localNowMs / kDayMs) * kDayMs - lonOffsetMs
                               + static_cast<qint64>(m_nightOffset) * kDayMs;

    const double midnightJD    = toJD(static_cast<double>(midnightMs));
    const double lstAtMidnight = lst(midnightJD, m_lon);
    const double midnightUtcH  = static_cast<double>(
        ((midnightMs % kDayMs) + kDayMs) % kDayMs) / 3600000.0;

    auto lstToMidnightOffsetH = [&](double targetLstDeg) -> double {
        double delta = std::fmod(targetLstDeg - lstAtMidnight + 360.0, 360.0);
        if (delta > 180.0) delta -= 360.0;
        return delta / kSiderealDegPerSolarHour;
    };

    const double nightStartUtcH = std::fmod(midnightUtcH - kNightHalfHours + 24.0, 24.0);

    QList<PlannerEntry> results;
    results.reserve(m_catalog->entries().size());

    for (const CatalogEntry &ce : m_catalog->entries()) {

        const double riseSetHaH = riseSetHAHours(ce.decDeg, m_lat);
        if (riseSetHaH < 0.0) continue;

        const bool circumpolar = (riseSetHaH >= 24.0);

        double riseUtcH = 0.0, setUtcH = 0.0;
        if (!circumpolar) {
            const double lstAtRise = std::fmod(std::fmod((ce.raHours - riseSetHaH) * 15.0, 360.0) + 360.0, 360.0);
            const double lstAtSet  = std::fmod(std::fmod((ce.raHours + riseSetHaH) * 15.0, 360.0) + 360.0, 360.0);
            riseUtcH = std::fmod(midnightUtcH + lstToMidnightOffsetH(lstAtRise) + 24.0, 24.0);
            setUtcH  = std::fmod(midnightUtcH + lstToMidnightOffsetH(lstAtSet)  + 24.0, 24.0);
        }

        double nightWindowH;
        if (circumpolar) {
            nightWindowH = kNightHalfHours * 2.0;
        } else {
            const double visibilitySpanH = std::fmod(setUtcH - riseUtcH + 24.0, 24.0);
            double relativeRiseH = std::fmod(riseUtcH - nightStartUtcH + 24.0, 24.0);
            if (relativeRiseH > 12.0) relativeRiseH -= 24.0;
            const double relativeSetH = relativeRiseH + visibilitySpanH;

            if (relativeRiseH >= kNightHalfHours * 2.0 || relativeSetH <= 0.0) continue;

            nightWindowH = std::min(relativeSetH, kNightHalfHours * 2.0)
                         - std::max(relativeRiseH, 0.0);
        }

        const double transitAlt     = 90.0 - std::abs(m_lat - ce.decDeg);
        const double transitOffsetH = lstToMidnightOffsetH(std::fmod(ce.raHours * 15.0, 360.0));

        double nightPeakAlt;
        if (std::abs(transitOffsetH) <= kNightHalfHours) {
            nightPeakAlt = transitAlt;
        } else {
            const double windowBoundaryH = (transitOffsetH > 0.0) ? kNightHalfHours : -kNightHalfHours;
            nightPeakAlt = altitudeDeg(ce.raHours, ce.decDeg, m_lat,
                                       lst(midnightJD + windowBoundaryH / 24.0, m_lon));
        }

        if (nightPeakAlt < 15.0) continue;

        if (m_viewFilter) {
            const double floorDeg = std::max(15.0, m_viewMinAlt);
            bool reachable = false;
            for (double t = -kNightHalfHours; t <= kNightHalfHours + 1e-9; t += 0.25) {
                const double lstAtT = lst(midnightJD + t / 24.0, m_lon);
                if (altitudeDeg(ce.raHours, ce.decDeg, m_lat, lstAtT) < floorDeg) continue;
                const double azAtT = azimuthDeg(ce.raHours, ce.decDeg, m_lat, lstAtT);
                const int sectorIdx = static_cast<int>(
                    std::lround(std::fmod(std::fmod(azAtT, 360.0) + 360.0, 360.0) / 45.0)) % 8;
                if (m_viewSectors.value(sectorIdx, true)) { reachable = true; break; }
            }
            if (!reachable) continue;
        }

        PlannerEntry pe;
        pe.name          = ce.name;
        pe.commonName    = ce.commonName;
        pe.type          = ce.type;
        pe.constellation = ce.constellation;
        pe.mag           = ce.mag;
        pe.sizeArcmin    = ce.sizeArcmin;
        pe.raHours       = ce.raHours;
        pe.decDeg        = ce.decDeg;
        pe.altAtMidnight = altitudeDeg(ce.raHours, ce.decDeg, m_lat, lstAtMidnight);
        pe.peakAlt       = nightPeakAlt;
        pe.circumpolar   = circumpolar;
        pe.windowH       = nightWindowH;
        pe.riseUtcH      = riseUtcH;
        pe.setUtcH       = setUtcH;
        results.append(pe);
    }

    std::sort(results.begin(), results.end(),
              [](const PlannerEntry &a, const PlannerEntry &b) {
                  return a.peakAlt > b.peakAlt;
              });

    m_model->setEntries(results);
}
