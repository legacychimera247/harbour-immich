#ifndef BACKUPDATABASE_H
#define BACKUPDATABASE_H

#include <QObject>
#include <QSqlDatabase>
#include <QStringList>
#include <QSet>

class BackupDatabase : public QObject
{
    Q_OBJECT

public:
    enum Status {
        Pending = 0,
        Uploading = 1,
        BackedUp = 2,
        Failed = 3,
        DeletedOnServer = 4
    };
    Q_ENUM(Status)

    explicit BackupDatabase(QObject *parent = nullptr);
    ~BackupDatabase();

    bool initialize();

    // File tracking
    bool addFile(const QString &filePath, qint64 fileSize, qint64 fileModified);
    bool hasFile(const QString &filePath) const;
    bool hasFileChanged(const QString &filePath, qint64 fileSize, qint64 fileModified) const;
    bool removeFile(const QString &filePath);

    // Status updates
    bool setStatus(const QString &filePath, Status status, const QString &remoteAssetId = QString(), const QString &errorMessage = QString());
    Status fileStatus(const QString &filePath) const;

    // Queries
    QStringList pendingFiles(int limit = 100) const;
    QStringList failedFiles() const;
    QStringList backedUpFiles() const;
    int countByStatus(Status status) const;
    int totalTrackedFiles() const;

    // Remote asset correlation
    bool isRemoteAssetFromBackup(const QString &remoteAssetId) const;
    QSet<QString> allBackedUpRemoteAssetIds() const;
    QString remoteAssetIdForFile(const QString &filePath) const;
    QString filePathForRemoteAsset(const QString &remoteAssetId) const;

    // Manual upload integration
    bool registerManualUpload(const QString &filePath, qint64 fileSize, qint64 fileModified, const QString &remoteAssetId);

    // Server deletion
    bool markDeletedOnServer(const QString &remoteAssetId);
    QStringList deletedOnServerFiles() const;
    bool clearDeletedOnServer(const QString &filePath);

    // Device asset ID
    static QString makeDeviceAssetId(const QString &fileName, qint64 lastModifiedMs);

    // Retry failed uploads
    bool resetFailedFiles();
    bool resetFile(const QString &filePath);

    // Database management
    bool clearAll();

    // Pre-build from server comparison
    bool addFileAsBackedUp(const QString &filePath, qint64 fileSize, qint64 fileModified, const QString &remoteAssetId = QString());
    bool hasDeviceAssetId(const QString &deviceAssetId) const;
    QString deviceAssetIdForFile(const QString &filePath) const;

private:
    QSqlDatabase m_db;
    bool createTables();
};

#endif
