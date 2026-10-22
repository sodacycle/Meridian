#ifndef METADATAMODEL_H
#define METADATAMODEL_H

#include <QAbstractListModel>
#include <QList>
#include <QVariantMap>
#include <QString>
#include <functional>

class MetadataTableModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY viewChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY viewChanged)

public:
    enum Roles {
        RowRole = Qt::UserRole + 1
    };

    explicit MetadataTableModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int totalCount() const { return static_cast<int>(m_allRows.size()); }
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

    Q_INVOKABLE void setData(const QVariantList &rows, const QStringList &columns);
    Q_INVOKABLE void clear();

    Q_INVOKABLE void sortByColumn(const QString &column, bool ascending);
    Q_INVOKABLE void filterByCatalog(const QString &catalog);
    Q_INVOKABLE void filterByTarget(const QString &target);
    Q_INVOKABLE void filterByTargetAndDate(const QString &target, const QString &date);
    Q_INVOKABLE void showAll();
    Q_INVOKABLE void removeByPath(const QString &path);

signals:
    void viewChanged();

private:
    void rebuildView(const std::function<bool(const QVariantMap &)> &keep);
    void applySort();

    QList<QVariantMap> m_allRows;
    QList<int>         m_view;
    QStringList        m_columns;
    QString            m_sortColumn;
    bool               m_sortAscending = true;
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
