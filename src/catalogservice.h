#pragma once
#include <QObject>
#include <QList>
#include <QString>

// Typed catalog entry — exposed to C++ callers (e.g. PlannerService).
// Q_GADGET lets QML read properties if ever stored in a QVariant.
struct CatalogEntry {
    Q_GADGET
    Q_PROPERTY(QString name         MEMBER name)
    Q_PROPERTY(QString commonName   MEMBER commonName)
    Q_PROPERTY(QString type         MEMBER type)
    Q_PROPERTY(QString constellation MEMBER constellation)
    Q_PROPERTY(double  mag          MEMBER mag)
    Q_PROPERTY(double  sizeArcmin   MEMBER sizeArcmin)
    Q_PROPERTY(double  raHours      MEMBER raHours)
    Q_PROPERTY(double  decDeg       MEMBER decDeg)
public:
    QString name;
    QString commonName;
    QString type;
    QString constellation;
    double  mag        = 99.0; // 99 = unknown
    double  sizeArcmin = 0.0;
    double  raHours    = 0.0;
    double  decDeg     = 0.0;
};
Q_DECLARE_METATYPE(CatalogEntry)

// Loads the bundled NGC/IC/Messier catalog JSON and exposes the filtered
// object list to C++ callers (PlannerService) via entries().
class CatalogService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY catalogLoaded)

public:
    explicit CatalogService(QObject *parent = nullptr);

    bool ready() const { return m_ready; }
    const QList<CatalogEntry> &entries() const { return m_entries; }

signals:
    void catalogLoaded();

private:
    QList<CatalogEntry> m_entries;
    bool m_ready = false;

    static double parseMag(const QVariantMap &obj);
    static double parseRaHours(const QString &ra);
    static double parseDecDeg(const QString &dec);
    static bool   passesSeestarFilter(const QVariantMap &obj);
};
