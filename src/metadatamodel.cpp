#include "metadatamodel.h"
#include <QSet>
#include <algorithm>

MetadataTableModel::MetadataTableModel(QObject *parent) : QAbstractListModel(parent) {}

int MetadataTableModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return static_cast<int>(m_view.size());
}

QHash<int, QByteArray> MetadataTableModel::roleNames() const
{
    return {
        {RowRole, "rowData"}
    };
}

QVariant MetadataTableModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_view.size())
        return {};
    if (role == RowRole || role == Qt::DisplayRole)
        return m_allRows.at(m_view.at(index.row()));
    return {};
}

void MetadataTableModel::setData(const QVariantList &rows, const QStringList &columns)
{
    beginResetModel();
    m_columns = columns;
    m_allRows.clear();
    m_allRows.reserve(rows.size());
    for (const auto &r : rows)
        m_allRows.append(r.toMap());
    m_view.resize(m_allRows.size());
    for (int i = 0; i < m_allRows.size(); ++i)
        m_view[i] = i;
    applySort();
    endResetModel();
    emit viewChanged();
}

void MetadataTableModel::clear()
{
    beginResetModel();
    m_allRows.clear();
    m_view.clear();
    m_columns.clear();
    m_sortColumn.clear();
    endResetModel();
    emit viewChanged();
}

void MetadataTableModel::applySort()
{
    if (m_sortColumn.isEmpty())
        return;
    const QString col = m_sortColumn;
    const bool asc = m_sortAscending;
    std::stable_sort(m_view.begin(), m_view.end(), [&](int a, int b) {
        const QString va = m_allRows.at(a).value(col).toString();
        const QString vb = m_allRows.at(b).value(col).toString();
        bool ok1 = false, ok2 = false;
        const double na = va.toDouble(&ok1);
        const double nb = vb.toDouble(&ok2);
        bool less = (ok1 && ok2) ? (na < nb)
                                 : (va.compare(vb, Qt::CaseInsensitive) < 0);
        return asc ? less : !less;
    });
}

void MetadataTableModel::sortByColumn(const QString &column, bool ascending)
{
    m_sortColumn = column;
    m_sortAscending = ascending;
    beginResetModel();
    applySort();
    endResetModel();
}

void MetadataTableModel::rebuildView(const std::function<bool(const QVariantMap &)> &keep)
{
    beginResetModel();
    m_view.clear();
    for (int i = 0; i < m_allRows.size(); ++i) {
        if (!keep || keep(m_allRows.at(i)))
            m_view.append(i);
    }
    applySort();
    endResetModel();
    emit viewChanged();
}

void MetadataTableModel::filterByCatalog(const QString &catalog)
{
    auto matchesCatalog = [catalog](const QVariantMap &row) -> bool {
        QString name = row.value("Target").toString().toUpper().trimmed();
        name.remove("MOSAIC").remove("PANEL").replace("-", " ");
        name = name.simplified();
        auto starts = [&](const QString &prefix) { return name.startsWith(prefix); };
        if (catalog == "Messier") return starts("M ");
        if (catalog == "NGC") return starts("NGC");
        if (catalog == "IC") return starts("IC");
        if (catalog == "Caldwell") return starts("CALDWELL");
        if (catalog == "Sharpless") return starts("SH") || starts("SH2");
        if (catalog == "Barnard") return starts("BARNARD") || starts("B ");
        if (catalog == "LDN") return starts("LDN");
        if (catalog == "LBN") return starts("LBN");
        if (catalog == "Abell") return starts("ABELL");
        if (catalog == "PGC") return starts("PGC");
        if (catalog == "UGC") return starts("UGC");
        if (catalog == "Other") {
            return !starts("M ") && !starts("NGC") && !starts("IC") &&
                   !starts("CALDWELL") && !starts("SH") && !starts("SH2") &&
                   !starts("BARNARD") && !starts("B ") && !starts("LDN") &&
                   !starts("LBN") && !starts("ABELL") && !starts("PGC") && !starts("UGC");
        }
        return false;
    };
    rebuildView(matchesCatalog);
}

