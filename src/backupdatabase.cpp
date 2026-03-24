#include "backupdatabase.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QStandardPaths>
#include <QDir>
#include <QFileInfo>
#include <QDebug>
#include <QDateTime>

BackupDatabase::BackupDatabase(QObject *parent)
    : QObject(parent)
{
}

BackupDatabase::~BackupDatabase()
{
    if (m_db.isOpen()) {
        m_db.close();
    }
}

bool BackupDatabase::initialize()
{
    QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataDir);
    QString dbPath = dataDir + "/backup.db";

    m_db = QSqlDatabase::addDatabase("QSQLITE", "backup_connection");
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        qWarning() << "BackupDatabase: Failed to open database:" << m_db.lastError().text();
        return false;
    }

    qInfo() << "BackupDatabase: Opened database at" << dbPath;

    // Enable WAL mode for better concurrent performance
    QSqlQuery pragma(m_db);
    pragma.exec("PRAGMA journal_mode=WAL");
    pragma.exec("PRAGMA synchronous=NORMAL");

    return createTables();
}

bool BackupDatabase::createTables()
{
    QSqlQuery query(m_db);

    bool ok = query.exec("CREATE TABLE IF NOT EXISTS backup_files ("
       "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
       "  file_path TEXT UNIQUE NOT NULL,"
       "  file_name TEXT NOT NULL,"
       "  file_size INTEGER NOT NULL,"
       "  file_modified INTEGER NOT NULL,"
       "  device_asset_id TEXT NOT NULL,"
       "  remote_asset_id TEXT DEFAULT '',"
       "  status INTEGER DEFAULT 0,"
       "  last_attempt INTEGER DEFAULT 0,"
       "  error_message TEXT DEFAULT '',"
       "  created_at INTEGER NOT NULL"
       ")"
   );

    if (!ok) {
        qWarning() << "BackupDatabase: Failed to create table:" << query.lastError().text();
        return false;
    }

    // Indexes for common queries
    query.exec("CREATE INDEX IF NOT EXISTS idx_status ON backup_files(status)");
    query.exec("CREATE INDEX IF NOT EXISTS idx_remote_asset ON backup_files(remote_asset_id)");
    query.exec("CREATE INDEX IF NOT EXISTS idx_device_asset ON backup_files(device_asset_id)");

    qInfo() << "BackupDatabase: Tables initialized";
    return true;
}

QString BackupDatabase::makeDeviceAssetId(const QString &fileName, qint64 lastModifiedMs)
{
    return QString("%1-%2").arg(fileName).arg(lastModifiedMs);
}

