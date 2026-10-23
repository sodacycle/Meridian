#include "fitspixelreader.h"
#include <QFile>
#include <cstring>

FitsPixelData FitsPixelReader::read(const QString &filePath)
{
    FitsPixelData result;

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly))
        return result;

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
        return result;

    const int    bpp = std::abs(bitpix) / 8;
    if (bpp <= 0)
        return result;

    const qint64 planes    = (naxis >= 3) ? naxis3 : 1;
    const qint64 ppPlane   = (qint64)naxis1 * naxis2;
    const qint64 dataBytes = ppPlane * planes * bpp;

    if (dataBytes <= 0 || dataBytes > 512LL * 1024 * 1024)
        return result;

    const QByteArray raw = file.read(dataBytes);
    file.close();
    if ((qint64)raw.size() < dataBytes)
        return result;

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
        default:
            return 0.0f;
        }
        return static_cast<float>(bzero + bscale * v);
    };

    const int W = naxis1, H = naxis2;
    result.bayerPattern = bayerPat;

    if (!bayerPat.isEmpty() && planes == 1 && W >= 2 && H >= 2) {
        // Cheap 2x2 superpixel debayer: adequate for star detection,
        // not intended for colour-accurate display.
        const int W2 = W / 2, H2 = H / 2;
        result.width  = W2;
        result.height = H2;
        result.pixels.resize((size_t)W2 * H2);
        for (int by = 0; by < H2; ++by) {
            for (int bx = 0; bx < W2; ++bx) {
                const int x0 = bx * 2, y0 = by * 2;
                const float sum = px((qint64)y0 * W + x0)
                                 + px((qint64)y0 * W + x0 + 1)
                                 + px((qint64)(y0 + 1) * W + x0)
                                 + px((qint64)(y0 + 1) * W + x0 + 1);
                result.pixels[(size_t)by * W2 + bx] = sum * 0.25f;
            }
        }
    } else {
        result.width  = W;
        result.height = H;
        result.pixels.resize((size_t)ppPlane);
        if (planes >= 3) {
            for (qint64 i = 0; i < ppPlane; ++i)
                result.pixels[i] = (px(i) + px(i + ppPlane) + px(i + ppPlane * 2)) / 3.0f;
        } else {
            for (qint64 i = 0; i < ppPlane; ++i)
                result.pixels[i] = px(i);
        }
    }

    result.valid = true;
    return result;
}

