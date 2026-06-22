#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QVariantMap>
#include <QHash>
#include <QString>

class WikiService : public QObject
{
    Q_OBJECT
public:
    explicit WikiService(QObject *parent = nullptr);

    Q_INVOKABLE void lookup(const QString &objectName);

    Q_INVOKABLE QString fullConstellation(const QString &abbr) const;

signals:
    void infoboxReady(const QVariantMap &data, const QString &objectName);
    void lookupFailed(const QString &objectName, const QString &error);

private:
    QNetworkAccessManager *m_network;

    static const QHash<QString, QString> &constellationMap();
};
