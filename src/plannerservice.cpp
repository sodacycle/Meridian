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

    // Step 1: filter
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

    // Step 2: sort (if active)
    if (!m_sortCol.isEmpty()) {
        const QString col = m_sortCol;
        const bool    asc = m_sortAsc;
        std::stable_sort(m_entries.begin(), m_entries.end(),
            [&](const PlannerEntry &a, const PlannerEntry &b) {
                bool less = false;
                if (col == QLatin1String("Name")) {
                    const QString na = a.commonName.isEmpty() ? a.name : a.commonName;
                    const QString nb = b.commonName.isEmpty() ? b.name : b.commonName;
                    less = na.compare(nb, Qt::CaseInsensitive) < 0;
                } else if (col == QLatin1String("Type")) {
                    less = a.type.compare(b.type, Qt::CaseInsensitive) < 0;
                } else if (col == QLatin1String("Con")) {
                    less = a.constellation.compare(b.constellation, Qt::CaseInsensitive) < 0;
                } else if (col == QLatin1String("Mag")) {
                    less = a.mag < b.mag;
                } else if (col == QLatin1String("Size")) {
                    less = a.sizeArcmin < b.sizeArcmin;
                } else if (col == QLatin1String("Peak Alt")) {
                    less = a.peakAlt < b.peakAlt;
                } else if (col == QLatin1String("Window")) {
                    less = a.windowH < b.windowH;
                } else if (col == QLatin1String("UTC Visible")) {
                    less = a.riseUtcH < b.riseUtcH;
                }
                return asc ? less : !less;
            });
    }

    endResetModel();
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