FitsColorData FitsPixelReader::readColor(const QString &filePath, bool wantColor, bool fullRes)
{
    FitsColorData result;

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly))
        return result;

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
        return result;

    const int bpp = std::abs(bitpix) / 8;
    if (bpp <= 0)
        return result;

    const qint64 planes    = (naxis >= 3) ? naxis3 : 1;
    const qint64 ppPlane   = (qint64)naxis1 * naxis2;
    const qint64 dataBytes = ppPlane * planes * bpp;

    if (dataBytes <= 0 || dataBytes > 512LL * 1024 * 1024)
        return result;

    const QByteArray raw = file.read(dataBytes);
    file.close();
    if ((qint64)raw.size() < dataBytes)
        return result;

    const uchar *d = reinterpret_cast<const uchar *>(raw.constData());

    const auto px = [&](qint64 idx) -> float {
        const uchar *p = d + idx * bpp;
        double v = 0.0;
        switch (bitpix) {
        case 8:  v = p[0]; break;
        case 16: { const quint16 u = (quint16(p[0]) << 8) | p[1]; v = static_cast<qint16>(u); break; }
        case 32: { const quint32 u = (quint32(p[0])<<24)|(quint32(p[1])<<16)|(quint32(p[2])<<8)|p[3]; v = static_cast<qint32>(u); break; }
        case -32: { quint32 u = (quint32(p[0])<<24)|(quint32(p[1])<<16)|(quint32(p[2])<<8)|p[3]; float f; std::memcpy(&f, &u, 4); v = f; break; }
        case -64: { quint64 u = 0; for (int b = 0; b < 8; ++b) u = (u << 8) | p[b]; double f; std::memcpy(&f, &u, 8); v = f; break; }
        default: return 0.0f;
        }
        return static_cast<float>(bzero + bscale * v);
    };

    const int W = naxis1, H = naxis2;

    if (!bayerPat.isEmpty() && planes == 1 && W >= 2 && H >= 2) {
        static const int bayerTable[4][4] = {
            {0, 1, 1, 2}, {1, 0, 2, 1}, {1, 2, 0, 1}, {2, 1, 1, 0}
        };
        const int pat = (bayerPat == "RGGB") ? 0 : (bayerPat == "GRBG") ? 1
                      : (bayerPat == "GBRG") ? 2 : 3;

        if (wantColor && fullRes) {
            // Full-resolution bilinear demosaic (edge-reflected), producing W x H
            // R/G/B planes — the same interpolation the viewer uses for display.
            result.width  = W;
            result.height = H;
            result.channels = 3;
            result.luma.resize((size_t)ppPlane);
            result.r.resize((size_t)ppPlane);
            result.g.resize((size_t)ppPlane);
            result.b.resize((size_t)ppPlane);

            auto at = [&](int x, int y) -> float {
                const int rx = (x < 0) ? -x : (x >= W ? 2 * W - 2 - x : x);
                const int ry = (y < 0) ? -y : (y >= H ? 2 * H - 2 - y : y);
                return px((qint64)ry * W + rx);
            };
            auto colAt = [&](int x, int y) -> int {
                return bayerTable[pat][((y & 1) << 1) | (x & 1)];
            };

            for (int y = 0; y < H; ++y) {
                for (int x = 0; x < W; ++x) {
                    const float p = px((qint64)y * W + x);
                    const int c = colAt(x, y);
                    float R, G, B;
                    if (c == 0) {
                        R = p;
                        G = (at(x-1,y) + at(x+1,y) + at(x,y-1) + at(x,y+1)) * 0.25f;
                        B = (at(x-1,y-1) + at(x+1,y-1) + at(x-1,y+1) + at(x+1,y+1)) * 0.25f;
                    } else if (c == 2) {
                        B = p;
                        G = (at(x-1,y) + at(x+1,y) + at(x,y-1) + at(x,y+1)) * 0.25f;
                        R = (at(x-1,y-1) + at(x+1,y-1) + at(x-1,y+1) + at(x+1,y+1)) * 0.25f;
                    } else {
                        G = p;
                        const float hv = (at(x-1,y) + at(x+1,y)) * 0.5f;
                        const float vv = (at(x,y-1) + at(x,y+1)) * 0.5f;
                        if (colAt(x + 1, y) == 0) { R = hv; B = vv; }
                        else                      { B = hv; R = vv; }
                    }
                    const size_t o = (size_t)y * W + x;
                    result.r[o] = R;
                    result.g[o] = G;
                    result.b[o] = B;
                    result.luma[o] = (R + G + B) / 3.0f;
                }
            }
        } else {
            const int W2 = W / 2, H2 = H / 2;
            result.width  = W2;
            result.height = H2;
            result.luma.resize((size_t)W2 * H2);
            if (wantColor) {
                result.channels = 3;
                result.r.resize((size_t)W2 * H2);
                result.g.resize((size_t)W2 * H2);
                result.b.resize((size_t)W2 * H2);
            }
            for (int by = 0; by < H2; ++by) {
                for (int bx = 0; bx < W2; ++bx) {
                    const int x0 = bx * 2, y0 = by * 2;
                    float red = 0, blue = 0, g1 = 0, g2 = 0; bool haveG1 = false;
                    float sum = 0;
                    for (int dy = 0; dy < 2; ++dy) {
                        for (int dx = 0; dx < 2; ++dx) {
                            const float v = px((qint64)(y0 + dy) * W + (x0 + dx));
                            sum += v;
                            const int col = bayerTable[pat][(dy << 1) | dx];
                            if      (col == 0) red = v;
                            else if (col == 2) blue = v;
                            else if (!haveG1)  { g1 = v; haveG1 = true; }
                            else               g2 = v;
                        }
                    }
                    const size_t o = (size_t)by * W2 + bx;
                    result.luma[o] = sum * 0.25f;
                    if (wantColor) {
                        result.r[o] = red;
                        result.g[o] = (g1 + g2) * 0.5f;
                        result.b[o] = blue;
                    }
                }
            }
        }
    } else if (planes >= 3) {
        result.width  = W;
        result.height = H;
        result.luma.resize((size_t)ppPlane);
        if (wantColor) {
            result.channels = 3;
            result.r.resize((size_t)ppPlane);
            result.g.resize((size_t)ppPlane);
            result.b.resize((size_t)ppPlane);
        }
        for (qint64 i = 0; i < ppPlane; ++i) {
            const float rr = px(i), gg = px(i + ppPlane), bb = px(i + ppPlane * 2);
            result.luma[(size_t)i] = (rr + gg + bb) / 3.0f;
            if (wantColor) {
                result.r[(size_t)i] = rr;
                result.g[(size_t)i] = gg;
                result.b[(size_t)i] = bb;
            }
        }
    } else {
        result.width  = W;
        result.height = H;
        result.channels = 1;
        result.luma.resize((size_t)ppPlane);
        for (qint64 i = 0; i < ppPlane; ++i)
            result.luma[(size_t)i] = px(i);
    }

    if (result.channels == 1)
        result.r = result.luma;

    result.valid = true;
    return result;
}