void MetadataTableModel::filterByTarget(const QString &target)
{
    rebuildView([target](const QVariantMap &row) {
        return row.value("Target").toString() == target;
    });
}

void MetadataTableModel::filterByTargetAndDate(const QString &target, const QString &date)
{
    rebuildView([target, date](const QVariantMap &row) {
        return row.value("Target").toString() == target
            && row.value("Start Time UTC").toString().left(10) == date;
    });
}

void MetadataTableModel::showAll()
{
    rebuildView(nullptr);
}

void MetadataTableModel::removeByPath(const QString &path)
{
    int found = -1;
    for (int i = 0; i < m_allRows.size(); ++i) {
        if (m_allRows.at(i).value("Path").toString() == path) { found = i; break; }
    }
    if (found < 0)
        return;
    beginResetModel();
    m_allRows.removeAt(found);
    m_view.clear();
    for (int i = 0; i < m_allRows.size(); ++i)
        m_view.append(i);
    applySort();
    endResetModel();
    emit viewChanged();
}

QStringList MetadataTableModel::viewPaths() const
{
    QStringList paths;
    paths.reserve(m_view.size());
    for (int idx : m_view) {
        const QString p = m_allRows.at(idx).value("Path").toString();
        if (!p.isEmpty())
            paths.append(p);
    }
    return paths;
}

QStringList MetadataTableModel::pathsForTarget(const QString &target) const
{
    QStringList paths;
    for (const QVariantMap &row : m_allRows) {
        if (row.value("Target").toString() == target) {
            const QString p = row.value("Path").toString();
            if (!p.isEmpty())
                paths.append(p);
        }
    }
    return paths;
}

TargetSummaryModel::TargetSummaryModel(QObject *parent) : QAbstractListModel(parent) {}

int TargetSummaryModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_entries.size();
}

QHash<int, QByteArray> TargetSummaryModel::roleNames() const
{
    return {
        {TargetRole, "targetName"},
        {FitsCountRole, "fitsCount"},
        {FilesWithExposureRole, "filesWithExposure"},
        {IntegrationTimeRole, "integrationTime"}
    };
}

QVariant TargetSummaryModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_entries.size()) return {};
    const auto &e = m_entries[index.row()];
    switch (role) {
    case TargetRole: return e.value("Target");
    case FitsCountRole: return e.value("FITS Count");
    case FilesWithExposureRole: return e.value("Files With Exposure");
    case IntegrationTimeRole: return e.value("Total Integration Time");
    default: return {};
    }
}

void TargetSummaryModel::setEntries(const QVariantList &entries)
{
    beginResetModel();
    m_entries.clear();
    for (const auto &e : entries)
        m_entries.append(e.toMap());
    endResetModel();
}

void TargetSummaryModel::sortBy(const QString &column, bool ascending)
{
    beginResetModel();
    std::stable_sort(m_entries.begin(), m_entries.end(),
        [&](const QVariantMap &a, const QVariantMap &b) {
            bool less;
            if (column == QLatin1String("Target")) {
                less = a.value("Target").toString().compare(
                           b.value("Target").toString(), Qt::CaseInsensitive) < 0;
            } else if (column == QLatin1String("FITS Count")) {
                less = a.value("FITS Count").toInt() < b.value("FITS Count").toInt();
            } else {
                less = a.value("Total Integration Time s").toDouble()
                     < b.value("Total Integration Time s").toDouble();
            }
            return ascending ? less : !less;
        });
    endResetModel();
}

static QString normalizeTargetName(const QString &name)
{
    QString n = name.toUpper().simplified();
    n.remove(QLatin1Char(' '));
    return n;
}

double TargetSummaryModel::integrationSecondsForTarget(const QString &targetName) const
{
    const QString key = normalizeTargetName(targetName);
    for (const auto &e : m_entries) {
        if (normalizeTargetName(e.value("Target").toString()) == key)
            return e.value("Total Integration Time s").toDouble();
    }
    return 0.0;
}

