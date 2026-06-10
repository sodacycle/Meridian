#pragma once
#include <QObject>
#include <QAbstractListModel>
#include <QList>
#include <QString>
#include "catalogservice.h"

// ── PlannerEntry ─────────────────────────────────────────────────────────────
// Q_GADGET value type: one computed observation-planner object.
// All fields are Q_PROPERTYs so QML can read them when the value is stored
// in a property var (e.g. plannerWindow.selectedObj).
struct PlannerEntry {
    Q_GADGET
    Q_PROPERTY(QString name          MEMBER name)
    Q_PROPERTY(QString commonName    MEMBER commonName)
    Q_PROPERTY(QString type          MEMBER type)
    Q_PROPERTY(QString constellation MEMBER constellation)
    Q_PROPERTY(double  mag           MEMBER mag)
    Q_PROPERTY(double  sizeArcmin    MEMBER sizeArcmin)
    Q_PROPERTY(double  raHours       MEMBER raHours)
    Q_PROPERTY(double  decDeg        MEMBER decDeg)
    Q_PROPERTY(double  altAtMidnight MEMBER altAtMidnight)
    Q_PROPERTY(double  peakAlt       MEMBER peakAlt)
    Q_PROPERTY(double  windowH       MEMBER windowH)
    Q_PROPERTY(bool    circumpolar   MEMBER circumpolar)
    Q_PROPERTY(double  riseUtcH      MEMBER riseUtcH)
    Q_PROPERTY(double  setUtcH       MEMBER setUtcH)
public:
    QString name;
    QString commonName;
    QString type;
    QString constellation;
    double  mag          = 99.0;
    double  sizeArcmin   = 0.0;
    double  raHours      = 0.0;
    double  decDeg       = 0.0;
    double  altAtMidnight = 0.0;
    double  peakAlt      = 0.0;
    double  windowH      = 0.0;
    bool    circumpolar  = false;
    double  riseUtcH     = 0.0;
    double  setUtcH      = 0.0;
};
Q_DECLARE_METATYPE(PlannerEntry)

// ── VisibleObjectsModel ───────────────────────────────────────────────────────
// QAbstractListModel wrapping a QList<PlannerEntry>.  Every PlannerEntry field
// is exposed as a named role so QML required-property delegates work directly.
class VisibleObjectsModel : public QAbstractListModel
{
    Q_OBJECT
public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        CommonNameRole,
        TypeRole,
        ConstellationRole,
        MagRole,
        SizeArcminRole,
        RaHoursRole,
        DecDegRole,
        AltAtMidnightRole,
        PeakAltRole,
        WindowHRole,
        CircumpolarRole,
        RiseUtcHRole,
        SetUtcHRole
    };

    explicit VisibleObjectsModel(QObject *parent = nullptr);

    int     rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setEntries(const QList<PlannerEntry> &entries);
    Q_INVOKABLE PlannerEntry entryAt(int index) const;
    Q_INVOKABLE void sortBy(const QString &column, bool ascending);
    Q_INVOKABLE void setFilter(const QString &text);

private:
    void rebuild();

    QList<PlannerEntry> m_entries;     // displayed (filtered + sorted)
    QList<PlannerEntry> m_allEntries;  // full set from last compute
    QString m_filter;
    QString m_sortCol;
    bool    m_sortAsc = false;
};

// ── PlannerService ────────────────────────────────────────────────────────────
// Runs the astronomical visibility math in C++ and populates VisibleObjectsModel.
class PlannerService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(VisibleObjectsModel* objects READ objects CONSTANT)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)

public:
    explicit PlannerService(CatalogService *catalog, QObject *parent = nullptr);

    VisibleObjectsModel *objects() const { return m_model; }
    bool ready() const { return m_ready; }

    // Called from QML when location or night changes
    Q_INVOKABLE void compute(double lat, double lon, int nightOffset);

    // Astronomical helpers — also called directly from QML Canvas drawing
    Q_INVOKABLE double toJD(double epochMs) const;
    Q_INVOKABLE double lst(double jd, double lonDeg) const;
    Q_INVOKABLE double altitudeDeg(double raH, double decDeg, double latDeg, double lstDeg) const;

signals:
    void readyChanged();

private:
    double gmst(double jd) const;
    double riseSetHAHours(double decDeg, double latDeg, double horizonDeg = 15.0) const;
    void   doCompute();

    CatalogService      *m_catalog;
    VisibleObjectsModel *m_model;
    bool   m_ready      = false;
    double m_lat        = 0.0;
    double m_lon        = 0.0;
    int    m_nightOffset = 0;
};
