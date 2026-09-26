#ifndef FRAMECULLINGSERVICE_H
#define FRAMECULLINGSERVICE_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QFutureWatcher>

#include "starfinder.h"

class FrameCullingService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool    analyzing              READ isAnalyzing            NOTIFY analyzingChanged)
    Q_PROPERTY(QString controlPath            READ controlPath            NOTIFY controlChanged)
    Q_PROPERTY(bool    controlValid           READ controlValid           NOTIFY controlChanged)
    Q_PROPERTY(QString controlWarning         READ controlWarning         NOTIFY controlChanged)
    Q_PROPERTY(int     controlStarCount       READ controlStarCount       NOTIFY controlChanged)
    Q_PROPERTY(int     controlUsableStarCount READ controlUsableStarCount NOTIFY controlChanged)
    Q_PROPERTY(double  controlFwhm            READ controlFwhm            NOTIFY controlChanged)
    Q_PROPERTY(double  controlEccentricity    READ controlEccentricity    NOTIFY controlChanged)
    Q_PROPERTY(double  controlFlux            READ controlFlux            NOTIFY controlChanged)
    Q_PROPERTY(double  controlBackgroundNoise READ controlBackgroundNoise NOTIFY controlChanged)
    Q_PROPERTY(double  controlBackgroundLevel READ controlBackgroundLevel NOTIFY controlChanged)
    Q_PROPERTY(bool    controlRecommended     READ controlWasRecommended  NOTIFY controlChanged)

    Q_PROPERTY(bool    recommending      READ isRecommending  NOTIFY recommendingChanged)
    Q_PROPERTY(int     recommendDone     READ recommendDone   NOTIFY recommendProgress)
    Q_PROPERTY(int     recommendTotal    READ recommendTotal  NOTIFY recommendProgress)

    Q_PROPERTY(bool    batchAnalyzing    READ isBatchAnalyzing NOTIFY batchAnalyzingChanged)
    Q_PROPERTY(int     batchDone         READ batchDone        NOTIFY batchProgress)
    Q_PROPERTY(int     batchTotal        READ batchTotal       NOTIFY batchProgress)
    Q_PROPERTY(QVariantList batchResults READ batchResults     NOTIFY batchResultsChanged)
    Q_PROPERTY(QVariantList rejectionReasons READ rejectionReasons NOTIFY batchResultsChanged)
    Q_PROPERTY(int     passCount         READ passCount         NOTIFY batchResultsChanged)
    Q_PROPERTY(int     borderlineCount   READ borderlineCount   NOTIFY batchResultsChanged)
    Q_PROPERTY(int     rejectCount       READ rejectCount       NOTIFY batchResultsChanged)
    Q_PROPERTY(int     insufficientCount READ insufficientCount NOTIFY batchResultsChanged)
    Q_PROPERTY(int     rejectionCount    READ rejectionCount    NOTIFY batchResultsChanged)

public:
    explicit FrameCullingService(QObject *parent = nullptr);

    bool    isAnalyzing() const            { return m_analyzing; }
    QString controlPath() const            { return m_controlPath; }
    bool    controlValid() const           { return m_controlQuality.valid; }
    QString controlWarning() const         { return m_controlWarning; }
    int     controlStarCount() const       { return m_controlQuality.starCount; }
    int     controlUsableStarCount() const { return m_controlQuality.usableStarCount; }
    double  controlFwhm() const            { return m_controlQuality.medianFwhm; }
    double  controlEccentricity() const    { return m_controlQuality.medianEccentricity; }
    double  controlFlux() const            { return m_controlQuality.medianStarFlux; }
    double  controlBackgroundNoise() const { return m_controlQuality.backgroundNoise; }
    double  controlBackgroundLevel() const { return m_controlQuality.backgroundLevel; }
    bool    controlWasRecommended() const  { return m_controlRecommended; }

    bool    isRecommending() const { return m_recommending; }
    int     recommendDone() const  { return m_recommendDone; }
    int     recommendTotal() const { return m_recommendTotal; }

    bool         isBatchAnalyzing() const { return m_batchAnalyzing; }
    int          batchDone() const        { return m_batchDone; }
    int          batchTotal() const       { return m_batchTotal; }
    QVariantList batchResults() const     { return m_batchResults; }
    QVariantList rejectionReasons() const { return m_rejectionReasons; }
    int          passCount() const         { return m_passCount; }
    int          borderlineCount() const   { return m_borderlineCount; }
    int          rejectCount() const       { return m_rejectCount; }
    int          insufficientCount() const { return m_insufficientCount; }
    int          rejectionCount() const;

    Q_INVOKABLE QString selectControlImage();
    Q_INVOKABLE void    analyzeControl(const QString &path);
    Q_INVOKABLE void    recommendControlImage(const QStringList &candidatePaths);
    Q_INVOKABLE void    analyzeBatch(const QStringList &candidatePaths,
                                     const QString &sensitivity,
                                     const QStringList &enabledMetrics);
    Q_INVOKABLE void    setFrameDecision(int index, const QString &decision);
    Q_INVOKABLE QStringList  rejectionPaths() const;
    Q_INVOKABLE QVariantList thresholdTable(const QString &sensitivity) const;

signals:
    void analyzingChanged();
    void controlChanged();
    void controlAnalyzed(bool success, const QString &error);
    void recommendingChanged();
    void recommendProgress();
    void controlRecommended(bool success, const QString &error);
    void batchAnalyzingChanged();
    void batchProgress();
    void batchResultsChanged();

private slots:
    void onControlFinished();
    void onRecommendFinished();
    void onBatchFinished();

private:
    bool         m_analyzing = false;
    QString      m_controlPath;
    QString      m_controlWarning;
    FrameQuality m_controlQuality;
    bool         m_controlRecommended = false;

    bool         m_recommending = false;
    int          m_recommendDone = 0;
    int          m_recommendTotal = 0;
    QStringList  m_recommendCandidates;

    bool         m_batchAnalyzing = false;
    int          m_batchDone = 0;
    int          m_batchTotal = 0;
    QStringList  m_batchCandidates;
    QString      m_sensitivity = "balanced";
    QStringList  m_enabledMetrics;
    QVariantList m_batchResults;
    QVariantList m_rejectionReasons;
    int          m_passCount = 0;
    int          m_borderlineCount = 0;
    int          m_rejectCount = 0;
    int          m_insufficientCount = 0;

    QFutureWatcher<FrameQuality> *m_watcher = nullptr;
    QFutureWatcher<FrameQuality> *m_recWatcher = nullptr;
    QFutureWatcher<FrameQuality> *m_batchWatcher = nullptr;
};

#endif
