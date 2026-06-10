#pragma once
#include <QObject>
#include <QNetworkAccessManager>

// Fetches sky quality data from lightpollutionmap.info and converts to Bortle class.
// Call fetch(lat, lon) whenever a new location is obtained; properties update async.
class LightPollutionService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int     bortleClass  READ bortleClass  NOTIFY dataChanged)
    Q_PROPERTY(double  sqm         READ sqm          NOTIFY dataChanged)
    Q_PROPERTY(QString bortleLabel READ bortleLabel  NOTIFY dataChanged)
    Q_PROPERTY(QString status      READ status       NOTIFY statusChanged)
    Q_PROPERTY(bool    available   READ available    NOTIFY dataChanged)

public:
    explicit LightPollutionService(QObject *parent = nullptr);

    int     bortleClass() const { return m_bortle;    }
    double  sqm()         const { return m_sqm;       }
    QString bortleLabel() const;
    QString status()      const { return m_status;    }
    bool    available()   const { return m_available; }

    Q_INVOKABLE void fetch(double lat, double lon);

signals:
    void dataChanged();
    void statusChanged();

private:
    void setStatus(const QString &s);
    void applyBortle(int bortle, double sqm, bool estimated);
    static int sqmToBortle(double sqm);
    static int estimateFromCoords(double lat, double lon);

    QNetworkAccessManager *m_network;
    int    m_bortle    = 0;
    double m_sqm       = 0.0;
    bool   m_available = false;
    bool   m_fetching  = false;
    QString m_status;
};
