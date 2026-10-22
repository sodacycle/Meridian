#ifndef EXPORTSERVICE_H
#define EXPORTSERVICE_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>

class ExportService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasData READ hasData NOTIFY dataChanged)

public:
    explicit ExportService(QObject *parent = nullptr);

    bool hasData() const { return !m_targets.isEmpty(); }

    void setSummary(const QStringList &columns, const QVariantList &targets);

    Q_INVOKABLE QString exportTargetSummaryCsv();
    Q_INVOKABLE QString exportSessionHistoryCsv(const QVariantList &metadata);
    Q_INVOKABLE QString exportReportHtml(const QVariantList &metadata);

signals:
    void dataChanged();
    void exportFinished(bool success, const QString &path);

private:
    QString writeFile(const QString &path, const QString &contents);

    QStringList  m_columns;
    QVariantList m_targets;
};

#endif
