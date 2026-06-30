#include "weatherservice.h"
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QUrlQuery>
#include <QSettings>
#include <QTimeZone>
#include <cmath>

WeatherService::WeatherService(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
    QSettings settings;
    m_celsius = settings.value("weather/useCelsius", true).toBool();
    m_latitude = settings.value("weather/latitude", 0).toDouble();
    m_longitude = settings.value("weather/longitude", 0).toDouble();
}

bool WeatherService::isCelsius() const { return m_celsius; }
double WeatherService::latitude() const { return m_latitude; }
double WeatherService::longitude() const { return m_longitude; }

void WeatherService::setLocation(double lat, double lon)
{
    m_latitude = lat;
    m_longitude = lon;
    QSettings settings;
    settings.setValue("weather/latitude", lat);
    settings.setValue("weather/longitude", lon);
    emit locationChanged();
}

void WeatherService::toggleUnit()
{
    m_celsius = !m_celsius;
    QSettings settings;
    settings.setValue("weather/useCelsius", m_celsius);
    emit unitChanged();
    emit weatherUpdated();
}

void WeatherService::fetchWeatherForDateRange(const QString &startDate, const QString &endDate)
{
    if (m_latitude == 0 && m_longitude == 0) return;

    QDate today = QDate::currentDate();
    QDate start = QDate::fromString(startDate, "yyyy-MM-dd");
    QDate end   = QDate::fromString(endDate,   "yyyy-MM-dd");
    if (!start.isValid() || !end.isValid() || start > end) return;

    if (start < today) {
        QDate histEnd = qMin(today, end);
        QUrl url("https://archive-api.open-meteo.com/v1/archive");
        QUrlQuery query;
        query.addQueryItem("latitude",   QString::number(m_latitude));
        query.addQueryItem("longitude",  QString::number(m_longitude));
        query.addQueryItem("hourly",     "cloud_cover,relative_humidity_2m,temperature_2m,wind_speed_10m,wind_direction_10m");
        query.addQueryItem("daily",      "weather_code,sunrise,sunset");
        query.addQueryItem("start_date", start.toString("yyyy-MM-dd"));
        query.addQueryItem("end_date",   histEnd.toString("yyyy-MM-dd"));
        query.addQueryItem("timezone",   "auto");
        url.setQuery(query);

        QNetworkReply *reply = m_network->get(QNetworkRequest(url));
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            if (reply->error() == QNetworkReply::NoError) {
                QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
                parseWeatherResponse(doc.object());
                emit weatherUpdated();
            }
            reply->deleteLater();
        });
    }

    QUrl forecastUrl("https://api.open-meteo.com/v1/forecast");
    QUrlQuery forecastQuery;
    forecastQuery.addQueryItem("latitude",      QString::number(m_latitude));
    forecastQuery.addQueryItem("longitude",     QString::number(m_longitude));
    forecastQuery.addQueryItem("hourly",        "cloud_cover,relative_humidity_2m,temperature_2m,wind_speed_10m,wind_direction_10m");
    forecastQuery.addQueryItem("daily",         "weather_code,sunrise,sunset");
    forecastQuery.addQueryItem("timezone",      "auto");
    forecastQuery.addQueryItem("forecast_days", "16");
    forecastUrl.setQuery(forecastQuery);

    QNetworkReply *forecastReply = m_network->get(QNetworkRequest(forecastUrl));
    connect(forecastReply, &QNetworkReply::finished, this, [this, forecastReply]() {
        if (forecastReply->error() == QNetworkReply::NoError) {
            QJsonDocument doc = QJsonDocument::fromJson(forecastReply->readAll());
            parseWeatherResponse(doc.object());
        }
        forecastReply->deleteLater();
        emit weatherUpdated();
    });
}

