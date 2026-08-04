#include "videocontroller.h"
#include "authmanager.h"
#include <QUrl>
#include <QUrlQuery>
#include <QMediaContent>
#include <QDebug>

VideoController::VideoController(QObject *parent)
    : QObject(parent)
    , m_player(new QMediaPlayer(this))
    , m_authManager(nullptr)
    , m_autoPlay(false)
    , m_loadedEmitted(false)
    , m_failed(false)
    , m_suppressErrors(false)
{
    connect(m_player, &QMediaPlayer::mediaStatusChanged, this, &VideoController::onMediaStatusChanged);
    connect(m_player, &QMediaPlayer::stateChanged, this, &VideoController::onStateChanged);
    connect(m_player, &QMediaPlayer::positionChanged, this, &VideoController::positionChanged);
    connect(m_player, &QMediaPlayer::durationChanged, this, &VideoController::durationChanged);
    connect(m_player, &QMediaPlayer::seekableChanged, this, &VideoController::seekableChanged);
    connect(m_player, static_cast<void (QMediaPlayer::*)(QMediaPlayer::Error)>(&QMediaPlayer::error), this, &VideoController::onError);
}

QObject *VideoController::player() const
{
    return m_player;
}

QObject *VideoController::mediaObject() const
{
    return m_player;
}

QObject *VideoController::authManager() const
{
    return m_authManager.data();
}

void VideoController::setAuthManager(QObject *authManager)
{
    AuthManager *am = qobject_cast<AuthManager *>(authManager);
    if (m_authManager.data() == am)
        return;
    m_authManager = am;
    emit authManagerChanged();
}

int VideoController::playbackState() const
{
    return static_cast<int>(m_player->state());
}

int VideoController::mediaStatus() const
{
    return static_cast<int>(m_player->mediaStatus());
}

qint64 VideoController::position() const
{
    return m_player->position();
}

qint64 VideoController::duration() const
{
    return m_player->duration();
}

bool VideoController::seekable() const
{
    return m_player->isSeekable();
}

int VideoController::error() const
{
    return static_cast<int>(m_player->error());
}

QString VideoController::errorString() const
{
    return m_player->errorString();
}

bool VideoController::failed() const
{
    return m_failed;
}

void VideoController::load(const QString &assetId)
{
    if (assetId.isEmpty()) {
        qInfo() << "VideoController: load skipped (empty assetId)";
        return;
    }

    m_assetId = assetId;
    m_autoPlay = true;
    m_loadedEmitted = false;
    setFailed(false);
    m_suppressErrors = true;
    m_player->stop();
    applyPendingSource();
}

void VideoController::unload()
{
    m_autoPlay = false;
    m_loadedEmitted = false;
    setFailed(false);
    m_suppressErrors = true;
    m_player->stop();
    m_assetId.clear();
}

void VideoController::play()
{
    m_autoPlay = true;
    m_player->play();
}

void VideoController::pause()
{
    m_autoPlay = false;
    m_player->pause();
}

void VideoController::stop()
{
    m_autoPlay = false;
    m_player->stop();
}

void VideoController::seek(qint64 position)
{
    m_player->setPosition(position);
}

void VideoController::applyPendingSource()
{
    if (m_assetId.isEmpty() || !m_autoPlay)
        return;
    if (!m_authManager) {
        qWarning() << "VideoController: no AuthManager set, cannot build source";
        return;
    }

    QUrl url(m_authManager->serverUrl() + QStringLiteral("/api/assets/") + m_assetId + QStringLiteral("/video/playback"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("sessionKey"), m_authManager->getAccessToken());
    url.setQuery(query);

    m_player->setMedia(QMediaContent(url));
}

void VideoController::onMediaStatusChanged(QMediaPlayer::MediaStatus status)
{
    emit mediaStatusChanged();

    switch (status) {
    case QMediaPlayer::LoadedMedia:
    case QMediaPlayer::BufferedMedia:
        m_suppressErrors = false;
        setFailed(false);
        if (!m_loadedEmitted) {
            m_loadedEmitted = true;
            emit loaded();
        }
        if (m_autoPlay && m_player->state() != QMediaPlayer::PlayingState)
            m_player->play();
        break;
    case QMediaPlayer::InvalidMedia:
        break;
    default:
        break;
    }
}

void VideoController::onError(QMediaPlayer::Error error)
{
    if (error == QMediaPlayer::NoError)
        return;

    if (m_suppressErrors || m_assetId.isEmpty()) {
        qInfo() << "VideoController: ignoring transient error" << error << m_player->errorString();
        return;
    }

    qWarning() << "VideoController: media error" << error << m_player->errorString() << "for" << m_assetId;
    emit errorChanged();
    setFailed(true);
}

void VideoController::onStateChanged(QMediaPlayer::State state)
{
    emit playbackStateChanged();

    if (state == QMediaPlayer::PlayingState) {
        m_autoPlay = false;
        m_suppressErrors = false;
        setFailed(false);
        if (!m_loadedEmitted) {
            m_loadedEmitted = true;
            emit loaded();
        }
    }
}

void VideoController::setFailed(bool failed)
{
    if (m_failed == failed)
        return;
    m_failed = failed;
    emit failedChanged();
}
