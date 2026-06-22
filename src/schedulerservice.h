#pragma once
#include <QObject>
#include <QStringList>
#include <QHash>

class SchedulerService : public QObject
{
    Q_OBJECT
public:
    explicit SchedulerService(QObject *parent = nullptr);

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
