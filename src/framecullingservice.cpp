#include "framecullingservice.h"
#include "fitspixelreader.h"

#include <QFileDialog>
#include <QtConcurrentRun>

FrameCullingService::FrameCullingService(QObject *parent)
    : QObject(parent)
{
    m_watcher = new QFutureWatcher<FrameQuality>(this);
    connect(m_watcher, &QFutureWatcher<FrameQuality>::finished,
            this, &FrameCullingService::onControlFinished);
}

QString FrameCullingService::selectControlImage()
{
    return QFileDialog::getOpenFileName(nullptr,
        "Select Control Image",
        QString(),
        "FITS Images (*.fit *.fits *.fts)");
}

void FrameCullingService::analyzeControl(const QString &path)
{
    if (m_analyzing || path.isEmpty())
        return;

    m_analyzing   = true;
    m_controlPath = path;
    emit analyzingChanged();
    emit controlChanged();

    QFuture<FrameQuality> future = QtConcurrent::run([path]() -> FrameQuality {
        const FitsPixelData data = FitsPixelReader::read(path);
        return StarFinder::analyze(data);
    });
    m_watcher->setFuture(future);
}

void FrameCullingService::onControlFinished()
{
    m_controlQuality = m_watcher->result();
    m_analyzing = false;

    if (!m_controlQuality.valid) {
        m_controlWarning.clear();
        emit analyzingChanged();
        emit controlChanged();
        emit controlAnalyzed(false, "Could not read star data from this image.");
        return;
    }

    constexpr int kMinUsableStars = 50;
    if (m_controlQuality.usableStarCount < kMinUsableStars) {
        m_controlWarning = QString("Only %1 usable stars detected. This may not be a suitable control image.")
                               .arg(m_controlQuality.usableStarCount);
    } else {
        m_controlWarning.clear();
    }

    emit analyzingChanged();
    emit controlChanged();
    emit controlAnalyzed(true, QString());
}
