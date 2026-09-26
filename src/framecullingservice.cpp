#include "framecullingservice.h"
#include "fitspixelreader.h"

#include <QFileDialog>
#include <QFileInfo>
#include <QVariantMap>
#include <QMap>
#include <QPair>
#include <QtConcurrentRun>
#include <QtConcurrentMap>
#include <algorithm>
#include <cmath>

FrameCullingService::FrameCullingService(QObject *parent)
    : QObject(parent)
{
    m_watcher = new QFutureWatcher<FrameQuality>(this);
    connect(m_watcher, &QFutureWatcher<FrameQuality>::finished,
            this, &FrameCullingService::onControlFinished);

    m_recWatcher = new QFutureWatcher<FrameQuality>(this);
    connect(m_recWatcher, &QFutureWatcher<FrameQuality>::finished,
            this, &FrameCullingService::onRecommendFinished);
    connect(m_recWatcher, &QFutureWatcher<FrameQuality>::progressValueChanged,
            this, [this](int value) { m_recommendDone = value; emit recommendProgress(); });

    m_batchWatcher = new QFutureWatcher<FrameQuality>(this);
    connect(m_batchWatcher, &QFutureWatcher<FrameQuality>::finished,
            this, &FrameCullingService::onBatchFinished);
    connect(m_batchWatcher, &QFutureWatcher<FrameQuality>::progressValueChanged,
            this, [this](int value) { m_batchDone = value; emit batchProgress(); });
}

static double controlScore(const FrameQuality &q)
{
    if (!q.valid || q.usableStarCount <= 0 || q.medianFwhm <= 0.0)
        return -1.0;
    const double snr = q.backgroundNoise > 0.0 ? q.medianStarFlux / q.backgroundNoise
                                               : q.medianStarFlux;
    return static_cast<double>(q.usableStarCount) * std::log(1.0 + std::max(0.0, snr))
           / (q.medianFwhm * (1.0 + q.medianEccentricity));
}

struct CullingThresholds {
    double starPass, starReject;
    double fluxLow, fluxHigh, fluxReject;
    double fwhmPass, fwhmReject;
    double eccPass, eccReject;
    double noisePass, noiseReject;
};

static CullingThresholds thresholdsFor(const QString &sensitivity)
{
    if (sensitivity == "conservative")
        return { 0.75, 0.55,  0.70, 1.35, 0.55,  0.40, 0.60,  0.40, 0.65,  0.50, 0.80 };
    if (sensitivity == "aggressive")
        return { 0.92, 0.80,  0.88, 1.12, 0.80,  0.15, 0.22,  0.15, 0.25,  0.18, 0.30 };
    return { 0.85, 0.70,  0.80, 1.20, 0.70,  0.25, 0.35,  0.25, 0.40,  0.30, 0.50 };
}

static QString statusHigh(double dev, double passLimit, double rejectLimit)
{
    if (dev > rejectLimit) return "bad";
    if (dev > passLimit)   return "ok";
    return "good";
}