void WeatherService::fetchWeather(int year, int month)
{
    m_currentYear = year;
    m_currentMonth = month;

    if (m_latitude == 0 && m_longitude == 0) return;
    if (m_network->findChildren<QNetworkReply*>().size() > 5) return;

    QDate today = QDate::currentDate();
    QDate firstOfMonth(year, month, 1);

    if (firstOfMonth < today) {
        QDate endDate = qMin(today, QDate(year, month, firstOfMonth.daysInMonth()));
        QUrl url("https://archive-api.open-meteo.com/v1/archive");
        QUrlQuery query;
        query.addQueryItem("latitude", QString::number(m_latitude));
        query.addQueryItem("longitude", QString::number(m_longitude));
        query.addQueryItem("hourly", "cloud_cover,relative_humidity_2m,temperature_2m,wind_speed_10m,wind_direction_10m");
        query.addQueryItem("daily", "weather_code,sunrise,sunset");
        query.addQueryItem("start_date", firstOfMonth.toString("yyyy-MM-dd"));
        query.addQueryItem("end_date", endDate.toString("yyyy-MM-dd"));
        query.addQueryItem("timezone", "auto");
        url.setQuery(query);

        QNetworkReply *reply = m_network->get(QNetworkRequest(url));
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            if (reply->error() == QNetworkReply::NoError) {
                QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
                parseWeatherResponse(doc.object());
            }
            reply->deleteLater();
        });
    }

    QUrl forecastUrl("https://api.open-meteo.com/v1/forecast");
    QUrlQuery forecastQuery;
    forecastQuery.addQueryItem("latitude",      QString::number(m_latitude));
    forecastQuery.addQueryItem("longitude",     QString::number(m_longitude));
    forecastQuery.addQueryItem("hourly",        "cloud_cover,relative_humidity_2m,temperature_2m,wind_speed_10m,wind_direction_10m");
    forecastQuery.addQueryItem("daily",         "weather_code,sunrise,sunset");
    forecastQuery.addQueryItem("timezone",      "auto");
    forecastQuery.addQueryItem("forecast_days", "16");
    forecastUrl.setQuery(forecastQuery);

    QNetworkReply *forecastReply = m_network->get(QNetworkRequest(forecastUrl));
    connect(forecastReply, &QNetworkReply::finished, this, [this, forecastReply]() {
        if (forecastReply->error() == QNetworkReply::NoError) {
            QJsonDocument doc = QJsonDocument::fromJson(forecastReply->readAll());
            parseWeatherResponse(doc.object());
        }
        forecastReply->deleteLater();
        emit weatherUpdated();
    });
}

