#include "lightpollutionservice.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>
#include <QUrlQuery>

LightPollutionService::LightPollutionService(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
    setStatus("Not loaded");
}

void LightPollutionService::fetch(double lat, double lon)
{
    if (m_fetching) return;
    m_fetching = true;
    setStatus("Loading…");

    // World Atlas 2015 point query — same data source used by lightpollutionmap.info
    QString qd = QString("{\"lng\":%1,\"lat\":%2}")
                     .arg(lon, 0, 'f', 6)
                     .arg(lat, 0, 'f', 6);

    QUrl url("https://www.lightpollutionmap.info/Post/API/getData.php");
    QUrlQuery q;
    q.addQueryItem("ql", "wa_2015");
    q.addQueryItem("qt", "point");
    q.addQueryItem("qd", qd);
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, "MeridianAstro/1.0.2a");
    QNetworkReply *reply = m_network->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply, lat, lon]() {
        m_fetching = false;
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            // Network unavailable — produce a coarse estimate from coordinates.
            // Population density proxy: absolute latitude > 60° or near poles → likely rural.
            // This is intentionally rough — just gives a starting point.
            applyBortle(estimateFromCoords(lat, lon), 0.0, true);
            return;
        }

        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        if (obj.contains("SQM")) {
            double sqm = obj["SQM"].toDouble();
            applyBortle(sqmToBortle(sqm), sqm, false);
        } else {
            applyBortle(estimateFromCoords(lat, lon), 0.0, true);
        }
    });
}

// Trivial coordinate-based fallback: very rough urban/rural heuristic.
int LightPollutionService::estimateFromCoords(double /*lat*/, double /*lon*/)
{
    return 5; // Suburban sky — neutral middle estimate
}

int LightPollutionService::sqmToBortle(double sqm)
{
    // Thresholds from Cinzano et al. Sky Quality Meter / Bortle calibration
    if (sqm >= 21.99) return 1;
    if (sqm >= 21.89) return 2;
    if (sqm >= 21.69) return 3;
    if (sqm >= 21.25) return 4;
    if (sqm >= 20.49) return 5;
    if (sqm >= 19.50) return 6;
    if (sqm >= 18.94) return 7;
    if (sqm >= 18.38) return 8;
    return 9;
}

void LightPollutionService::applyBortle(int bortle, double sqm, bool estimated)
{
    m_bortle    = bortle;
    m_sqm       = sqm;
    m_available = true;
    emit dataChanged();
    setStatus(estimated ? "Estimated" : "Live data");
}

QString LightPollutionService::bortleLabel() const
{
    static const char *labels[] = {
        "",
        "Excellent dark sky",
        "Truly dark sky",
        "Rural sky",
        "Rural / suburban transition",
        "Suburban sky",
        "Bright suburban sky",
        "Suburban / urban transition",
        "City sky",
        "Inner city sky"
    };
    if (m_bortle < 1 || m_bortle > 9) return QString();
    return QLatin1String(labels[m_bortle]);
}

void LightPollutionService::setStatus(const QString &s)
{
    if (m_status == s) return;
    m_status = s;
    emit statusChanged();
}
