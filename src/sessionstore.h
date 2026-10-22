#ifndef SESSIONSTORE_H
#define SESSIONSTORE_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QHash>
#include <QList>
#include <QSqlDatabase>

#include "fitsscanner.h"

class SessionStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasSession READ hasSession NOTIFY changed)
    Q_PROPERTY(int fileCount READ fileCount NOTIFY changed)
    Q_PROPERTY(int directoryCount READ directoryCount NOTIFY changed)
    Q_PROPERTY(QString lastScanText READ lastScanText NOTIFY changed)

public:
    explicit SessionStore(QObject *parent = nullptr);

    bool open();

    bool hasSession() const;
    int fileCount() const;
    int directoryCount() const;
    QString lastScanText() const;
    QStringList savedDirectories() const;

    QList<MetadataEntry> loadAll() const;
    QHash<QString, MetadataEntry> loadByPath() const;

    void syncScan(const QStringList &scannedRoots, const QList<MetadataEntry> &entries);
    void setDirectories(const QStringList &dirs);

    Q_INVOKABLE void startFresh();

signals:
    void changed();

private:
    void ensureSchema();

    QSqlDatabase m_db;
    bool m_ready = false;
};

#endif
