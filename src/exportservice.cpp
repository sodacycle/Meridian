#include "exportservice.h"

#include <QFileDialog>
#include <QFile>
#include <QTextStream>
#include <QDateTime>

ExportService::ExportService(QObject *parent) : QObject(parent) {}

void ExportService::setData(const QVariantList &metadata,
                            const QStringList &columns,
                            const QVariantList &targets)
{
    m_metadata = metadata;
    m_columns  = columns;
    m_targets  = targets;
    emit dataChanged();
}

static QString csvField(const QString &value)
{
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
        QString escaped = value;
        escaped.replace('"', "\"\"");
        return '"' + escaped + '"';
    }
    return value;
}

static QString csvRow(const QStringList &fields)
{
    QStringList out;
    out.reserve(fields.size());
    for (const QString &f : fields)
        out.append(csvField(f));
    return out.join(',') + '\n';
}

static QString htmlEscape(const QString &value)
{
    QString v = value;
    v.replace('&', "&amp;");
    v.replace('<', "&lt;");
    v.replace('>', "&gt;");
    return v;
}

static const QStringList kTargetColumns = {
    "Target", "FITS Count", "Files With Exposure", "Total Integration Time"
};

static const QStringList kReportHistoryColumns = {
    "Frame Type", "File", "Target", "Start Time UTC", "Filter Used",
    "Exposure Time s", "Number of Subs", "Camera Model", "Telescope", "Rejected"
};

QString ExportService::writeFile(const QString &path, const QString &contents)
{
    if (path.isEmpty())
        return QString();

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit exportFinished(false, path);
        return QString();
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << contents;
    file.close();
    emit exportFinished(true, path);
    return path;
}

QString ExportService::exportTargetSummaryCsv()
{
    const QString path = QFileDialog::getSaveFileName(
        nullptr, "Export Target Summary (CSV)", "meridian-target-summary.csv",
        "CSV files (*.csv)");
    if (path.isEmpty())
        return QString();

    QString csv = csvRow(kTargetColumns);
    for (const QVariant &v : m_targets) {
        const QVariantMap row = v.toMap();
        QStringList fields;
        for (const QString &col : kTargetColumns)
            fields.append(row.value(col).toString());
        csv += csvRow(fields);
    }
    return writeFile(path, csv);
}

QString ExportService::exportSessionHistoryCsv()
{
    const QString path = QFileDialog::getSaveFileName(
        nullptr, "Export Session History (CSV)", "meridian-session-history.csv",
        "CSV files (*.csv)");
    if (path.isEmpty())
        return QString();

    QString csv = csvRow(m_columns);
    for (const QVariant &v : m_metadata) {
        const QVariantMap row = v.toMap();
        QStringList fields;
        for (const QString &col : m_columns)
            fields.append(row.value(col).toString());
        csv += csvRow(fields);
    }
    return writeFile(path, csv);
}

static QString htmlTable(const QStringList &columns, const QVariantList &rows)
{
    QString html = "<table>\n<thead><tr>";
    for (const QString &col : columns)
        html += "<th>" + htmlEscape(col) + "</th>";
    html += "</tr></thead>\n<tbody>\n";
    for (const QVariant &v : rows) {
        const QVariantMap row = v.toMap();
        const bool rejected = row.value("Rejected").toBool()
                              || row.value("Rejected").toString() == "true";
        html += rejected ? "<tr class=\"rejected\">" : "<tr>";
        for (const QString &col : columns)
            html += "<td>" + htmlEscape(row.value(col).toString()) + "</td>";
        html += "</tr>\n";
    }
    html += "</tbody>\n</table>\n";
    return html;
}

QString ExportService::exportReportHtml()
{
    const QString path = QFileDialog::getSaveFileName(
        nullptr, "Export Report (HTML)", "meridian-report.html",
        "HTML files (*.html *.htm)");
    if (path.isEmpty())
        return QString();

    double totalIntegration = 0.0;
    for (const QVariant &v : m_targets)
        totalIntegration += v.toMap().value("Total Integration Time s").toDouble();

    const QString generated = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm");

    QString html;
    html += "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n";
    html += "<meta charset=\"utf-8\">\n";
    html += "<title>Meridian Imaging Report</title>\n";
    html += "<style>\n"
            "  body { font-family: system-ui, sans-serif; margin: 32px; color: #1a1a1a; }\n"
            "  h1 { margin: 0 0 4px; font-size: 22px; }\n"
            "  .meta { color: #666; font-size: 13px; margin-bottom: 20px; }\n"
            "  h2 { font-size: 16px; margin: 28px 0 8px; border-bottom: 2px solid #ddd; padding-bottom: 4px; }\n"
            "  .stats { font-size: 13px; margin-bottom: 8px; }\n"
            "  table { border-collapse: collapse; width: 100%; font-size: 12px; }\n"
            "  th, td { border: 1px solid #ccc; padding: 4px 8px; text-align: left; }\n"
            "  th { background: #f0f0f0; }\n"
            "  tr:nth-child(even) td { background: #fafafa; }\n"
            "  tr.rejected td { color: #b00; text-decoration: line-through; }\n"
            "  @media print { body { margin: 0; } h2 { page-break-after: avoid; } tr { page-break-inside: avoid; } }\n"
            "</style>\n</head>\n<body>\n";

    html += "<h1>Meridian — Imaging Report</h1>\n";
    html += "<div class=\"meta\">Generated " + generated + "</div>\n";

    html += "<div class=\"stats\">"
            + QString::number(m_targets.size()) + " target(s) · "
            + QString::number(m_metadata.size()) + " FITS file(s) · "
            + QString::number(totalIntegration / 3600.0, 'f', 1) + " h total integration"
            + "</div>\n";

    html += "<h2>Target Summary</h2>\n";
    html += htmlTable(kTargetColumns, m_targets);

    html += "<h2>Session History</h2>\n";
    html += htmlTable(kReportHistoryColumns, m_metadata);

    html += "</body>\n</html>\n";

    return writeFile(path, html);
}
