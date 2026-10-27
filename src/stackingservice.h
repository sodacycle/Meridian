#ifndef STACKINGSERVICE_H
#define STACKINGSERVICE_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QAtomicInt>
#include <QFutureWatcher>

struct StackResult {
    bool    ok = false;
    QString error;
    QString warning;
    QString outputPath;
    int     framesUsed = 0;
    int     framesTotal = 0;
};

class StackingService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool    stacking      READ isStacking    NOTIFY stackingChanged)
    Q_PROPERTY(int     progressDone  READ progressDone  NOTIFY progressChanged)
    Q_PROPERTY(int     progressTotal READ progressTotal NOTIFY progressChanged)
    Q_PROPERTY(QString phase         READ phase         NOTIFY progressChanged)
    Q_PROPERTY(QString resultPath    READ resultPath    NOTIFY resultChanged)
    Q_PROPERTY(int     framesUsed    READ framesUsed    NOTIFY resultChanged)
    Q_PROPERTY(int     framesTotal   READ framesTotal   NOTIFY resultChanged)
    Q_PROPERTY(QString lastError     READ lastError     NOTIFY resultChanged)
    Q_PROPERTY(QString lastWarning   READ lastWarning   NOTIFY resultChanged)

public:
    explicit StackingService(QObject *parent = nullptr);

    bool    isStacking() const    { return m_stacking; }
    int     progressDone() const  { return m_done; }
    int     progressTotal() const { return m_total; }
    QString phase() const         { return m_phase; }
    QString resultPath() const    { return m_resultPath; }
    int     framesUsed() const    { return m_framesUsed; }
    int     framesTotal() const   { return m_framesTotal; }
    QString lastError() const     { return m_lastError; }
    QString lastWarning() const   { return m_lastWarning; }

    Q_INVOKABLE void integrate(const QStringList &paths,
                               const QString &referencePath,
                               const QString &targetName,
                               bool align,
                               const QString &combineMethod,
                               const QString &outputMode,
                               bool autoBalance,
                               const QVariantMap &calibration,
                               const QVariantList &panelIds = QVariantList(),
                               bool mosaic = false);
    Q_INVOKABLE QStringList selectCalibrationFolder();
    Q_INVOKABLE QVariantMap  autoMatchCalibration(const QStringList &lightPaths);
    Q_INVOKABLE void cancel();

signals:
    void stackingChanged();
    void progressChanged();
    void resultChanged();
    void finished(bool ok, const QString &outputPath, const QString &error);

public slots:
    void reportProgress(int done, int total, const QString &phase);

private slots:
    void onFinished();

private:
    bool    m_stacking = false;
    int     m_done = 0;
    int     m_total = 0;
    QString m_phase;
    QString m_resultPath;
    int     m_framesUsed = 0;
    int     m_framesTotal = 0;
    QString m_lastError;
    QString m_lastWarning;

    QAtomicInt m_cancel { 0 };
    QFutureWatcher<StackResult> *m_watcher = nullptr;
};

#endif
