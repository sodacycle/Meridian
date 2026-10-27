#include "seestarservice.h"
#include <QStorageInfo>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QFile>
#include <QtConcurrent>

SeestarService::SeestarService(QObject *parent) : QObject(parent)
{
    connect(&m_timer, &QTimer::timeout, this, &SeestarService::poll);
    m_timer.start(2000);

    connect(this, &SeestarService::reportImportProgress, this,
            [this](int done, int total) {
                m_importDone  = done;
                m_importTotal = total;
                emit importProgressChanged();
            });

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

void SeestarService::importMyWorks(const QString &destBase)
{
    if (m_importing)
        return;

    const QString src = m_mountPath + "/MyWorks";
    if (m_mountPath.isEmpty() || !QDir(src).exists()) {
        emit importFinished(0, 0, false, QStringLiteral("No Seestar MyWorks folder was found."));
        return;
    }
    if (destBase.isEmpty()) {
        emit importFinished(0, 0, false, QStringLiteral("No default astrophotography folder is set."));
        return;
    }

    m_importCancel.storeRelaxed(0);
    m_importDone  = 0;
    m_importTotal = 0;
    emit importProgressChanged();

    m_importing = true;
    emit importingChanged();

    const QString dst = destBase;
    QFuture<ImportResult> future = QtConcurrent::run(
        [this, src, dst]() { return doImport(src, dst); });

    m_importWatcher = new QFutureWatcher<ImportResult>(this);
    connect(m_importWatcher, &QFutureWatcher<ImportResult>::finished,
            this, &SeestarService::onImportFinished);
    m_importWatcher->setFuture(future);
}

void SeestarService::cancelImport()
{
    if (m_importing)
        m_importCancel.storeRelaxed(1);
}

SeestarService::ImportResult SeestarService::doImport(const QString &src, const QString &dst)
{
    ImportResult r;

    QStringList files;
    {
        QDirIterator it(src, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (it.hasNext())
            files << it.next();
    }
    const int total = files.size();
    emit reportImportProgress(0, total);

    const QDir srcDir(src);
    QDir().mkpath(dst);

    int done = 0;
    for (const QString &file : files) {
        if (m_importCancel.loadRelaxed()) {
            r.cancelled = true;
            break;
        }

        const QString rel      = srcDir.relativeFilePath(file);
        const QString target   = QDir(dst).filePath(rel);
        const QFileInfo srcInfo(file);
        const QFileInfo dstInfo(target);

        if (dstInfo.exists() && dstInfo.size() == srcInfo.size()) {
            ++r.skipped;
        } else {
            QDir().mkpath(dstInfo.absolutePath());
            if (dstInfo.exists())
                QFile::remove(target);
            if (QFile::copy(file, target))
                ++r.copied;
            else
                ++r.skipped;
        }

        ++done;
        if (done == total || (done % 25) == 0)
            emit reportImportProgress(done, total);
    }

    return r;
}

void SeestarService::onImportFinished()
{
    const ImportResult r = m_importWatcher->result();

    m_importing = false;
    emit importingChanged();
    emit importFinished(r.copied, r.skipped, r.cancelled, r.error);

    m_importWatcher->deleteLater();
    m_importWatcher = nullptr;
}
