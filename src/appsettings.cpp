#include "appsettings.h"

// Keys mirror the QML Settings categories used before these preferences were
// centralised, so values saved by earlier builds (group "viewer" / "culling")
// are picked up unchanged. Application behaviour lives under group "app".
AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
    m_stretchMin = m_settings.value("viewer/stretchMin", 0.01).toDouble();
    m_stretchMax = m_settings.value("viewer/stretchMax", 2.0).toDouble();
    m_clipMin    = m_settings.value("viewer/clipMin", 90.0).toDouble();
    m_clipMax    = m_settings.value("viewer/clipMax", 99.9).toDouble();
    m_denoiseMax = m_settings.value("viewer/denoiseMax", 5).toInt();

    m_cullSensitivity = m_settings.value("culling/sensitivity", "balanced").toString();
    m_cullStarCount   = m_settings.value("culling/metricStarCount", true).toBool();
    m_cullBrightness  = m_settings.value("culling/metricBrightness", true).toBool();
    m_cullFwhm        = m_settings.value("culling/metricFwhm", true).toBool();
    m_cullEcc         = m_settings.value("culling/metricEcc", true).toBool();
    m_cullNoise       = m_settings.value("culling/metricNoise", true).toBool();

    m_launchViewerOnSelect   = m_settings.value("app/launchViewerOnSelect", true).toBool();
    m_reuseViewerWindow      = m_settings.value("app/reuseViewerWindow", true).toBool();
    m_rememberViewerGeometry = m_settings.value("app/rememberViewerGeometry", false).toBool();
    m_confirmRejectDelete    = m_settings.value("app/confirmRejectDelete", true).toBool();

    m_astroFolder       = m_settings.value("app/astroFolder", QString()).toString();
    m_seestarAutoImport = m_settings.value("app/seestarAutoImport", false).toBool();

    m_viewerX      = m_settings.value("app/viewerX", -1).toInt();
    m_viewerY      = m_settings.value("app/viewerY", -1).toInt();
    m_viewerWidth  = m_settings.value("app/viewerWidth", -1).toInt();
    m_viewerHeight = m_settings.value("app/viewerHeight", -1).toInt();
}

void AppSettings::setStretchMin(double v)
{
    if (qFuzzyCompare(m_stretchMin, v)) return;
    m_stretchMin = v;
    m_settings.setValue("viewer/stretchMin", v);
    emit stretchMinChanged();
}

void AppSettings::setStretchMax(double v)
{
    if (qFuzzyCompare(m_stretchMax, v)) return;
    m_stretchMax = v;
    m_settings.setValue("viewer/stretchMax", v);
    emit stretchMaxChanged();
}

void AppSettings::setClipMin(double v)
{
    if (qFuzzyCompare(m_clipMin, v)) return;
    m_clipMin = v;
    m_settings.setValue("viewer/clipMin", v);
    emit clipMinChanged();
}

void AppSettings::setClipMax(double v)
{
    if (qFuzzyCompare(m_clipMax, v)) return;
    m_clipMax = v;
    m_settings.setValue("viewer/clipMax", v);
    emit clipMaxChanged();
}

void AppSettings::setDenoiseMax(int v)
{
    if (m_denoiseMax == v) return;
    m_denoiseMax = v;
    m_settings.setValue("viewer/denoiseMax", v);
    emit denoiseMaxChanged();
}

void AppSettings::setCullSensitivity(const QString &v)
{
    if (m_cullSensitivity == v) return;
    m_cullSensitivity = v;
    m_settings.setValue("culling/sensitivity", v);
    emit cullSensitivityChanged();
}

void AppSettings::setCullStarCount(bool v)
{
    if (m_cullStarCount == v) return;
    m_cullStarCount = v;
    m_settings.setValue("culling/metricStarCount", v);
    emit cullStarCountChanged();
}

void AppSettings::setCullBrightness(bool v)
{
    if (m_cullBrightness == v) return;
    m_cullBrightness = v;
    m_settings.setValue("culling/metricBrightness", v);
    emit cullBrightnessChanged();
}

void AppSettings::setCullFwhm(bool v)
{
    if (m_cullFwhm == v) return;
    m_cullFwhm = v;
    m_settings.setValue("culling/metricFwhm", v);
    emit cullFwhmChanged();
}

void AppSettings::setCullEcc(bool v)
{
    if (m_cullEcc == v) return;
    m_cullEcc = v;
    m_settings.setValue("culling/metricEcc", v);
    emit cullEccChanged();
}

void AppSettings::setCullNoise(bool v)
{
    if (m_cullNoise == v) return;
    m_cullNoise = v;
    m_settings.setValue("culling/metricNoise", v);
    emit cullNoiseChanged();
}

void AppSettings::setLaunchViewerOnSelect(bool v)
{
    if (m_launchViewerOnSelect == v) return;
    m_launchViewerOnSelect = v;
    m_settings.setValue("app/launchViewerOnSelect", v);
    emit launchViewerOnSelectChanged();
}

void AppSettings::setReuseViewerWindow(bool v)
{
    if (m_reuseViewerWindow == v) return;
    m_reuseViewerWindow = v;
    m_settings.setValue("app/reuseViewerWindow", v);
    emit reuseViewerWindowChanged();
}

void AppSettings::setRememberViewerGeometry(bool v)
{
    if (m_rememberViewerGeometry == v) return;
    m_rememberViewerGeometry = v;
    m_settings.setValue("app/rememberViewerGeometry", v);
    emit rememberViewerGeometryChanged();
}

void AppSettings::setConfirmRejectDelete(bool v)
{
    if (m_confirmRejectDelete == v) return;
    m_confirmRejectDelete = v;
    m_settings.setValue("app/confirmRejectDelete", v);
    emit confirmRejectDeleteChanged();
}

void AppSettings::setAstroFolder(const QString &v)
{
    if (m_astroFolder == v) return;
    m_astroFolder = v;
    m_settings.setValue("app/astroFolder", v);
    emit astroFolderChanged();
}

void AppSettings::setSeestarAutoImport(bool v)
{
    if (m_seestarAutoImport == v) return;
    m_seestarAutoImport = v;
    m_settings.setValue("app/seestarAutoImport", v);
    emit seestarAutoImportChanged();
}

void AppSettings::setViewerX(int v)
{
    if (m_viewerX == v) return;
    m_viewerX = v;
    m_settings.setValue("app/viewerX", v);
    emit viewerGeometryChanged();
}

void AppSettings::setViewerY(int v)
{
    if (m_viewerY == v) return;
    m_viewerY = v;
    m_settings.setValue("app/viewerY", v);
    emit viewerGeometryChanged();
}

void AppSettings::setViewerWidth(int v)
{
    if (m_viewerWidth == v) return;
    m_viewerWidth = v;
    m_settings.setValue("app/viewerWidth", v);
    emit viewerGeometryChanged();
}

void AppSettings::setViewerHeight(int v)
{
    if (m_viewerHeight == v) return;
    m_viewerHeight = v;
    m_settings.setValue("app/viewerHeight", v);
    emit viewerGeometryChanged();
}

void AppSettings::resetViewerDefaults()
{
    setStretchMin(0.01);
    setStretchMax(2.0);
    setClipMin(90.0);
    setClipMax(99.9);
    setDenoiseMax(5);
    setCullSensitivity("balanced");
    setCullStarCount(true);
    setCullBrightness(true);
    setCullFwhm(true);
    setCullEcc(true);
    setCullNoise(true);
}
