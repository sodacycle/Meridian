#pragma once
#include <QObject>
#include <QGeoPositionInfoSource>
#include <QNetworkAccessManager>

// Resolves the user's current position using the OS location stack (GeoClue2)
// and falls back to IP geolocation when the system stack is unavailable.
class LocationService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString status  READ status  NOTIFY statusChanged)
    Q_PROPERTY(bool    located READ located NOTIFY locatedChanged)
    Q_PROPERTY(QString city    READ city    NOTIFY locatedChanged)

public:
    explicit LocationService(QObject *parent = nullptr);

    QString status()  const { return m_status;  }
    bool    located() const { return m_located; }
    QString city()    const { return m_city;    }

    Q_INVOKABLE void requestLocation();

signals:
    void locationObtained(double lat, double lon);
    void statusChanged();
    void locatedChanged();

private slots:
    void onPositionUpdated(const QGeoPositionInfo &info);
    void onPositioningError(QGeoPositionInfoSource::Error error);

private:
    void tryIPFallback();
    void setStatus(const QString &s);
    void deliver(double lat, double lon, const QString &sourceLabel,
                 const QString &city = QString());

    QGeoPositionInfoSource *m_posSource = nullptr;
    QNetworkAccessManager  *m_network;
    QString m_status;
    QString m_city;
    bool    m_located   = false;
    bool    m_ipPending = false;
};
