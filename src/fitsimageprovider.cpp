#include "fitsimageprovider.h"
#include <QFile>
#include <QUrl>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

FitsImageProvider::FitsImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{}

static inline double asinhStretch(double x, double a)
{
    return std::asinh(x / a) / std::asinh(1.0 / a);
}

struct StretchParams { double vmin, vmax; };

static StretchParams computeParams(const std::vector<float>& sorted, double p = 99.0)
{
    const int ns = static_cast<int>(sorted.size());
    if (ns == 0) return {0.0, 1.0};

    const double halfTail = (100.0 - p) * 0.005;
    const int lo = static_cast<int>((ns - 1) * halfTail);
    const int hi = static_cast<int>((ns - 1) * (1.0 - halfTail));

    const double vmin = sorted[lo];
    const double vmax = sorted[hi];

    if (vmax - vmin < 1e-6) return {vmin, vmin + 1.0};
    return {vmin, vmax};
}

static void applyBoxBlur(QImage& img, int r)
{
    if (r <= 0 || img.isNull()) return;
    const int W = img.width(), H = img.height();
    const bool isRGB = (img.format() == QImage::Format_RGB32);

    if (isRGB) {
        std::vector<int> rB(W), gB(W), bB(W), rO(W), gO(W), bO(W);
        for (int y = 0; y < H; ++y) {
            QRgb* row = reinterpret_cast<QRgb*>(img.scanLine(y));
            for (int x = 0; x < W; ++x) {
                rB[x] = qRed(row[x]); gB[x] = qGreen(row[x]); bB[x] = qBlue(row[x]);
            }
            int sR = 0, sG = 0, sB = 0;
            for (int k = 0; k <= std::min(r, W-1); ++k) { sR += rB[k]; sG += gB[k]; sB += bB[k]; }
            for (int x = 0; x < W; ++x) {
                const int w = std::min(x+r+1, W) - std::max(0, x-r);
                rO[x] = sR/w; gO[x] = sG/w; bO[x] = sB/w;
                if (x+r+1 < W) { sR += rB[x+r+1]; sG += gB[x+r+1]; sB += bB[x+r+1]; }
                if (x-r   >= 0) { sR -= rB[x-r];   sG -= gB[x-r];   sB -= bB[x-r]; }
            }
            for (int x = 0; x < W; ++x) row[x] = qRgb(rO[x], gO[x], bO[x]);
        }
        std::vector<int> rC(H), gC(H), bC(H), rCO(H), gCO(H), bCO(H);
        for (int x = 0; x < W; ++x) {
            for (int y = 0; y < H; ++y) {
                const QRgb p = reinterpret_cast<const QRgb*>(img.constScanLine(y))[x];
                rC[y] = qRed(p); gC[y] = qGreen(p); bC[y] = qBlue(p);
            }
            int sR = 0, sG = 0, sB = 0;
            for (int k = 0; k <= std::min(r, H-1); ++k) { sR += rC[k]; sG += gC[k]; sB += bC[k]; }
            for (int y = 0; y < H; ++y) {
                const int w = std::min(y+r+1, H) - std::max(0, y-r);
                rCO[y] = sR/w; gCO[y] = sG/w; bCO[y] = sB/w;
                if (y+r+1 < H) { sR += rC[y+r+1]; sG += gC[y+r+1]; sB += bC[y+r+1]; }
                if (y-r   >= 0) { sR -= rC[y-r];   sG -= gC[y-r];   sB -= bC[y-r]; }
            }
            for (int y = 0; y < H; ++y)
                reinterpret_cast<QRgb*>(img.scanLine(y))[x] = qRgb(rCO[y], gCO[y], bCO[y]);
        }
    } else {
        std::vector<int> buf(W), out(W);
        for (int y = 0; y < H; ++y) {
            uchar* row = img.scanLine(y);
            for (int x = 0; x < W; ++x) buf[x] = row[x];
            int s = 0;
            for (int k = 0; k <= std::min(r, W-1); ++k) s += buf[k];
            for (int x = 0; x < W; ++x) {
                out[x] = s / (std::min(x+r+1, W) - std::max(0, x-r));
                if (x+r+1 < W) s += buf[x+r+1];
                if (x-r   >= 0) s -= buf[x-r];
            }
            for (int x = 0; x < W; ++x) row[x] = static_cast<uchar>(out[x]);
        }
        std::vector<int> col(H), colO(H);
        for (int x = 0; x < W; ++x) {
            for (int y = 0; y < H; ++y) col[y] = img.constScanLine(y)[x];
            int s = 0;
            for (int k = 0; k <= std::min(r, H-1); ++k) s += col[k];
            for (int y = 0; y < H; ++y) {
                colO[y] = s / (std::min(y+r+1, H) - std::max(0, y-r));
                if (y+r+1 < H) s += col[y+r+1];
                if (y-r   >= 0) s -= col[y-r];
            }
            for (int y = 0; y < H; ++y) img.scanLine(y)[x] = static_cast<uchar>(colO[y]);
        }
    }
}

