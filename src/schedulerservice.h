#pragma once
#include <QObject>
#include <QStringList>
#include <QHash>

// Stores per-night observation targets and persists them via QSettings.
class SchedulerService : public QObject
{
    Q_OBJECT
public:
    explicit SchedulerService(QObject *parent = nullptr);

    // Toggle an object in/out of the plan for a given date ("yyyy-MM-dd").
    Q_INVOKABLE void toggleObject(const QString &dateStr, const QString &objectName);

    Q_INVOKABLE bool        isScheduled(const QString &dateStr, const QString &objectName) const;
    Q_INVOKABLE QStringList objectsForDate(const QString &dateStr) const;
    Q_INVOKABLE int         countForDate(const QString &dateStr) const;

signals:
    void scheduleChanged();

private:
    void load();
    void save() const;

    QHash<QString, QStringList> m_schedule;
};
