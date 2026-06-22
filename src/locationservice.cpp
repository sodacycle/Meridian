#include "locationservice.h"
#include <QGeoPositionInfo>
#include <QGeoCoordinate>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>

LocationService::LocationService(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
    setStatus("Not located");
}

void LocationService::requestLocation()
{
    if (!m_posSource) {
        m_posSource = QGeoPositionInfoSource::createDefaultSource(this);
        if (m_posSource) {
            connect(m_posSource, &QGeoPositionInfoSource::positionUpdated,
                    this, &LocationService::onPositionUpdated);
            connect(m_posSource, &QGeoPositionInfoSource::errorOccurred,
                    this, &LocationService::onPositioningError);
        }
    }

    if (m_posSource) {
        setStatus("Requesting…");
        m_posSource->requestUpdate(8000);
    } else {
        tryIPFallback();
    }
}

void LocationService::onPositionUpdated(const QGeoPositionInfo &info)
{
    if (!info.coordinate().isValid()) {
        tryIPFallback();
        return;
    }
    deliver(info.coordinate().latitude(), info.coordinate().longitude(), "GPS");
}

void LocationService::onPositioningError(QGeoPositionInfoSource::Error error)
{
    Q_UNUSED(error)
    if (!m_ipPending)
        tryIPFallback();
}

void LocationService::tryIPFallback()
{
    if (m_ipPending) return;
    m_ipPending = true;
    setStatus("Requesting via IP…");

    QNetworkReply *reply = m_network->get(
        QNetworkRequest(QUrl("https://ipinfo.io/json")));

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        m_ipPending = false;
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            setStatus("Location unavailable");
            return;
        }

        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        const QString locStr  = obj["loc"].toString();
        const QStringList parts = locStr.split(',');
        if (parts.size() != 2) { setStatus("Location unavailable"); return; }

        bool okLat, okLon;
        const double lat = parts[0].toDouble(&okLat);
        const double lon = parts[1].toDouble(&okLon);
        if (!okLat || !okLon) { setStatus("Location unavailable"); return; }

        const QString city = obj["city"].toString();
        deliver(lat, lon, "IP", city);
    });
}

void LocationService::deliver(double lat, double lon,
                               const QString &sourceLabel,
                               const QString &city)
{
    m_located = true;
    m_city    = city;
    emit locatedChanged();

    QString s = QString("Located via %1").arg(sourceLabel);
    if (!city.isEmpty()) s += QString(" (%1)").arg(city);
    setStatus(s);

    emit locationObtained(lat, lon);
}

void LocationService::setStatus(const QString &s)
{
    if (m_status == s) return;
    m_status = s;
    emit statusChanged();
}
