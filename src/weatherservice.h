#ifndef WEATHERSERVICE_H
#define WEATHERSERVICE_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QJsonObject>
#include <QJsonArray>
#include <QHash>
#include <QDateTime>
#include <QSettings>
#include <QString>

struct WeatherData {
    Q_GADGET
    Q_PROPERTY(bool    valid        MEMBER valid)
    Q_PROPERTY(int     weatherCode  MEMBER weatherCode)
    Q_PROPERTY(double  avgCloud     MEMBER avgCloud)
    Q_PROPERTY(double  avgHumidity  MEMBER avgHumidity)
    Q_PROPERTY(double  nightTemp    MEMBER nightTemp)
    Q_PROPERTY(double  windSpeed    MEMBER windSpeed)
    Q_PROPERTY(double  windDir      MEMBER windDir)
    Q_PROPERTY(QString sunrise      MEMBER sunrise)
    Q_PROPERTY(QString sunset       MEMBER sunset)
public:
    int     weatherCode  = 0;
    double  avgCloud     = 0;
    double  avgHumidity  = 0;
    double  nightTemp    = 0;
    double  windSpeed    = 0;
    double  windDir      = 0;
    QString sunrise;
    QString sunset;
    bool    valid        = false;
};
Q_DECLARE_METATYPE(WeatherData)

class WeatherService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool celsius READ isCelsius NOTIFY unitChanged)
    Q_PROPERTY(double latitude READ latitude NOTIFY locationChanged)
    Q_PROPERTY(double longitude READ longitude NOTIFY locationChanged)

public:
    explicit WeatherService(QObject *parent = nullptr);

    bool isCelsius() const;
    double latitude() const;
    double longitude() const;

    Q_INVOKABLE void setLocation(double lat, double lon);
    Q_INVOKABLE void fetchWeather(int year, int month);
    Q_INVOKABLE void fetchWeatherForDateRange(const QString &startDate, const QString &endDate);
    Q_INVOKABLE QString getWeatherEmoji(int weatherCode, double avgCloud) const;
    Q_INVOKABLE QString getMoonPhase(const QDateTime &date) const;
    Q_INVOKABLE void toggleUnit();
    Q_INVOKABLE WeatherData weatherForDate(const QString &dateStr) const;

signals:
    void weatherUpdated();
    void locationChanged();
    void unitChanged();

private:
    void parseWeatherResponse(const QJsonObject &data);
    QNetworkAccessManager *m_network;
    QHash<QString, WeatherData> m_weatherCache;
    double m_latitude = 0;
    double m_longitude = 0;
    bool m_celsius = true;
    int m_currentYear = 0;
    int m_currentMonth = 0;
};

#endif
