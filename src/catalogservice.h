#pragma once
#include <QObject>
#include <QList>
#include <QString>
#include <QVariantList>

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
    double  mag        = 99.0;
    double  sizeArcmin = 0.0;
    double  raHours    = 0.0;
    double  decDeg     = 0.0;
};
Q_DECLARE_METATYPE(CatalogEntry)

class CatalogService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY catalogLoaded)

public:
    explicit CatalogService(QObject *parent = nullptr);

    bool ready() const { return m_ready; }
    const QList<CatalogEntry> &entries() const { return m_entries; }

    Q_INVOKABLE QVariantList brightStars();

signals:
    void catalogLoaded();

private:
    QList<CatalogEntry> m_entries;
    QVariantList m_brightStars;
    bool m_ready = false;

    static double parseMag(const QVariantMap &obj);
    static double parseRaHours(const QString &ra);
    static double parseDecDeg(const QString &dec);
    static bool   passesSeestarFilter(const QVariantMap &obj);
};