bool BackupDatabase::addFile(const QString &filePath, qint64 fileSize, qint64 fileModified)
{
    QFileInfo fi(filePath);
    QString deviceAssetId = makeDeviceAssetId(fi.fileName(), fileModified);

    QSqlQuery query(m_db);
    query.prepare("INSERT OR IGNORE INTO backup_files "
       "(file_path, file_name, file_size, file_modified, device_asset_id, status, created_at) "
       "VALUES (:path, :name, :size, :modified, :deviceId, :status, :created)"
   );
    query.bindValue(":path", filePath);
    query.bindValue(":name", fi.fileName());
    query.bindValue(":size", fileSize);
    query.bindValue(":modified", fileModified);
    query.bindValue(":deviceId", deviceAssetId);
    query.bindValue(":status", static_cast<int>(Pending));
    query.bindValue(":created", QDateTime::currentMSecsSinceEpoch());

    if (!query.exec()) {
        qWarning() << "BackupDatabase: Failed to add file:" << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool BackupDatabase::hasFile(const QString &filePath) const
{
    QSqlQuery query(m_db);
    query.prepare("SELECT 1 FROM backup_files WHERE file_path = :path LIMIT 1");
    query.bindValue(":path", filePath);
    query.exec();
    return query.next();
}

bool BackupDatabase::hasFileChanged(const QString &filePath, qint64 fileSize, qint64 fileModified) const
{
    QSqlQuery query(m_db);
    query.prepare("SELECT file_size, file_modified FROM backup_files WHERE file_path = :path LIMIT 1");
    query.bindValue(":path", filePath);
    query.exec();
    if (query.next()) {
        return query.value(0).toLongLong() != fileSize || query.value(1).toLongLong() != fileModified;
    }
    return true; // Not found = treat as changed
}

bool BackupDatabase::removeFile(const QString &filePath)
{
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM backup_files WHERE file_path = :path");
    query.bindValue(":path", filePath);
    return query.exec();
}

bool BackupDatabase::setStatus(const QString &filePath, Status status,
                               const QString &remoteAssetId, const QString &errorMessage)
{
    QSqlQuery query(m_db);

    if (!remoteAssetId.isEmpty()) {
        query.prepare("UPDATE backup_files SET status = :status, remote_asset_id = :remoteId, "
           "last_attempt = :attempt, error_message = :error WHERE file_path = :path"
       );
        query.bindValue(":remoteId", remoteAssetId);
    } else {
        query.prepare("UPDATE backup_files SET status = :status, "
           "last_attempt = :attempt, error_message = :error WHERE file_path = :path"
       );
    }

    query.bindValue(":status", static_cast<int>(status));
    query.bindValue(":attempt", QDateTime::currentMSecsSinceEpoch());
    query.bindValue(":error", errorMessage);
    query.bindValue(":path", filePath);

    if (!query.exec()) {
        qWarning() << "BackupDatabase: Failed to update status:" << query.lastError().text();
        return false;
    }
    return true;
}

BackupDatabase::Status BackupDatabase::fileStatus(const QString &filePath) const
{
    QSqlQuery query(m_db);
    query.prepare("SELECT status FROM backup_files WHERE file_path = :path LIMIT 1");
    query.bindValue(":path", filePath);
    query.exec();
    if (query.next()) {
        return static_cast<Status>(query.value(0).toInt());
    }
    return Pending;
}

QStringList BackupDatabase::pendingFiles(int limit) const
{
    QStringList files;
    QSqlQuery query(m_db);
    query.prepare("SELECT file_path FROM backup_files WHERE status = :status ORDER BY created_at ASC LIMIT :limit");
    query.bindValue(":status", static_cast<int>(Pending));
    query.bindValue(":limit", limit);
    query.exec();
    while (query.next()) {
        files.append(query.value(0).toString());
    }
    return files;
}

QStringList BackupDatabase::failedFiles() const
{
    QStringList files;
    QSqlQuery query(m_db);
    query.prepare("SELECT file_path FROM backup_files WHERE status = :status ORDER BY last_attempt ASC");
    query.bindValue(":status", static_cast<int>(Failed));
    query.exec();
    while (query.next()) {
        files.append(query.value(0).toString());
    }
    return files;
}

QStringList BackupDatabase::backedUpFiles() const
{
    QStringList files;
    QSqlQuery query(m_db);
    query.prepare("SELECT file_path FROM backup_files WHERE status = :status");
    query.bindValue(":status", static_cast<int>(BackedUp));
    query.exec();
    while (query.next()) {
        files.append(query.value(0).toString());
    }
    return files;
}

int BackupDatabase::countByStatus(Status status) const
{
    QSqlQuery query(m_db);
    query.prepare("SELECT COUNT(*) FROM backup_files WHERE status = :status");
    query.bindValue(":status", static_cast<int>(status));
    query.exec();
    if (query.next()) {
        return query.value(0).toInt();
    }
    return 0;
}

int BackupDatabase::totalTrackedFiles() const
{
    QSqlQuery query(m_db);
    query.exec("SELECT COUNT(*) FROM backup_files");
    if (query.next()) {
        return query.value(0).toInt();
    }
    return 0;
}

bool BackupDatabase::isRemoteAssetFromBackup(const QString &remoteAssetId) const
{
    if (remoteAssetId.isEmpty()) return false;
    QSqlQuery query(m_db);
    query.prepare("SELECT 1 FROM backup_files WHERE remote_asset_id = :id AND status = :status LIMIT 1");
    query.bindValue(":id", remoteAssetId);
    query.bindValue(":status", static_cast<int>(BackedUp));
    query.exec();
    return query.next();
}

QSet<QString> BackupDatabase::allBackedUpRemoteAssetIds() const
{
    QSet<QString> ids;
    QSqlQuery query(m_db);
    query.prepare("SELECT remote_asset_id FROM backup_files WHERE status = :status AND remote_asset_id != ''");
    query.bindValue(":status", static_cast<int>(BackedUp));
    query.exec();
    while (query.next()) {
        ids.insert(query.value(0).toString());
    }
    return ids;
}

QString BackupDatabase::remoteAssetIdForFile(const QString &filePath) const
{
    QSqlQuery query(m_db);
    query.prepare("SELECT remote_asset_id FROM backup_files WHERE file_path = :path LIMIT 1");
    query.bindValue(":path", filePath);
    query.exec();
    if (query.next()) {
        return query.value(0).toString();
    }
    return QString();
}

QString BackupDatabase::filePathForRemoteAsset(const QString &remoteAssetId) const
{
    if (remoteAssetId.isEmpty()) return QString();
    QSqlQuery query(m_db);
    query.prepare("SELECT file_path FROM backup_files WHERE remote_asset_id = :id LIMIT 1");
    query.bindValue(":id", remoteAssetId);
    query.exec();
    if (query.next()) {
        return query.value(0).toString();
    }
    return QString();
}

bool BackupDatabase::registerManualUpload(const QString &filePath, qint64 fileSize, qint64 fileModified, const QString &remoteAssetId)
{
    QFileInfo fi(filePath);
    QString deviceAssetId = makeDeviceAssetId(fi.fileName(), fileModified);

    QSqlQuery query(m_db);
    query.prepare("INSERT OR REPLACE INTO backup_files "
       "(file_path, file_name, file_size, file_modified, device_asset_id, "
       "remote_asset_id, status, last_attempt, created_at) "
       "VALUES (:path, :name, :size, :modified, :deviceId, :remoteId, :status, :attempt, :created)"
   );
    query.bindValue(":path", filePath);
    query.bindValue(":name", fi.fileName());
    query.bindValue(":size", fileSize);
    query.bindValue(":modified", fileModified);
    query.bindValue(":deviceId", deviceAssetId);
    query.bindValue(":remoteId", remoteAssetId);
    query.bindValue(":status", static_cast<int>(BackedUp));
    query.bindValue(":attempt", QDateTime::currentMSecsSinceEpoch());
    query.bindValue(":created", QDateTime::currentMSecsSinceEpoch());

    if (!query.exec()) {
        qWarning() << "BackupDatabase: Failed to register manual upload:" << query.lastError().text();
        return false;
    }
    return true;
}

bool BackupDatabase::markDeletedOnServer(const QString &remoteAssetId)
{
    if (remoteAssetId.isEmpty()) return false;
    QSqlQuery query(m_db);
    query.prepare("UPDATE backup_files SET status = :status WHERE remote_asset_id = :id");
    query.bindValue(":status", static_cast<int>(DeletedOnServer));
    query.bindValue(":id", remoteAssetId);
    return query.exec();
}

QStringList BackupDatabase::deletedOnServerFiles() const
{
    QStringList files;
    QSqlQuery query(m_db);
    query.prepare("SELECT file_path FROM backup_files WHERE status = :status");
    query.bindValue(":status", static_cast<int>(DeletedOnServer));
    query.exec();
    while (query.next()) {
        files.append(query.value(0).toString());
    }
    return files;
}

bool BackupDatabase::clearDeletedOnServer(const QString &filePath)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE backup_files SET status = :status WHERE file_path = :path AND status = :oldStatus");
    query.bindValue(":status", static_cast<int>(Pending));
    query.bindValue(":path", filePath);
    query.bindValue(":oldStatus", static_cast<int>(DeletedOnServer));
    return query.exec();
}

bool BackupDatabase::resetFailedFiles()
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE backup_files SET status = :newStatus, error_message = '' WHERE status = :oldStatus");
    query.bindValue(":newStatus", static_cast<int>(Pending));
    query.bindValue(":oldStatus", static_cast<int>(Failed));
    return query.exec();
}

