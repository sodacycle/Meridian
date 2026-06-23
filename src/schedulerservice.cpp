#include "schedulerservice.h"
#include <QSettings>
#include <QVariantMap>

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

void SchedulerService::addBlock(const QString &dateStr, const QString &objectName, int startMin, int endMin)
{
    if (dateStr.isEmpty() || objectName.isEmpty() || endMin <= startMin)
        return;
    m_blocks[dateStr].append({objectName, startMin, endMin});
    save();
    emit scheduleChanged();
}

void SchedulerService::removeBlockAt(const QString &dateStr, int index)
{
    auto it = m_blocks.find(dateStr);
    if (it == m_blocks.end() || index < 0 || index >= it->size())
        return;
    it->removeAt(index);
    if (it->isEmpty())
        m_blocks.erase(it);
    save();
    emit scheduleChanged();
}

QVariantList SchedulerService::blocksForDate(const QString &dateStr) const
{
    QVariantList out;
    const QList<Block> blocks = m_blocks.value(dateStr);
    for (int i = 0; i < blocks.size(); ++i) {
        QVariantMap m;
        m["object"] = blocks[i].object;
        m["start"]  = blocks[i].start;
        m["end"]    = blocks[i].end;
        m["index"]  = i;
        out.append(m);
    }
    return out;
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

    const int bn = s.beginReadArray("scheduler_blocks");
    for (int i = 0; i < bn; ++i) {
        s.setArrayIndex(i);
        const QString date  = s.value("date").toString();
        const QString obj   = s.value("object").toString();
        const int start = s.value("start").toInt();
        const int end   = s.value("end").toInt();
        if (!date.isEmpty() && !obj.isEmpty() && end > start)
            m_blocks[date].append({obj, start, end});
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

    s.beginWriteArray("scheduler_blocks");
    int bi = 0;
    for (auto it = m_blocks.constBegin(); it != m_blocks.constEnd(); ++it) {
        for (const Block &b : it.value()) {
            s.setArrayIndex(bi++);
            s.setValue("date",   it.key());
            s.setValue("object", b.object);
            s.setValue("start",  b.start);
            s.setValue("end",    b.end);
        }
    }
    s.endArray();
}