int TargetSummaryModel::sessionCountForTarget(const QString &targetName) const
{
    const QString key = normalizeTargetName(targetName);
    for (const auto &e : m_entries) {
        if (normalizeTargetName(e.value("Target").toString()) == key)
            return e.value("FITS Count").toInt();
    }
    return 0;
}

CalibrationSummaryModel::CalibrationSummaryModel(QObject *parent) : QAbstractListModel(parent) {}

int CalibrationSummaryModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_entries.size();
}

QHash<int, QByteArray> CalibrationSummaryModel::roleNames() const
{
    return {
        {FrameTypeRole, "frameType"},
        {ExposureTimeRole, "exposureTime"},
        {GainRole, "gain"},
        {BinningRole, "binning"},
        {SensorTempRole, "sensorTemp"},
        {CountRole, "count"},
        {MostRecentRole, "mostRecent"}
    };
}

QVariant CalibrationSummaryModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_entries.size()) return {};
    const auto &e = m_entries[index.row()];
    switch (role) {
    case FrameTypeRole: return e.value("Frame Type");
    case ExposureTimeRole: return e.value("Exposure Time s");
    case GainRole: return e.value("Gain");
    case BinningRole: return e.value("Binning");
    case SensorTempRole: return e.value("Sensor Temp C");
    case CountRole: return e.value("Count");
    case MostRecentRole: return e.value("Most Recent");
    default: return {};
    }
}

void CalibrationSummaryModel::setEntries(const QVariantList &entries)
{
    beginResetModel();
    m_entries.clear();
    for (const auto &e : entries)
        m_entries.append(e.toMap());
    endResetModel();
}

CatalogModel::CatalogModel(QObject *parent) : QAbstractListModel(parent) {}

int CatalogModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_catalogs.size();
}

QHash<int, QByteArray> CatalogModel::roleNames() const
{
    return {
        {CatalogNameRole, "catalogName"},
        {CatalogCountRole, "catalogCount"}
    };
}

QVariant CatalogModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_catalogs.size()) return {};
    const auto &c = m_catalogs[index.row()];
    switch (role) {
    case CatalogNameRole: return c.name;
    case CatalogCountRole: return c.count;
    default: return {};
    }
}

void CatalogModel::clear()
{
    beginResetModel();
    m_catalogs.clear();
    endResetModel();
}

void CatalogModel::buildFromTargets(const QVariantList &targetSummary)
{
    beginResetModel();
    m_catalogs.clear();

    QMap<QString, int> counts = {
        {"Messier", 0}, {"NGC", 0}, {"IC", 0}, {"Caldwell", 0},
        {"Sharpless", 0}, {"Barnard", 0}, {"LDN", 0}, {"LBN", 0},
        {"Abell", 0}, {"PGC", 0}, {"UGC", 0}, {"Other", 0}
    };

    auto classify = [](const QString &name) -> QString {
        QString n = name.toUpper().trimmed();
        n.remove("MOSAIC").remove("PANEL").replace("-", " ");
        n = n.simplified();
        if (n.startsWith("M ")) return "Messier";
        if (n.startsWith("NGC")) return "NGC";
        if (n.startsWith("IC")) return "IC";
        if (n.startsWith("CALDWELL")) return "Caldwell";
        if (n.startsWith("SH2") || n.startsWith("SH ")) return "Sharpless";
        if (n.startsWith("BARNARD") || n.startsWith("B ")) return "Barnard";
        if (n.startsWith("LDN")) return "LDN";
        if (n.startsWith("LBN")) return "LBN";
        if (n.startsWith("ABELL")) return "Abell";
        if (n.startsWith("PGC")) return "PGC";
        if (n.startsWith("UGC")) return "UGC";
        return "Other";
    };

    for (const auto &entry : targetSummary) {
        QVariantMap map = entry.toMap();
        QString target = map.value("Target").toString();
        QString cat = classify(target);
        counts[cat]++;
    }

    for (auto it = counts.begin(); it != counts.end(); ++it)
        m_catalogs.append({it.key(), it.value()});

    endResetModel();
}