double PlannerService::azimuthDeg(double raH, double decDeg, double latDeg, double lstDeg) const
{
    static constexpr double DEG2RAD = M_PI / 180.0;
    const double ha  = std::fmod(std::fmod(lstDeg - raH * 15.0, 360.0) + 360.0, 360.0);
    const double haR = ha  * DEG2RAD;
    const double dR  = decDeg * DEG2RAD;
    const double lR  = latDeg * DEG2RAD;
    // Azimuth from South, positive to the West (Meeus); convert to compass
    // bearing measured from North, increasing eastward, in [0, 360).
    const double aSouth = std::atan2(std::sin(haR),
                                     std::cos(haR) * std::sin(lR) - std::tan(dR) * std::cos(lR));
    double az = aSouth / DEG2RAD + 180.0;
    az = std::fmod(std::fmod(az, 360.0) + 360.0, 360.0);
    return az;
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
    // Reference point: 23:00 local time on the selected night (~local midnight).
    QDateTime localMidnight = QDateTime::currentDateTime();
    localMidnight.setTime(QTime(23, 0, 0));
    localMidnight = localMidnight.addDays(m_nightOffset);

    const double jdMid  = toJD(static_cast<double>(localMidnight.toMSecsSinceEpoch()));
    const double lstMid = lst(jdMid, m_lon);   // degrees at midnight reference

    const QTime utcMidTime = localMidnight.toUTC().time();
    const double utcMidH   = utcMidTime.hour()
                           + utcMidTime.minute() / 60.0
                           + utcMidTime.second() / 3600.0;

    // Observable night = midnight ± kNightHalf hours.
    // Covers roughly 17:00–05:00 local solar time — a conservative darkness window
    // valid for most latitudes and seasons. Prevents objects that only rise during
    // the day from appearing in the list.
    static constexpr double kNightHalf = 6.0;

    // Convert a target LST (degrees) to solar hours offset from midnight.
    // Negative = before midnight, positive = after midnight.
    auto lstToHrOffset = [&](double lstTargetDeg) -> double {
        double d = std::fmod(lstTargetDeg - lstMid + 360.0, 360.0);
        if (d > 180.0) d -= 360.0;
        return d / 15.04107;  // sidereal ° → solar hours
    };

    const double nightStartUtc = std::fmod(utcMidH - kNightHalf + 24.0, 24.0);

    QList<PlannerEntry> results;
    results.reserve(m_catalog->entries().size());

    for (const CatalogEntry &ce : m_catalog->entries()) {

        // Hour angle at which the object crosses the 15° observation horizon.
        //   < 0  → never clears 15° from this latitude  (skip)
        //   ≥ 24 → circumpolar above 15° (always up)
        const double haH = riseSetHAHours(ce.decDeg, m_lat);
        if (haH < 0.0) continue;

        const bool circumpolar = (haH >= 24.0);

        // ── Rise / set UTC times ──────────────────────────────────────────────
        double riseUtcH = 0.0, setUtcH = 0.0;
        if (!circumpolar) {
            const double lstRiseDeg = std::fmod(std::fmod((ce.raHours - haH) * 15.0, 360.0) + 360.0, 360.0);
            const double lstSetDeg  = std::fmod(std::fmod((ce.raHours + haH) * 15.0, 360.0) + 360.0, 360.0);
            riseUtcH = std::fmod(utcMidH + lstToHrOffset(lstRiseDeg) + 24.0, 24.0);
            setUtcH  = std::fmod(utcMidH + lstToHrOffset(lstSetDeg)  + 24.0, 24.0);
        }

        // ── Night-overlap check & nighttime window ────────────────────────────
        // Normalize the object's visibility interval relative to nightStart so
        // that the darkness window maps to [0, kNightHalf*2].  Subtracting 24
        // when relRise > 12 handles the "already risen before nightStart" case.
        double nightWindowH;
        if (circumpolar) {
            nightWindowH = kNightHalf * 2.0;
        } else {
            const double objSpan = std::fmod(setUtcH - riseUtcH + 24.0, 24.0);
            double relRise = std::fmod(riseUtcH - nightStartUtc + 24.0, 24.0);
            if (relRise > 12.0) relRise -= 24.0;   // object was up before night started
            const double relSet = relRise + objSpan;

            // No overlap with darkness window [0, kNightHalf*2]:
            if (relRise >= kNightHalf * 2.0 || relSet <= 0.0) continue;

            nightWindowH = std::min(relSet, kNightHalf * 2.0) - std::max(relRise, 0.0);
        }

        // ── Peak altitude during tonight's darkness window ────────────────────
        // The absolute maximum is at upper transit (HA = 0).  If transit falls
        // inside the window we can use it directly; otherwise the maximum during
        // the night is at whichever window boundary is closest to transit.
        const double transitAlt    = 90.0 - std::abs(m_lat - ce.decDeg);
        const double transitOffset = lstToHrOffset(std::fmod(ce.raHours * 15.0, 360.0));

        double nightPeakAlt;
        if (std::abs(transitOffset) <= kNightHalf) {
            nightPeakAlt = transitAlt;
        } else {
            const double boundaryOffset = (transitOffset > 0.0) ? kNightHalf : -kNightHalf;
            nightPeakAlt = altitudeDeg(ce.raHours, ce.decDeg, m_lat,
                                       lst(jdMid + boundaryOffset / 24.0, m_lon));
        }

        if (nightPeakAlt < 15.0) continue;  // clears latitude but not during this night

        // ── Viewable-area filter ──────────────────────────────────────────────
        // Keep the object only if, at some point during the darkness window, it
        // sits in an enabled compass sector and above the obstruction floor.
        if (m_viewFilter) {
            const double floorDeg = std::max(15.0, m_viewMinAlt);
            bool reachable = false;
            for (double t = -kNightHalf; t <= kNightHalf + 1e-9; t += 0.25) {
                const double lstT = lst(jdMid + t / 24.0, m_lon);
                if (altitudeDeg(ce.raHours, ce.decDeg, m_lat, lstT) < floorDeg)
                    continue;
                const double azT = azimuthDeg(ce.raHours, ce.decDeg, m_lat, lstT);
                const int idx = static_cast<int>(
                    std::lround(std::fmod(std::fmod(azT, 360.0) + 360.0, 360.0) / 45.0)) % 8;
                if (m_viewSectors.value(idx, true)) { reachable = true; break; }
            }
            if (!reachable) continue;
        }

        // ── Build entry ───────────────────────────────────────────────────────
        PlannerEntry pe;
        pe.name          = ce.name;
        pe.commonName    = ce.commonName;
        pe.type          = ce.type;
        pe.constellation = ce.constellation;
        pe.mag           = ce.mag;
        pe.sizeArcmin    = ce.sizeArcmin;
        pe.raHours       = ce.raHours;
        pe.decDeg        = ce.decDeg;
        pe.altAtMidnight = altitudeDeg(ce.raHours, ce.decDeg, m_lat, lstMid);
        pe.peakAlt       = nightPeakAlt;  // max altitude reachable this night
        pe.circumpolar   = circumpolar;
        pe.windowH       = nightWindowH;  // hours above 15° within darkness window
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
