#ifndef APPSETTINGS_H
#define APPSETTINGS_H

#include <QObject>
#include <QSettings>
#include <QString>

// Application-wide, persisted preferences shared by every window. Both the
// Image Viewer's Settings tab and the top-menu Preferences window edit the
// same values here, so a change in one is reflected live in the other.
class AppSettings : public QObject
{
    Q_OBJECT

    Q_PROPERTY(double stretchMin READ stretchMin WRITE setStretchMin NOTIFY stretchMinChanged)
    Q_PROPERTY(double stretchMax READ stretchMax WRITE setStretchMax NOTIFY stretchMaxChanged)
    Q_PROPERTY(double clipMin    READ clipMin    WRITE setClipMin    NOTIFY clipMinChanged)
    Q_PROPERTY(double clipMax    READ clipMax    WRITE setClipMax    NOTIFY clipMaxChanged)
    Q_PROPERTY(int    denoiseMax READ denoiseMax WRITE setDenoiseMax NOTIFY denoiseMaxChanged)

    Q_PROPERTY(QString cullSensitivity READ cullSensitivity WRITE setCullSensitivity NOTIFY cullSensitivityChanged)
    Q_PROPERTY(bool cullStarCount  READ cullStarCount  WRITE setCullStarCount  NOTIFY cullStarCountChanged)
    Q_PROPERTY(bool cullBrightness READ cullBrightness WRITE setCullBrightness NOTIFY cullBrightnessChanged)
    Q_PROPERTY(bool cullFwhm       READ cullFwhm       WRITE setCullFwhm       NOTIFY cullFwhmChanged)
    Q_PROPERTY(bool cullEcc        READ cullEcc        WRITE setCullEcc        NOTIFY cullEccChanged)
    Q_PROPERTY(bool cullNoise      READ cullNoise      WRITE setCullNoise      NOTIFY cullNoiseChanged)

    Q_PROPERTY(bool launchViewerOnSelect  READ launchViewerOnSelect  WRITE setLaunchViewerOnSelect  NOTIFY launchViewerOnSelectChanged)
    Q_PROPERTY(bool reuseViewerWindow     READ reuseViewerWindow     WRITE setReuseViewerWindow     NOTIFY reuseViewerWindowChanged)
    Q_PROPERTY(bool rememberViewerGeometry READ rememberViewerGeometry WRITE setRememberViewerGeometry NOTIFY rememberViewerGeometryChanged)
    Q_PROPERTY(bool confirmRejectDelete   READ confirmRejectDelete   WRITE setConfirmRejectDelete   NOTIFY confirmRejectDeleteChanged)

    Q_PROPERTY(QString astroFolder        READ astroFolder        WRITE setAstroFolder        NOTIFY astroFolderChanged)
    Q_PROPERTY(bool    seestarAutoImport  READ seestarAutoImport  WRITE setSeestarAutoImport  NOTIFY seestarAutoImportChanged)

    Q_PROPERTY(int viewerX      READ viewerX      WRITE setViewerX      NOTIFY viewerGeometryChanged)
    Q_PROPERTY(int viewerY      READ viewerY      WRITE setViewerY      NOTIFY viewerGeometryChanged)
    Q_PROPERTY(int viewerWidth  READ viewerWidth  WRITE setViewerWidth  NOTIFY viewerGeometryChanged)
    Q_PROPERTY(int viewerHeight READ viewerHeight WRITE setViewerHeight NOTIFY viewerGeometryChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    double stretchMin() const { return m_stretchMin; }
    double stretchMax() const { return m_stretchMax; }
    double clipMin()    const { return m_clipMin; }
    double clipMax()    const { return m_clipMax; }
    int    denoiseMax() const { return m_denoiseMax; }

    QString cullSensitivity() const { return m_cullSensitivity; }
    bool cullStarCount()  const { return m_cullStarCount; }
    bool cullBrightness() const { return m_cullBrightness; }
    bool cullFwhm()       const { return m_cullFwhm; }
    bool cullEcc()        const { return m_cullEcc; }
    bool cullNoise()      const { return m_cullNoise; }

    bool launchViewerOnSelect()   const { return m_launchViewerOnSelect; }
    bool reuseViewerWindow()      const { return m_reuseViewerWindow; }
    bool rememberViewerGeometry() const { return m_rememberViewerGeometry; }
    bool confirmRejectDelete()    const { return m_confirmRejectDelete; }

    QString astroFolder()       const { return m_astroFolder; }
    bool    seestarAutoImport() const { return m_seestarAutoImport; }

    int viewerX()      const { return m_viewerX; }
    int viewerY()      const { return m_viewerY; }
    int viewerWidth()  const { return m_viewerWidth; }
    int viewerHeight() const { return m_viewerHeight; }

    void setStretchMin(double v);
    void setStretchMax(double v);
    void setClipMin(double v);
    void setClipMax(double v);
    void setDenoiseMax(int v);

    void setCullSensitivity(const QString &v);
    void setCullStarCount(bool v);
    void setCullBrightness(bool v);
    void setCullFwhm(bool v);
    void setCullEcc(bool v);
    void setCullNoise(bool v);

    void setLaunchViewerOnSelect(bool v);
    void setReuseViewerWindow(bool v);
    void setRememberViewerGeometry(bool v);
    void setConfirmRejectDelete(bool v);

    void setAstroFolder(const QString &v);
    void setSeestarAutoImport(bool v);

    void setViewerX(int v);
    void setViewerY(int v);
    void setViewerWidth(int v);
    void setViewerHeight(int v);

    // Restores the Image Viewer stretch limits and Auto-Sort defaults to the
    // same values the old viewer "Reset to defaults" button used. Application
    // behaviour toggles are left untouched.
    Q_INVOKABLE void resetViewerDefaults();

signals:
    void stretchMinChanged();
    void stretchMaxChanged();
    void clipMinChanged();
    void clipMaxChanged();
    void denoiseMaxChanged();
    void cullSensitivityChanged();
    void cullStarCountChanged();
    void cullBrightnessChanged();
    void cullFwhmChanged();
    void cullEccChanged();
    void cullNoiseChanged();
    void launchViewerOnSelectChanged();
    void reuseViewerWindowChanged();
    void rememberViewerGeometryChanged();
    void confirmRejectDeleteChanged();
    void astroFolderChanged();
    void seestarAutoImportChanged();
    void viewerGeometryChanged();

private:
    QSettings m_settings;

    double m_stretchMin;
    double m_stretchMax;
    double m_clipMin;
    double m_clipMax;
    int    m_denoiseMax;

    QString m_cullSensitivity;
    bool m_cullStarCount;
    bool m_cullBrightness;
    bool m_cullFwhm;
    bool m_cullEcc;
    bool m_cullNoise;

    bool m_launchViewerOnSelect;
    bool m_reuseViewerWindow;
    bool m_rememberViewerGeometry;
    bool m_confirmRejectDelete;

    QString m_astroFolder;
    bool    m_seestarAutoImport;

    int m_viewerX;
    int m_viewerY;
    int m_viewerWidth;
    int m_viewerHeight;
};

#endif // APPSETTINGS_H