bool BackupDatabase::resetFile(const QString &filePath)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE backup_files SET status = :status, error_message = '' WHERE file_path = :path");
    query.bindValue(":status", static_cast<int>(Pending));
    query.bindValue(":path", filePath);
    return query.exec();
}

bool BackupDatabase::clearAll()
{
    QSqlQuery query(m_db);
    if (!query.exec("DELETE FROM backup_files")) {
        qWarning() << "BackupDatabase: Failed to clear database:" << query.lastError().text();
        return false;
    }
    qInfo() << "BackupDatabase: Database cleared";
    return true;
}

bool BackupDatabase::addFileAsBackedUp(const QString &filePath, qint64 fileSize, qint64 fileModified, const QString &remoteAssetId)
{
    QFileInfo fi(filePath);
    QString deviceAssetId = makeDeviceAssetId(fi.fileName(), fileModified);

    QSqlQuery query(m_db);
    query.prepare("INSERT OR IGNORE INTO backup_files "
       "(file_path, file_name, file_size, file_modified, device_asset_id, "
       "remote_asset_id, status, last_attempt, created_at) "
       "VALUES (:path, :name, :size, :modified, :deviceId, :remoteId, :status, :attempt, :created)"
   );
    query.bindValue(":path", filePath);
    query.bindValue(":name", fi.fileName());
    query.bindValue(":size", fileSize);
    query.bindValue(":modified", fileModified);
    query.bindValue(":deviceId", deviceAssetId);
    query.bindValue(":remoteId", remoteAssetId.isEmpty() ? QString("") : remoteAssetId);
    query.bindValue(":status", static_cast<int>(BackedUp));
    query.bindValue(":attempt", QDateTime::currentMSecsSinceEpoch());
    query.bindValue(":created", QDateTime::currentMSecsSinceEpoch());

    if (!query.exec()) {
        qWarning() << "BackupDatabase: Failed to add file as backed up:" << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool BackupDatabase::hasDeviceAssetId(const QString &deviceAssetId) const
{
    QSqlQuery query(m_db);
    query.prepare("SELECT 1 FROM backup_files WHERE device_asset_id = :id LIMIT 1");
    query.bindValue(":id", deviceAssetId);
    query.exec();
    return query.next();
}

QString BackupDatabase::deviceAssetIdForFile(const QString &filePath) const
{
    QSqlQuery query(m_db);
    query.prepare("SELECT device_asset_id FROM backup_files WHERE file_path = :path LIMIT 1");
    query.bindValue(":path", filePath);
    query.exec();
    if (query.next()) {
        return query.value(0).toString();
    }
    return QString();
}
