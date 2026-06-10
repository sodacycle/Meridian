#include "schedulerservice.h"
#include <QSettings>

SchedulerService::SchedulerService(QObject *parent)
    : QObject(parent)
{
    load();
}

void SchedulerService::toggleObject(const QString &dateStr, const QString &objectName)
{
    QStringList &list = m_schedule[dateStr];
    const int idx = list.indexOf(objectName);
    if (idx >= 0)
        list.removeAt(idx);
    else
        list.append(objectName);

    if (list.isEmpty())
        m_schedule.remove(dateStr);

    save();
    emit scheduleChanged();
}

bool SchedulerService::isScheduled(const QString &dateStr, const QString &objectName) const
{
    auto it = m_schedule.constFind(dateStr);
    return it != m_schedule.constEnd() && it->contains(objectName);
}

QStringList SchedulerService::objectsForDate(const QString &dateStr) const
{
    return m_schedule.value(dateStr);
}

int SchedulerService::countForDate(const QString &dateStr) const
{
    return m_schedule.value(dateStr).size();
}

void SchedulerService::load()
{
    QSettings s;
    const int n = s.beginReadArray("scheduler");
    for (int i = 0; i < n; ++i) {
        s.setArrayIndex(i);
        const QString date    = s.value("date").toString();
        const QStringList objs = s.value("objects").toStringList();
        if (!date.isEmpty() && !objs.isEmpty())
            m_schedule[date] = objs;
    }
    s.endArray();
}

void SchedulerService::save() const
{
    QSettings s;
    s.beginWriteArray("scheduler");
    int i = 0;
    for (auto it = m_schedule.constBegin(); it != m_schedule.constEnd(); ++it) {
        s.setArrayIndex(i++);
        s.setValue("date",    it.key());
        s.setValue("objects", it.value());
    }
    s.endArray();
}