void WeatherService::parseWeatherResponse(const QJsonObject &data)
{
    static const double kPi = 3.14159265358979323846;

    QJsonObject daily = data["daily"].toObject();
    QJsonArray times = daily["time"].toArray();
    QJsonArray codes = daily["weather_code"].toArray();
    QJsonArray sunrises = daily["sunrise"].toArray();
    QJsonArray sunsets  = daily["sunset"].toArray();

    for (int i = 0; i < times.size() && i < codes.size(); i++) {
        QString date = times[i].toString();
        WeatherData wd = m_weatherCache.value(date);
        wd.weatherCode = codes[i].toInt();
        if (i < sunrises.size() && !sunrises[i].isNull())
            wd.sunrise = sunrises[i].toString().mid(11, 5);
        if (i < sunsets.size() && !sunsets[i].isNull())
            wd.sunset = sunsets[i].toString().mid(11, 5);
        wd.valid = true;
        m_weatherCache[date] = wd;
    }

    QJsonObject hourly = data["hourly"].toObject();
    QJsonArray hTimes = hourly["time"].toArray();
    QJsonArray clouds = hourly["cloud_cover"].toArray();
    QJsonArray humidity = hourly["relative_humidity_2m"].toArray();
    QJsonArray temps = hourly["temperature_2m"].toArray();
    QJsonArray windSpeeds = hourly["wind_speed_10m"].toArray();
    QJsonArray windDirs = hourly["wind_direction_10m"].toArray();

    QMap<QString, QVector<double>> nightClouds, nightHumidity, nightTemps, nightWind;
    QMap<QString, double> windSin, windCos;
    QMap<QString, int> windN;

    for (int i = 0; i < hTimes.size(); i++) {
        QString dt = hTimes[i].toString();
        QString day = dt.left(10);
        int hour = dt.mid(11, 2).toInt();
        if (!(hour >= 20 || hour < 6)) continue;

        if (i < clouds.size() && !clouds[i].isNull())
            nightClouds[day].append(clouds[i].toDouble());
        if (i < humidity.size() && !humidity[i].isNull())
            nightHumidity[day].append(humidity[i].toDouble());
        if (i < temps.size() && !temps[i].isNull())
            nightTemps[day].append(temps[i].toDouble());
        if (i < windSpeeds.size() && !windSpeeds[i].isNull())
            nightWind[day].append(windSpeeds[i].toDouble());
        if (i < windDirs.size() && !windDirs[i].isNull()) {
            double r = windDirs[i].toDouble() * kPi / 180.0;
            windSin[day] += std::sin(r);
            windCos[day] += std::cos(r);
            windN[day] += 1;
        }
    }

    auto mean = [](const QVector<double> &v) {
        double s = 0;
        for (double x : v) s += x;
        return v.isEmpty() ? 0.0 : s / v.size();
    };

    for (auto it = nightClouds.begin(); it != nightClouds.end(); ++it)
        if (!it.value().isEmpty()) m_weatherCache[it.key()].avgCloud = mean(it.value());
    for (auto it = nightHumidity.begin(); it != nightHumidity.end(); ++it)
        if (!it.value().isEmpty()) m_weatherCache[it.key()].avgHumidity = mean(it.value());
    for (auto it = nightTemps.begin(); it != nightTemps.end(); ++it)
        if (!it.value().isEmpty()) m_weatherCache[it.key()].nightTemp = mean(it.value());
    for (auto it = nightWind.begin(); it != nightWind.end(); ++it)
        if (!it.value().isEmpty()) m_weatherCache[it.key()].windSpeed = mean(it.value());
    for (auto it = windN.begin(); it != windN.end(); ++it) {
        if (it.value() > 0) {
            double a = std::atan2(windSin[it.key()] / it.value(),
                                  windCos[it.key()] / it.value()) * 180.0 / kPi;
            if (a < 0) a += 360.0;
            m_weatherCache[it.key()].windDir = a;
        }
    }
}

WeatherData WeatherService::weatherForDate(const QString &dateStr) const
{
    return m_weatherCache.value(dateStr);
}

QString WeatherService::getWeatherEmoji(int weatherCode, double avgCloud) const
{
    if (avgCloud < 20) return "☀️";
    if (avgCloud < 50) return "⛅";
    if (avgCloud < 80) return "☁️";
    if (weatherCode >= 95) return "⛈️";
    if (weatherCode >= 80) return "🌧️";
    if (weatherCode >= 71) return "🌨️";
    if (weatherCode >= 61) return "🌧️";
    if (weatherCode >= 51) return "🌨️";
    if (weatherCode >= 45) return "🌫️";
    return "☁️";
}

QString WeatherService::getMoonPhase(const QDateTime &date) const
{
    const double lunarCycle = 29.53058867;
    QDateTime knownNewMoon(QDate(2000, 1, 6), QTime(18, 14, 0), QTimeZone("UTC"));
    double diffDays = knownNewMoon.secsTo(date) / (24.0 * 3600.0);
    double daysSinceNewMoon = std::fmod(diffDays, lunarCycle);
    if (daysSinceNewMoon < 0) daysSinceNewMoon += lunarCycle;
    int phase = static_cast<int>(std::floor((daysSinceNewMoon / lunarCycle) * 8)) % 8;

    static const QStringList phases = {
        "🌑", "🌒", "🌓", "🌔",
        "🌕", "🌖", "🌗", "🌘"
    };
    return phases[phase];
}