static QVariantMap classifyFrame(const QString &path, const FrameQuality &q,
                                 const FrameQuality &control,
                                 const CullingThresholds &t,
                                 const QStringList &enabled)
{
    QVariantMap frame;
    frame["path"]         = path;
    frame["file"]         = QFileInfo(path).fileName();
    frame["usableStars"]  = q.usableStarCount;
    frame["decision"]     = "auto";

    constexpr int kMinUsableStars = 15;
    if (!q.valid || q.usableStarCount < kMinUsableStars) {
        frame["classification"] = "INSUFFICIENT";
        frame["primaryReason"]  = "Too few usable stars";
        frame["metrics"]        = QVariantList();
        return frame;
    }

    const double fwhmDev  = control.medianFwhm > 0.0
        ? (q.medianFwhm - control.medianFwhm) / control.medianFwhm : 0.0;
    const double eccDev   = control.medianEccentricity > 0.0
        ? (q.medianEccentricity - control.medianEccentricity) / control.medianEccentricity : 0.0;
    const double noiseDev = control.backgroundNoise > 0.0
        ? (q.backgroundNoise - control.backgroundNoise) / control.backgroundNoise : 0.0;
    const double starRatio = control.usableStarCount > 0
        ? static_cast<double>(q.usableStarCount) / control.usableStarCount : 1.0;
    const double fluxRatio = control.medianStarFlux > 0.0
        ? q.medianStarFlux / control.medianStarFlux : 1.0;

    const QString starStatus = starRatio < t.starReject ? "bad" : (starRatio < t.starPass ? "ok" : "good");
    const QString fluxStatus = fluxRatio < t.fluxReject ? "bad" : ((fluxRatio < t.fluxLow || fluxRatio > t.fluxHigh) ? "ok" : "good");
    const QString fwhmStatus  = statusHigh(fwhmDev, t.fwhmPass, t.fwhmReject);
    const QString eccStatus   = statusHigh(eccDev, t.eccPass, t.eccReject);
    const QString noiseStatus = statusHigh(noiseDev, t.noisePass, t.noiseReject);

    struct MetricRow { QString id; QString key; QString reason; QString status; double dev; };
    const QList<MetricRow> rows = {
        { "fwhm",         "FWHM",         "Excessive FWHM",        fwhmStatus,  fwhmDev },
        { "starcount",    "Star Count",   "Low star count",        starStatus,  starRatio - 1.0 },
        { "brightness",   "Brightness",   "Low star brightness",   fluxStatus,  fluxRatio - 1.0 },
        { "eccentricity", "Eccentricity", "Excessive elongation",  eccStatus,   eccDev },
        { "noise",        "Noise",        "High background noise", noiseStatus, noiseDev }
    };

    QVariantList metrics;
    int worst = 0;
    QString worstReason;
    for (const MetricRow &row : rows) {
        if (!enabled.contains(row.id)) continue;
        const int rank = row.status == "bad" ? 2 : (row.status == "ok" ? 1 : 0);
        if (rank > worst) { worst = rank; worstReason = row.reason; }
        QVariantMap m;
        m["key"]    = row.key;
        m["delta"]  = qRound(row.dev * 100.0);
        m["status"] = row.status;
        metrics.append(m);
    }

    frame["metrics"]        = metrics;
    frame["classification"] = worst == 2 ? "REJECT" : (worst == 1 ? "BORDERLINE" : "PASS");
    frame["primaryReason"]  = worstReason;
    return frame;
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

    m_analyzing         = true;
    m_controlPath       = path;
    m_controlRecommended = false;
    emit analyzingChanged();
    emit controlChanged();

    QFuture<FrameQuality> future = QtConcurrent::run([path]() -> FrameQuality {
        const FitsPixelData data = FitsPixelReader::read(path);
        return StarFinder::analyze(data);
    });
    m_watcher->setFuture(future);
}

void FrameCullingService::recommendControlImage(const QStringList &candidatePaths)
{
    if (m_analyzing || m_recommending || candidatePaths.isEmpty())
        return;

    m_recommendCandidates = candidatePaths;
    m_recommending   = true;
    m_recommendDone  = 0;
    m_recommendTotal = m_recommendCandidates.size();
    emit recommendingChanged();
    emit recommendProgress();

    QFuture<FrameQuality> future = QtConcurrent::mapped(m_recommendCandidates,
        [](const QString &path) -> FrameQuality {
            const FitsPixelData data = FitsPixelReader::read(path);
            return StarFinder::analyze(data);
        });
    m_recWatcher->setFuture(future);
}

