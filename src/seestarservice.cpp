#include "seestarservice.h"
#include <QStorageInfo>
#include <QDir>

SeestarService::SeestarService(QObject *parent) : QObject(parent)
{
    connect(&m_timer, &QTimer::timeout, this, &SeestarService::poll);
    m_timer.start(2000);
    poll();
}

void SeestarService::poll()
{
    bool    found     = false;
    QString path;
    qint64  freeBytes = 0;

    for (const QStorageInfo &vol : QStorageInfo::mountedVolumes()) {
        if (vol.name() == QLatin1String("Seestar")) {
            found     = true;
            path      = vol.rootPath();
            freeBytes = qMax<qint64>(0, vol.bytesAvailable());
            break;
        }
    }

    bool myWorks = found && QDir(path + "/MyWorks").exists();

    if (found != m_connected || path != m_mountPath
            || myWorks != m_hasMyWorks || freeBytes != m_freeBytes) {
        m_connected  = found;
        m_mountPath  = path;
        m_hasMyWorks = myWorks;
        m_freeBytes  = freeBytes;
        emit connectedChanged();
    }
}
