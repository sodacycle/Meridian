#ifndef METADATAMODEL_H
#define METADATAMODEL_H

#include <QAbstractListModel>
#include <QList>
#include <QVariantMap>

class MetadataTableModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount)

public:
    enum Roles {
        ValueRole = Qt::UserRole + 1,
        ColumnNameRole
    };

    explicit MetadataTableModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

    Q_INVOKABLE void setData(const QVariantList &rows, const QStringList &columns);
    Q_INVOKABLE void clear();
    Q_INVOKABLE void filterByCatalog(const QString &catalog, const QVariantList &allRows, const QStringList &columns);
    Q_INVOKABLE void filterByTargetAndDate(const QString &target, const QString &date,
                                           const QVariantList &allRows, const QStringList &columns);

private:
    QList<QVariantMap> m_rows;
    QStringList m_columns;
};

class TargetSummaryModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount)

public:
    enum Roles {
        TargetRole = Qt::UserRole + 1,
        FitsCountRole,
        FilesWithExposureRole,
        IntegrationTimeRole
    };

    explicit TargetSummaryModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

    Q_INVOKABLE void   setEntries(const QVariantList &entries);
    Q_INVOKABLE void   sortBy(const QString &column, bool ascending);
    Q_INVOKABLE double integrationSecondsForTarget(const QString &targetName) const;
    Q_INVOKABLE int    sessionCountForTarget(const QString &targetName) const;

private:
    QList<QVariantMap> m_entries;
};

class CalibrationSummaryModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount)

public:
    enum Roles {
        FrameTypeRole = Qt::UserRole + 1,
        ExposureTimeRole,
        GainRole,
        BinningRole,
        SensorTempRole,
        CountRole,
        MostRecentRole
    };

    explicit CalibrationSummaryModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

    Q_INVOKABLE void setEntries(const QVariantList &entries);

private:
    QList<QVariantMap> m_entries;
};

class CatalogModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount)

public:
    enum Roles {
        CatalogNameRole = Qt::UserRole + 1,
        CatalogCountRole
    };

    explicit CatalogModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

    Q_INVOKABLE void buildFromTargets(const QVariantList &targetSummary);
    Q_INVOKABLE void clear();

private:
    struct CatalogEntry {
        QString name;
        int count = 0;
    };
    QList<CatalogEntry> m_catalogs;
};

#endif