QImage FitsImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const int qmark = id.indexOf('?');
    const QString path = QUrl::fromPercentEncoding(
        (qmark >= 0 ? id.left(qmark) : id).toUtf8());

    double stretchA = 0.1, stretchP = 99.0;
    int    denoiseR = 0;
    if (qmark >= 0) {
        for (const auto& part : id.mid(qmark + 1).split('&')) {
            const int eq = part.indexOf('=');
            if (eq < 0) continue;
            const double val = part.mid(eq + 1).toDouble();
            const QString key = part.left(eq);
            if      (key == "a") stretchA = qBound(0.001, val, 10.0);
            else if (key == "p") stretchP = qBound(50.0,  val, 99.99);
            else if (key == "d") denoiseR = qBound(0, static_cast<int>(val), 10);
        }
    }

    if (path.endsWith(".jpg",  Qt::CaseInsensitive) ||
        path.endsWith(".jpeg", Qt::CaseInsensitive)) {
        QImage img;
        if (img.load(path)) {
            if (size) *size = img.size();
            return (requestedSize.isValid() && requestedSize != img.size())
                   ? img.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation)
                   : img;
        }
        return {};
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};

    int    bitpix = 0, naxis = 0, naxis1 = 0, naxis2 = 0, naxis3 = 1;
    double bzero  = 0.0, bscale = 1.0;
    QString bayerPat;
    bool   endFound = false;

    while (!endFound && !file.atEnd()) {
        const QByteArray block = file.read(2880);
        const int cards = block.size() / 80;
        for (int ci = 0; ci < cards; ++ci) {
            const char *c = block.constData() + ci * 80;
            if (std::strncmp(c, "END     ", 8) == 0) { endFound = true; break; }
            if (c[8] != '=') continue;

            const QByteArray key = QByteArray(c, 8).trimmed();
            int slashAt = 80;
            for (int j = 10; j < 80; ++j)
                if (c[j] == '/' && (j < 11 || c[j-1] != '\'')) { slashAt = j; break; }

            const QString valStr = QString::fromLatin1(c + 10, slashAt - 10).trimmed();
            const double  dval   = valStr.toDouble();
            const int     ival   = static_cast<int>(dval);

            if      (key == "BITPIX") bitpix = ival;
            else if (key == "NAXIS")  naxis  = ival;
            else if (key == "NAXIS1") naxis1 = ival;
            else if (key == "NAXIS2") naxis2 = ival;
            else if (key == "NAXIS3") naxis3 = ival;
            else if (key == "BZERO")  bzero  = dval;
            else if (key == "BSCALE") bscale = dval;
            else if (key == "BAYERPAT") {
                QString s = valStr;
                if (s.startsWith('\'')) s = s.mid(1);
                if (s.endsWith('\''))   s = s.left(s.size() - 1);
                s = s.trimmed().toUpper();
                if (s == "RGGB" || s == "GRBG" || s == "GBRG" || s == "BGGR")
                    bayerPat = s;
            }
        }
    }

    if (!endFound || naxis < 2 || naxis1 <= 0 || naxis2 <= 0)
        return {};

    const int    bpp     = std::abs(bitpix) / 8;
    const qint64 planes  = (naxis >= 3) ? naxis3 : 1;
    const qint64 ppPlane = (qint64)naxis1 * naxis2;
    const qint64 dataBytes = ppPlane * planes * bpp;

    if (dataBytes > 512LL * 1024 * 1024)
        return {};

    const QByteArray raw = file.read(dataBytes);
    file.close();
    if ((qint64)raw.size() < dataBytes)
        return {};

    const uchar *d = reinterpret_cast<const uchar *>(raw.constData());

    const auto px = [&](qint64 idx) -> float {
        const uchar *p = d + idx * bpp;
        double v = 0.0;
        switch (bitpix) {
        case 8:
            v = p[0];
            break;
        case 16: {
            const quint16 u = (quint16(p[0]) << 8) | p[1];
            v = static_cast<qint16>(u);
            break;
        }
        case 32: {
            const quint32 u = (quint32(p[0])<<24)|(quint32(p[1])<<16)|(quint32(p[2])<<8)|p[3];
            v = static_cast<qint32>(u);
            break;
        }
        case -32: {
            quint32 u = (quint32(p[0])<<24)|(quint32(p[1])<<16)|(quint32(p[2])<<8)|p[3];
            float f; std::memcpy(&f, &u, 4);
            v = f;
            break;
        }
        case -64: {
            quint64 u = 0;
            for (int b = 0; b < 8; ++b) u = (u << 8) | p[b];
            double f; std::memcpy(&f, &u, 8);
            v = f;
            break;
        }
        }
        return static_cast<float>(bzero + bscale * v);
    };

    const int kSampleN = std::min((int)ppPlane, 100000);
    const auto samplePlane = [&](qint64 off) -> std::vector<float> {
        const float step = (float)ppPlane / kSampleN;
        std::vector<float> s(kSampleN);
        for (int i = 0; i < kSampleN; ++i)
            s[i] = px(off + (qint64)(i * step));
        std::sort(s.begin(), s.end());
        return s;
    };

    const auto applyStretch = [&](qint64 off, const StretchParams& sp) -> std::vector<uchar> {
        const double range = sp.vmax - sp.vmin;
        std::vector<uchar> out(ppPlane);
        for (qint64 i = 0; i < ppPlane; ++i) {
            const double xn = std::max(0.0, std::min(1.0,
                              (static_cast<double>(px(off + i)) - sp.vmin) / range));
            out[i] = static_cast<uchar>(asinhStretch(xn, stretchA) * 255.0 + 0.5);
        }
        return out;
    };

    const int W = naxis1, H = naxis2;
    QImage image;

    if (!bayerPat.isEmpty() && planes == 1 && W >= 2 && H >= 2) {

        static constexpr int bayerTable[4][4] = {
            {0, 1, 1, 2},
            {1, 0, 2, 1},
            {1, 2, 0, 1},
            {2, 1, 1, 0},
        };
        const int patIdx = (bayerPat == "RGGB") ? 0 :
                           (bayerPat == "GRBG") ? 1 :
                           (bayerPat == "GBRG") ? 2 : 3;

        const auto bayerColor = [&](int x, int y) -> int {
            return bayerTable[patIdx][((y & 1) << 1) | (x & 1)];
        };

        const auto reflectCoord = [](int v, int max) -> int {
            if (v < 0)    return -v;
            if (v >= max) return 2 * max - 2 - v;
            return v;
        };
        const auto rp = [&](int x, int y) -> float {
            return px((qint64)reflectCoord(y, H) * W + reflectCoord(x, W));
        };

        int rDx = 0, rDy = 0, bDx = 0, bDy = 0;
        int g1Dx = 0, g1Dy = 0, g2Dx = 0, g2Dy = 0;
        bool foundG1 = false;
        for (int dy = 0; dy < 2; ++dy) {
            for (int dx = 0; dx < 2; ++dx) {
                const int c = bayerTable[patIdx][(dy << 1) | dx];
                if      (c == 0)   { rDx  = dx; rDy  = dy; }
                else if (c == 2)   { bDx  = dx; bDy  = dy; }
                else if (!foundG1) { g1Dx = dx; g1Dy = dy; foundG1 = true; }
                else               { g2Dx = dx; g2Dy = dy; }
            }
        }

        const int nBlocksX = W / 2;
        const int nBlocksY = H / 2;
        const int blockStride = std::max(1, (int)std::sqrt((double)(nBlocksX * nBlocksY) / 25000.0));

        std::vector<float> rSamp, gSamp, bSamp;
        rSamp.reserve(25000); gSamp.reserve(50000); bSamp.reserve(25000);

        for (int bby = 0; bby < nBlocksY; bby += blockStride) {
            for (int bbx = 0; bbx < nBlocksX; bbx += blockStride) {
                const int baseX = bbx * 2;
                const int baseY = bby * 2;
                rSamp.push_back(px((qint64)(baseY + rDy) * W + (baseX + rDx)));
                gSamp.push_back(px((qint64)(baseY + g1Dy) * W + (baseX + g1Dx)));
                gSamp.push_back(px((qint64)(baseY + g2Dy) * W + (baseX + g2Dx)));
                bSamp.push_back(px((qint64)(baseY + bDy) * W + (baseX + bDx)));
            }
        }
        std::sort(rSamp.begin(), rSamp.end());
        std::sort(gSamp.begin(), gSamp.end());
        std::sort(bSamp.begin(), bSamp.end());

        const auto pR = computeParams(rSamp, stretchP);
        const auto pG = computeParams(gSamp, stretchP);
        const auto pB = computeParams(bSamp, stretchP);

        image = QImage(W, H, QImage::Format_RGB32);
        for (int y = 0; y < H; ++y) {
            QRgb *line = reinterpret_cast<QRgb *>(image.scanLine(H - 1 - y));
            for (int x = 0; x < W; ++x) {
                const float p = px((qint64)y * W + x);
                const int   c = bayerColor(x, y);
                float r, g, b;

                if (c == 0) {
                    r = p;
                    g = (rp(x-1,y) + rp(x+1,y) + rp(x,y-1) + rp(x,y+1)) * 0.25f;
                    b = (rp(x-1,y-1) + rp(x+1,y-1) + rp(x-1,y+1) + rp(x+1,y+1)) * 0.25f;
                } else if (c == 2) {
                    b = p;
                    g = (rp(x-1,y) + rp(x+1,y) + rp(x,y-1) + rp(x,y+1)) * 0.25f;
                    r = (rp(x-1,y-1) + rp(x+1,y-1) + rp(x-1,y+1) + rp(x+1,y+1)) * 0.25f;
                } else {
                    g = p;
                    const int hc = bayerColor(x + 1, y);
                    const float hv = (rp(x-1,y) + rp(x+1,y)) * 0.5f;
                    const float vv = (rp(x,y-1) + rp(x,y+1)) * 0.5f;
                    if (hc == 0) { r = hv; b = vv; }
                    else         { b = hv; r = vv; }
                }

                const double rn = std::max(0.0, std::min(1.0, (r - pR.vmin) / (pR.vmax - pR.vmin)));
                const double gn = std::max(0.0, std::min(1.0, (g - pG.vmin) / (pG.vmax - pG.vmin)));
                const double bn = std::max(0.0, std::min(1.0, (b - pB.vmin) / (pB.vmax - pB.vmin)));

                line[x] = qRgb(
                    static_cast<int>(asinhStretch(rn, stretchA) * 255.0 + 0.5),
                    static_cast<int>(asinhStretch(gn, stretchA) * 255.0 + 0.5),
                    static_cast<int>(asinhStretch(bn, stretchA) * 255.0 + 0.5)
                );
            }
        }

    } else if (planes >= 3) {
        const auto p0 = computeParams(samplePlane(0),           stretchP);
        const auto p1 = computeParams(samplePlane(ppPlane),     stretchP);
        const auto p2 = computeParams(samplePlane(ppPlane * 2), stretchP);

        const auto R = applyStretch(0,           p0);
        const auto G = applyStretch(ppPlane,     p1);
        const auto B = applyStretch(ppPlane * 2, p2);

        image = QImage(W, H, QImage::Format_RGB32);
        for (int y = 0; y < H; ++y) {
            QRgb *line = reinterpret_cast<QRgb *>(image.scanLine(H - 1 - y));
            for (int x = 0; x < W; ++x) {
                const int i = y * W + x;
                line[x] = qRgb(R[i], G[i], B[i]);
            }
        }

    } else {
        const auto sp = computeParams(samplePlane(0), stretchP);
        const auto L  = applyStretch(0, sp);

        image = QImage(W, H, QImage::Format_Grayscale8);
        for (int y = 0; y < H; ++y) {
            uchar *line = image.scanLine(H - 1 - y);
            std::memcpy(line, L.data() + y * W, W);
        }
    }

    applyBoxBlur(image, denoiseR);

    if (size)
        *size = image.size();

    return (requestedSize.isValid() && requestedSize != image.size())
           ? image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation)
           : image;
}
