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

    bool hasData() const { return !m_metadata.isEmpty(); }

    void setData(const QVariantList &metadata,
                 const QStringList &columns,
                 const QVariantList &targets);

    Q_INVOKABLE QString exportTargetSummaryCsv();
    Q_INVOKABLE QString exportSessionHistoryCsv();
    Q_INVOKABLE QString exportReportHtml();

signals:
    void dataChanged();
    void exportFinished(bool success, const QString &path);

private:
    QString writeFile(const QString &path, const QString &contents);

    QVariantList m_metadata;
    QStringList  m_columns;
    QVariantList m_targets;
};

#endif