void FrameCullingService::onRecommendFinished()
{
    m_recommending = false;
    emit recommendingChanged();

    const QList<FrameQuality> results = m_recWatcher->future().results();

    int    bestIndex = -1;
    double bestScore = 0.0;
    for (int i = 0; i < results.size(); ++i) {
        const double score = controlScore(results[i]);
        if (score > bestScore) {
            bestScore = score;
            bestIndex = i;
        }
    }

    if (bestIndex < 0 || bestIndex >= m_recommendCandidates.size()) {
        emit controlRecommended(false, "No frame with enough usable stars was found among the candidates.");
        return;
    }

    m_controlPath        = m_recommendCandidates[bestIndex];
    m_controlQuality     = results[bestIndex];
    m_controlRecommended = true;

    constexpr int kMinUsableStars = 50;
    if (m_controlQuality.usableStarCount < kMinUsableStars) {
        m_controlWarning = QString("The best candidate has only %1 usable stars. Consider a longer or better-focused frame.")
                               .arg(m_controlQuality.usableStarCount);
    } else {
        m_controlWarning.clear();
    }

    emit controlChanged();
    emit controlRecommended(true, QString());
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

void FrameCullingService::analyzeBatch(const QStringList &candidatePaths,
                                       const QString &sensitivity,
                                       const QStringList &enabledMetrics)
{
    if (m_batchAnalyzing || m_recommending || m_analyzing
        || candidatePaths.isEmpty() || !m_controlQuality.valid)
        return;

    m_batchCandidates = candidatePaths;
    m_sensitivity     = sensitivity.isEmpty() ? QStringLiteral("balanced") : sensitivity;
    m_enabledMetrics  = enabledMetrics.isEmpty()
        ? QStringList{ "fwhm", "starcount", "brightness", "eccentricity", "noise" }
        : enabledMetrics;
    m_batchAnalyzing  = true;
    m_batchDone       = 0;
    m_batchTotal      = m_batchCandidates.size();
    emit batchAnalyzingChanged();
    emit batchProgress();

    QFuture<FrameQuality> future = QtConcurrent::mapped(m_batchCandidates,
        [](const QString &path) -> FrameQuality {
            const FitsPixelData data = FitsPixelReader::read(path);
            return StarFinder::analyze(data);
        });
    m_batchWatcher->setFuture(future);
}

void FrameCullingService::onBatchFinished()
{
    m_batchAnalyzing = false;
    emit batchAnalyzingChanged();

    const QList<FrameQuality> results = m_batchWatcher->future().results();

    m_batchResults.clear();
    m_passCount = m_borderlineCount = m_rejectCount = m_insufficientCount = 0;
    QMap<QString, int> reasonCounts;

    const CullingThresholds thresholds = thresholdsFor(m_sensitivity);

    for (int i = 0; i < results.size() && i < m_batchCandidates.size(); ++i) {
        const QVariantMap frame = classifyFrame(m_batchCandidates[i], results[i], m_controlQuality,
                                                thresholds, m_enabledMetrics);
        const QString cls = frame["classification"].toString();
        if (cls == "PASS")            m_passCount++;
        else if (cls == "BORDERLINE") m_borderlineCount++;
        else if (cls == "REJECT") {
            m_rejectCount++;
            const QString reason = frame["primaryReason"].toString();
            if (!reason.isEmpty()) reasonCounts[reason]++;
        } else {
            m_insufficientCount++;
        }
        m_batchResults.append(frame);
    }

    QList<QPair<QString, int>> sortedReasons;
    for (auto it = reasonCounts.constBegin(); it != reasonCounts.constEnd(); ++it)
        sortedReasons.append({ it.key(), it.value() });
    std::sort(sortedReasons.begin(), sortedReasons.end(),
              [](const QPair<QString, int> &a, const QPair<QString, int> &b) { return a.second > b.second; });

    m_rejectionReasons.clear();
    for (const auto &pair : sortedReasons) {
        QVariantMap reason;
        reason["label"] = pair.first;
        reason["count"] = pair.second;
        m_rejectionReasons.append(reason);
    }

    emit batchProgress();
    emit batchResultsChanged();
}

void FrameCullingService::setFrameDecision(int index, const QString &decision)
{
    if (index < 0 || index >= m_batchResults.size())
        return;
    QVariantMap frame = m_batchResults[index].toMap();
    frame["decision"] = decision;
    m_batchResults[index] = frame;
    emit batchResultsChanged();
}

int FrameCullingService::rejectionCount() const
{
    return rejectionPaths().size();
}

QStringList FrameCullingService::rejectionPaths() const
{
    QStringList paths;
    for (const QVariant &value : m_batchResults) {
        const QVariantMap frame = value.toMap();
        const QString decision = frame["decision"].toString();
        if (decision == "reject"
            || (decision == "auto" && frame["classification"].toString() == "REJECT"))
            paths.append(frame["path"].toString());
    }
    return paths;
}

QVariantList FrameCullingService::thresholdTable(const QString &sensitivity) const
{
    const CullingThresholds t = thresholdsFor(sensitivity);

    auto pct     = [](double v) { return QString::number(qRound(v * 100.0)); };
    auto devHigh = [](double v) { return "+" + QString::number(qRound(v * 100.0)) + "%"; };

    QVariantList table;
    auto row = [&](const QString &label, const QString &value, const QString &reject) {
        QVariantMap m;
        m["label"]  = label;
        m["value"]  = value;
        m["reject"] = reject;
        table.append(m);
    };

    row("Star Count",      "≥ " + pct(t.starPass) + "%",
                           "reject < " + pct(t.starReject) + "%");
    row("Star Brightness", pct(t.fluxLow) + "–" + pct(t.fluxHigh) + "%",
                           "reject < " + pct(t.fluxReject) + "%");
    row("FWHM",            "≤ " + devHigh(t.fwhmPass),
                           "reject > " + devHigh(t.fwhmReject));
    row("Eccentricity",    "≤ " + devHigh(t.eccPass),
                           "reject > " + devHigh(t.eccReject));
    row("Noise",           "≤ " + devHigh(t.noisePass),
                           "reject > " + devHigh(t.noiseReject));
    return table;
}
