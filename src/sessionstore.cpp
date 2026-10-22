#include "sessionstore.h"

#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QSqlQuery>
#include <QSqlError>
#include <QVariant>

SessionStore::SessionStore(QObject *parent) : QObject(parent) {}

bool SessionStore::open()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (dir.isEmpty())
        return false;
    QDir().mkpath(dir);

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"));
    m_db.setDatabaseName(dir + QStringLiteral("/session.db"));
    if (!m_db.open())
        return false;

    QSqlQuery pragma(m_db);
    pragma.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    pragma.exec(QStringLiteral("PRAGMA synchronous=NORMAL"));

    ensureSchema();
    m_ready = true;
    return true;
}

void SessionStore::ensureSchema()
{
    QSqlQuery q(m_db);
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS files ("
        "path TEXT PRIMARY KEY, mtime INTEGER, size INTEGER, "
        "frameType TEXT, file TEXT, target TEXT, startTimeUtc TEXT, endTimeUtc TEXT, "
        "exposureTimeS REAL, numberOfSubs INTEGER, totalExposureTimeS REAL, "
        "telescope TEXT, cameraModel TEXT, sensorTemperatureC TEXT, ra TEXT, dec TEXT, "
        "latitude TEXT, longitude TEXT, binning TEXT, filterUsed TEXT, gain TEXT, "
        "focalLengthMm TEXT, apertureMm TEXT, focusPosition TEXT, imageType TEXT, "
        "stackingSoftware TEXT, rejected INTEGER)"));
    q.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS scan_dirs (path TEXT PRIMARY KEY)"));
    q.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)"));
}

bool SessionStore::hasSession() const
{
    return m_ready && fileCount() > 0;
}

int SessionStore::fileCount() const
{
    if (!m_ready) return 0;
    QSqlQuery q(m_db);
    if (q.exec(QStringLiteral("SELECT COUNT(*) FROM files")) && q.next())
        return q.value(0).toInt();
    return 0;
}

int SessionStore::directoryCount() const
{
    return savedDirectories().size();
}

QString SessionStore::lastScanText() const
{
    if (!m_ready) return QString();
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT value FROM meta WHERE key='last_scan'"));
    if (q.exec() && q.next())
        return q.value(0).toString();
    return QString();
}

QStringList SessionStore::savedDirectories() const
{
    QStringList dirs;
    if (!m_ready) return dirs;
    QSqlQuery q(m_db);
    if (q.exec(QStringLiteral("SELECT path FROM scan_dirs ORDER BY path"))) {
        while (q.next())
            dirs.append(q.value(0).toString());
    }
    return dirs;
}

static MetadataEntry entryFromQuery(const QSqlQuery &q)
{
    MetadataEntry e;
    e.path               = q.value(0).toString();
    e.fileMtime          = q.value(1).toLongLong();
    e.fileSize           = q.value(2).toLongLong();
    e.frameType          = q.value(3).toString();
    e.file               = q.value(4).toString();
    e.target             = q.value(5).toString();
    e.startTimeUtc       = q.value(6).toString();
    e.endTimeUtc         = q.value(7).toString();
    e.exposureTimeS      = q.value(8).toDouble();
    e.numberOfSubs       = q.value(9).toInt();
    e.totalExposureTimeS = q.value(10).toDouble();
    e.telescope          = q.value(11).toString();
    e.cameraModel        = q.value(12).toString();
    e.sensorTemperatureC = q.value(13).toString();
    e.ra                 = q.value(14).toString();
    e.dec                = q.value(15).toString();
    e.latitude           = q.value(16).toString();
    e.longitude          = q.value(17).toString();
    e.binning            = q.value(18).toString();
    e.filterUsed         = q.value(19).toString();
    e.gain               = q.value(20).toString();
    e.focalLengthMm      = q.value(21).toString();
    e.apertureMm         = q.value(22).toString();
    e.focusPosition      = q.value(23).toString();
    e.imageType          = q.value(24).toString();
    e.stackingSoftware   = q.value(25).toString();
    e.rejected           = q.value(26).toInt() != 0;
    return e;
}

static const QString kSelectCols = QStringLiteral(
    "path, mtime, size, frameType, file, target, startTimeUtc, endTimeUtc, "
    "exposureTimeS, numberOfSubs, totalExposureTimeS, telescope, cameraModel, "
    "sensorTemperatureC, ra, dec, latitude, longitude, binning, filterUsed, gain, "
    "focalLengthMm, apertureMm, focusPosition, imageType, stackingSoftware, rejected");

QList<MetadataEntry> SessionStore::loadAll() const
{
    QList<MetadataEntry> out;
    if (!m_ready) return out;
    QSqlQuery q(m_db);
    if (q.exec(QStringLiteral("SELECT ") + kSelectCols + QStringLiteral(" FROM files"))) {
        while (q.next())
            out.append(entryFromQuery(q));
    }
    return out;
}

