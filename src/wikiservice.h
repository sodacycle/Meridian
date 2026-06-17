#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QVariantMap>
#include <QHash>
#include <QString>

// Fetches and parses Wikipedia infobox data for astronomical objects.
// Ported from wiki-parser.js in the Electron Astro Planner.
class WikiService : public QObject
{
    Q_OBJECT
public:
    explicit WikiService(QObject *parent = nullptr);

    // Fetch the Wikipedia infobox for an astronomical object by name.
    // Emits infoboxReady or lookupFailed when done.
    Q_INVOKABLE void lookup(const QString &objectName);

    // Expand a standard constellation abbreviation to its full name.
    Q_INVOKABLE QString fullConstellation(const QString &abbr) const;

signals:
    void infoboxReady(const QVariantMap &data, const QString &objectName);
    void lookupFailed(const QString &objectName, const QString &error);

private:
    QNetworkAccessManager *m_network;


    static const QHash<QString, QString> &constellationMap();
};
