#pragma once
#include <QObject>
#include <QTimer>
#include <QString>

class SeestarService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool    connected  READ connected  NOTIFY connectedChanged)
    Q_PROPERTY(QString mountPath  READ mountPath  NOTIFY connectedChanged)
    Q_PROPERTY(bool    hasMyWorks READ hasMyWorks NOTIFY connectedChanged)
    Q_PROPERTY(qint64  freeBytes  READ freeBytes  NOTIFY connectedChanged)

public:
    explicit SeestarService(QObject *parent = nullptr);

    bool    connected()  const { return m_connected; }
    QString mountPath()  const { return m_mountPath; }
    bool    hasMyWorks() const { return m_hasMyWorks; }
    qint64  freeBytes()  const { return m_freeBytes; }

signals:
    void connectedChanged();

private:
    void poll();

    QTimer  m_timer;
    bool    m_connected  = false;
    bool    m_hasMyWorks = false;
    qint64  m_freeBytes  = 0;
    QString m_mountPath;
};