QHash<QString, MetadataEntry> SessionStore::loadByPath() const
{
    QHash<QString, MetadataEntry> out;
    if (!m_ready) return out;
    QSqlQuery q(m_db);
    if (q.exec(QStringLiteral("SELECT ") + kSelectCols + QStringLiteral(" FROM files"))) {
        out.reserve(1024);
        while (q.next()) {
            MetadataEntry e = entryFromQuery(q);
            out.insert(e.path, e);
        }
    }
    return out;
}

void SessionStore::syncScan(const QStringList &scannedRoots, const QList<MetadataEntry> &entries)
{
    if (!m_ready) return;

    m_db.transaction();

    for (const QString &root : scannedRoots) {
        QSqlQuery del(m_db);
        del.prepare(QStringLiteral("DELETE FROM files WHERE instr(path, :prefix) = 1"));
        del.bindValue(QStringLiteral(":prefix"), root + QStringLiteral("/"));
        del.exec();
    }

    QSqlQuery ins(m_db);
    ins.prepare(QStringLiteral(
        "INSERT OR REPLACE INTO files (") + kSelectCols + QStringLiteral(") VALUES "
        "(:path, :mtime, :size, :frameType, :file, :target, :startTimeUtc, :endTimeUtc, "
        ":exposureTimeS, :numberOfSubs, :totalExposureTimeS, :telescope, :cameraModel, "
        ":sensorTemperatureC, :ra, :dec, :latitude, :longitude, :binning, :filterUsed, :gain, "
        ":focalLengthMm, :apertureMm, :focusPosition, :imageType, :stackingSoftware, :rejected)"));

    for (const MetadataEntry &e : entries) {
        ins.bindValue(QStringLiteral(":path"),               e.path);
        ins.bindValue(QStringLiteral(":mtime"),              e.fileMtime);
        ins.bindValue(QStringLiteral(":size"),               e.fileSize);
        ins.bindValue(QStringLiteral(":frameType"),          e.frameType);
        ins.bindValue(QStringLiteral(":file"),               e.file);
        ins.bindValue(QStringLiteral(":target"),             e.target);
        ins.bindValue(QStringLiteral(":startTimeUtc"),       e.startTimeUtc);
        ins.bindValue(QStringLiteral(":endTimeUtc"),         e.endTimeUtc);
        ins.bindValue(QStringLiteral(":exposureTimeS"),      e.exposureTimeS);
        ins.bindValue(QStringLiteral(":numberOfSubs"),       e.numberOfSubs);
        ins.bindValue(QStringLiteral(":totalExposureTimeS"), e.totalExposureTimeS);
        ins.bindValue(QStringLiteral(":telescope"),          e.telescope);
        ins.bindValue(QStringLiteral(":cameraModel"),        e.cameraModel);
        ins.bindValue(QStringLiteral(":sensorTemperatureC"), e.sensorTemperatureC);
        ins.bindValue(QStringLiteral(":ra"),                 e.ra);
        ins.bindValue(QStringLiteral(":dec"),                e.dec);
        ins.bindValue(QStringLiteral(":latitude"),           e.latitude);
        ins.bindValue(QStringLiteral(":longitude"),          e.longitude);
        ins.bindValue(QStringLiteral(":binning"),            e.binning);
        ins.bindValue(QStringLiteral(":filterUsed"),         e.filterUsed);
        ins.bindValue(QStringLiteral(":gain"),               e.gain);
        ins.bindValue(QStringLiteral(":focalLengthMm"),      e.focalLengthMm);
        ins.bindValue(QStringLiteral(":apertureMm"),         e.apertureMm);
        ins.bindValue(QStringLiteral(":focusPosition"),      e.focusPosition);
        ins.bindValue(QStringLiteral(":imageType"),          e.imageType);
        ins.bindValue(QStringLiteral(":stackingSoftware"),   e.stackingSoftware);
        ins.bindValue(QStringLiteral(":rejected"),           e.rejected ? 1 : 0);
        ins.exec();
    }

    QSqlQuery meta(m_db);
    meta.prepare(QStringLiteral("INSERT OR REPLACE INTO meta (key, value) VALUES ('last_scan', :v)"));
    meta.bindValue(QStringLiteral(":v"), QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm")));
    meta.exec();

    m_db.commit();
    emit changed();
}

void SessionStore::setDirectories(const QStringList &dirs)
{
    if (!m_ready) return;
    m_db.transaction();
    QSqlQuery clear(m_db);
    clear.exec(QStringLiteral("DELETE FROM scan_dirs"));
    QSqlQuery ins(m_db);
    ins.prepare(QStringLiteral("INSERT OR REPLACE INTO scan_dirs (path) VALUES (:p)"));
    for (const QString &d : dirs) {
        ins.bindValue(QStringLiteral(":p"), d);
        ins.exec();
    }
    m_db.commit();
    emit changed();
}

void SessionStore::startFresh()
{
    if (!m_ready) return;
    m_db.transaction();
    QSqlQuery q(m_db);
    q.exec(QStringLiteral("DELETE FROM files"));
    q.exec(QStringLiteral("DELETE FROM scan_dirs"));
    q.exec(QStringLiteral("DELETE FROM meta"));
    m_db.commit();
    emit changed();
}
