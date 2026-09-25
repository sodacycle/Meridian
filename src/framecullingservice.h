#ifndef FRAMECULLINGSERVICE_H
#define FRAMECULLINGSERVICE_H

#include <QObject>
#include <QString>
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

    Q_INVOKABLE QString selectControlImage();
    Q_INVOKABLE void    analyzeControl(const QString &path);

signals:
    void analyzingChanged();
    void controlChanged();
    void controlAnalyzed(bool success, const QString &error);

private slots:
    void onControlFinished();

private:
    bool         m_analyzing = false;
    QString      m_controlPath;
    QString      m_controlWarning;
    FrameQuality m_controlQuality;

    QFutureWatcher<FrameQuality> *m_watcher = nullptr;
};

#endif
