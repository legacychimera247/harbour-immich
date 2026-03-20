#include "settingsmanager.h"
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>

SettingsManager::SettingsManager(QObject *parent)
    : QObject(parent)
{
}

QString SettingsManager::detailQuality() const
{
    return m_settings.value("detailQuality", "preview").toString();
}

void SettingsManager::setDetailQuality(const QString &quality)
{
    if (detailQuality() != quality) {
        m_settings.setValue("detailQuality", quality);
        emit detailQualityChanged();
    }
}

int SettingsManager::assetsPerRow() const
{
    return m_settings.value("assetsPerRow", 4).toInt();
}

void SettingsManager::setAssetsPerRow(int count)
{
    if (assetsPerRow() != count) {
        m_settings.setValue("assetsPerRow", count);
        emit assetsPerRowChanged();
    }
}

int SettingsManager::memoriesThumbnailSize() const
{
    return m_settings.value("memoriesThumbnailSize", 1).toInt();
}

void SettingsManager::setMemoriesThumbnailSize(int size)
{
    if (memoriesThumbnailSize() != size) {
        m_settings.setValue("memoriesThumbnailSize", size);
        emit memoriesThumbnailSizeChanged();
    }
}

bool SettingsManager::showMemoriesBar() const
{
    return m_settings.value("showMemoriesBar", true).toBool();
}

void SettingsManager::setShowMemoriesBar(bool show)
{
    if (showMemoriesBar() != show) {
        m_settings.setValue("showMemoriesBar", show);
        emit showMemoriesBarChanged();
    }
}

QString SettingsManager::scrollToTopPosition() const
{
    return m_settings.value("scrollToTopPosition", "right").toString();
}

void SettingsManager::setScrollToTopPosition(const QString &position)
{
    if (scrollToTopPosition() != position) {
        m_settings.setValue("scrollToTopPosition", position);
        emit scrollToTopPositionChanged();
    }
}

bool SettingsManager::coverShowAssets() const
{
    return m_settings.value("cover/showAssets", false).toBool();
}

void SettingsManager::setCoverShowAssets(bool show)
{
    if (coverShowAssets() != show) {
        m_settings.setValue("cover/showAssets", show);
        emit coverShowAssetsChanged();
    }
}

bool SettingsManager::coverSlideshow() const
{
    return m_settings.value("cover/slideshow", false).toBool();
}

void SettingsManager::setCoverSlideshow(bool enabled)
{
    if (coverSlideshow() != enabled) {
        m_settings.setValue("cover/slideshow", enabled);
        emit coverSlideshowChanged();
    }
}
