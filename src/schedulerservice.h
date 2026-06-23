#pragma once
#include <QObject>
#include <QStringList>
#include <QHash>
#include <QList>
#include <QVariantList>

class SchedulerService : public QObject
{
    Q_OBJECT
public:
    explicit SchedulerService(QObject *parent = nullptr);

    Q_INVOKABLE void toggleObject(const QString &dateStr, const QString &objectName);

    Q_INVOKABLE bool        isScheduled(const QString &dateStr, const QString &objectName) const;
    Q_INVOKABLE QStringList objectsForDate(const QString &dateStr) const;
    Q_INVOKABLE int         countForDate(const QString &dateStr) const;

    Q_INVOKABLE void addBlock(const QString &dateStr, const QString &objectName, int startMin, int endMin);
    Q_INVOKABLE void removeBlockAt(const QString &dateStr, int index);
    Q_INVOKABLE QVariantList blocksForDate(const QString &dateStr) const;

signals:
    void scheduleChanged();

private:
    struct Block { QString object; int start; int end; };

    void load();
    void save() const;

    QHash<QString, QStringList>  m_schedule;
    QHash<QString, QList<Block>> m_blocks;
};
