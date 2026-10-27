#pragma once
#include <QObject>
#include <QTimer>
#include <QString>
#include <QAtomicInt>
#include <QFutureWatcher>

class SeestarService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool    connected  READ connected  NOTIFY connectedChanged)
    Q_PROPERTY(QString mountPath  READ mountPath  NOTIFY connectedChanged)
    Q_PROPERTY(bool    hasMyWorks READ hasMyWorks NOTIFY connectedChanged)
    Q_PROPERTY(qint64  freeBytes  READ freeBytes  NOTIFY connectedChanged)

    Q_PROPERTY(bool    importing    READ importing    NOTIFY importingChanged)
    Q_PROPERTY(int     importDone   READ importDone   NOTIFY importProgressChanged)
    Q_PROPERTY(int     importTotal  READ importTotal  NOTIFY importProgressChanged)

public:
    explicit SeestarService(QObject *parent = nullptr);

    struct ImportResult {
        int     copied    = 0;
        int     skipped   = 0;
        bool    cancelled = false;
        QString error;
    };

    bool    connected()  const { return m_connected; }
    QString mountPath()  const { return m_mountPath; }
    bool    hasMyWorks() const { return m_hasMyWorks; }
    qint64  freeBytes()  const { return m_freeBytes; }

    bool importing()   const { return m_importing; }
    int  importDone()  const { return m_importDone; }
    int  importTotal() const { return m_importTotal; }

    // Copies the contents of the Seestar's MyWorks folder into destBase off the
    // UI thread. Existing files of the same size are skipped, so a repeat import
    // only brings over what is new.
    Q_INVOKABLE void importMyWorks(const QString &destBase);
    Q_INVOKABLE void cancelImport();

signals:
    void connectedChanged();
    void importingChanged();
    void importProgressChanged();
    void importFinished(int copied, int skipped, bool cancelled, const QString &error);

    void reportImportProgress(int done, int total);

private slots:
    void onImportFinished();

private:
    void poll();
    ImportResult doImport(const QString &src, const QString &dst);

    QTimer  m_timer;
    bool    m_connected  = false;
    bool    m_hasMyWorks = false;
    qint64  m_freeBytes  = 0;
    QString m_mountPath;

    bool       m_importing   = false;
    int        m_importDone  = 0;
    int        m_importTotal = 0;
    QAtomicInt m_importCancel { 0 };
    QFutureWatcher<ImportResult> *m_importWatcher = nullptr;
};
