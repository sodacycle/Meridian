#ifndef FITSIMAGEPROVIDER_H
#define FITSIMAGEPROVIDER_H

#include <QQuickImageProvider>
#include <QImage>

class FitsImageProvider : public QQuickImageProvider
{
public:
    FitsImageProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};

#endif
