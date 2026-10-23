#include "stackingservice.h"
#include "fitspixelreader.h"
#include "starfinder.h"

#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDataStream>
#include <QHash>
#include <QList>
#include <QDateTime>
#include <QRegularExpression>
#include <QtConcurrentRun>
#include <algorithm>
#include <cmath>
#include <vector>

namespace {

struct Offset {
    bool   ok = false;
    double dx = 0.0;
    double dy = 0.0;
};

// Translation-only registration by offset voting: every pairing of a bright
// reference star with a bright frame star proposes a shift; the true shift is
// the one a whole constellation agrees on, so it collects far more votes than
// the random pairings scattered around it.
Offset matchOffset(const std::vector<StarPoint> &ref, const std::vector<StarPoint> &frm)
{
    Offset result;
    const int K = 40;
    const int nr = std::min<int>((int)ref.size(), K);
    const int nf = std::min<int>((int)frm.size(), K);
    if (nr < 4 || nf < 4)
        return result;

    auto key = [](int dx, int dy) -> qint64 {
        return ((qint64)(dx + 100000) << 20) | (qint64)(dy + 100000);
    };

    QHash<qint64, int> votes;
    votes.reserve(nr * nf);
    for (int i = 0; i < nr; ++i) {
        for (int j = 0; j < nf; ++j) {
            const int dx = (int)std::lround(frm[j].x - ref[i].x);
            const int dy = (int)std::lround(frm[j].y - ref[i].y);
            votes[key(dx, dy)]++;
        }
    }

    qint64 bestKey = 0;
    int    bestVotes = 0;
    for (auto it = votes.constBegin(); it != votes.constEnd(); ++it) {
        if (it.value() > bestVotes) { bestVotes = it.value(); bestKey = it.key(); }
    }

    if (bestVotes < 4 || bestVotes < nr / 4)
        return result;

    const int bdx = (int)((bestKey >> 20) & 0x1FFFFF) - 100000;
    const int bdy = (int)(bestKey & 0x1FFFFF) - 100000;

    // Sub-pixel refine: average the real offsets of all pairs that fall within
    // two pixels of the winning bin.
    double sumX = 0.0, sumY = 0.0;
    int    n = 0;
    for (int i = 0; i < nr; ++i) {
        for (int j = 0; j < nf; ++j) {
            const double dx = frm[j].x - ref[i].x;
            const double dy = frm[j].y - ref[i].y;
            if (std::abs(dx - bdx) <= 2.0 && std::abs(dy - bdy) <= 2.0) {
                sumX += dx; sumY += dy; ++n;
            }
        }
    }
    if (n == 0)
        return result;

    result.ok = true;
    result.dx = sumX / n;
    result.dy = sumY / n;
    return result;
}

QByteArray fitsCard(const QString &text)
{
    QByteArray b = text.toLatin1();
    b.truncate(80);
    while (b.size() < 80) b.append(' ');
    return b;
}

QByteArray fitsKeyword(const QString &key, const QString &valueField)
{
    return fitsCard(QString("%1= %2").arg(key, -8).arg(valueField, 20));
}

QByteArray fitsString(const QString &key, const QString &value)
{
    QString v = value;
    v.replace('\'', ' ');
    if (v.size() < 8) v = v.leftJustified(8, ' ');
    return fitsCard(QString("%1= '%2'").arg(key, -8).arg(v));
}

bool writeFloatFits(const QString &path, int W, int H, int channels,
                    const std::vector<float> &pixels,
                    const QString &object, int stackCount)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;

    QByteArray header;
    header += fitsKeyword("SIMPLE", "T");
    header += fitsKeyword("BITPIX", "-32");
    header += fitsKeyword("NAXIS", channels >= 3 ? "3" : "2");
    header += fitsKeyword("NAXIS1", QString::number(W));
    header += fitsKeyword("NAXIS2", QString::number(H));
    if (channels >= 3)
        header += fitsKeyword("NAXIS3", "3");
    header += fitsKeyword("BZERO", "0.0");
    header += fitsKeyword("BSCALE", "1.0");
    if (!object.isEmpty())
        header += fitsString("OBJECT", object);
    header += fitsKeyword("STACKCNT", QString::number(stackCount));
    header += fitsString("CREATOR", "Meridian");
    header += fitsString("DATE", QDateTime::currentDateTimeUtc().toString("yyyy-MM-dd"));
    header += fitsCard("END");

    while (header.size() % 2880 != 0)
        header += fitsCard("");
    if (file.write(header) != header.size()) { file.close(); return false; }

    QDataStream ds(&file);
    ds.setByteOrder(QDataStream::BigEndian);
    ds.setFloatingPointPrecision(QDataStream::SinglePrecision);
    for (float v : pixels)
        ds << v;

    const qint64 dataBytes = (qint64)pixels.size() * 4;
    qint64 pad = (2880 - (dataBytes % 2880)) % 2880;
    if (pad > 0) {
        QByteArray zeros(pad, '\0');
        file.write(zeros);
    }

    file.close();
    return true;
}

} // namespace

StackingService::StackingService(QObject *parent)
    : QObject(parent)
{
    m_watcher = new QFutureWatcher<StackResult>(this);
    connect(m_watcher, &QFutureWatcher<StackResult>::finished,
            this, &StackingService::onFinished);
}

void StackingService::reportProgress(int done, int total, const QString &phase)
{
    m_done  = done;
    m_total = total;
    m_phase = phase;
    emit progressChanged();
}

void StackingService::cancel()
{
    if (m_stacking)
        m_cancel.storeRelease(1);
}

void StackingService::integrate(const QStringList &paths,
                                const QString &referencePath,
                                const QString &targetName,
                                bool align,
                                const QString &combineMethod,
                                const QString &outputMode)
{
    if (m_stacking)
        return;

    QStringList frames = paths;
    frames.removeAll(QString());
    if (frames.size() < 2) {
        m_resultPath.clear();
        m_framesUsed = 0;
        m_framesTotal = frames.size();
        m_lastError = "At least two frames are needed to stack.";
        emit resultChanged();
        emit finished(false, QString(), m_lastError);
        return;
    }

    QString reference = referencePath;
    if (reference.isEmpty() || !frames.contains(reference))
        reference = frames.first();

    const bool sigmaClip = (combineMethod.compare("sigma", Qt::CaseInsensitive) == 0
                            || combineMethod.contains("sigma", Qt::CaseInsensitive));

    // Plane ids: 0 = luma, 1 = R, 2 = G, 3 = B. The selected set defines the
    // output channels (one for mono / single-channel, three for colour).
    const QString mode = outputMode.trimmed().toLower();
    QList<int> sel;
    QString modeTag;
    if (mode == "color" || mode == "colour" || mode == "rgb") { sel = {1, 2, 3}; modeTag = "color"; }
    else if (mode == "r" || mode == "red")                    { sel = {1};       modeTag = "R"; }
    else if (mode == "g" || mode == "green")                  { sel = {2};       modeTag = "G"; }
    else if (mode == "b" || mode == "blue")                   { sel = {3};       modeTag = "B"; }
    else                                                      { sel = {0};       modeTag = "mono"; }
    const bool wantColor = (modeTag != "mono");

    m_cancel.storeRelease(0);
    m_stacking = true;
    m_resultPath.clear();
    m_lastError.clear();
    m_framesUsed = 0;
    m_framesTotal = frames.size();
    m_done = 0;
    m_total = frames.size();
    m_phase = "Preparing";
    emit stackingChanged();
    emit progressChanged();
    emit resultChanged();

    const QString object = targetName;

    QFuture<StackResult> future = QtConcurrent::run(
        [this, frames, reference, object, align, sigmaClip, wantColor, sel, modeTag]() -> StackResult
    {
        StackResult res;
        res.framesTotal = frames.size();

        auto progress = [this](int done, int total, const QString &phase) {
            QMetaObject::invokeMethod(this, "reportProgress", Qt::QueuedConnection,
                                      Q_ARG(int, done), Q_ARG(int, total),
                                      Q_ARG(QString, phase));
        };
        auto canceled = [this]() { return m_cancel.loadAcquire() != 0; };

        auto lumaOf = [](const FitsColorData &c) -> FitsPixelData {
            FitsPixelData p;
            p.valid = c.valid; p.width = c.width; p.height = c.height; p.pixels = c.luma;
            return p;
        };
        auto planeOf = [](const FitsColorData &c, int id) -> const std::vector<float> & {
            switch (id) { case 1: return c.r; case 2: return c.g; case 3: return c.b; default: return c.luma; }
        };

        const FitsColorData refData = FitsPixelReader::readColor(reference, wantColor);
        if (!refData.valid || refData.width < 2 || refData.height < 2) {
            res.error = "Could not read the reference frame.";
            return res;
        }
        if (wantColor && refData.channels != 3) {
            res.error = "These frames are not colour (OSC or 3-plane). Choose Mono.";
            return res;
        }
        const int W = refData.width, H = refData.height;
        const qint64 N = (qint64)W * H;
        const int C = sel.size();
        const int refChannels = refData.channels;

        std::vector<StarPoint> refStars;
        if (align) {
            refStars = StarFinder::detectStars(lumaOf(refData), 60);
            if (refStars.size() < 4) {
                res.error = "The reference frame has too few stars to align to.";
                return res;
            }
        }

        // Phase 1: per-frame registration offsets (reference is 0,0).
        std::vector<Offset> offsets(frames.size());
        for (int i = 0; i < frames.size(); ++i) {
            if (canceled()) { res.error = "Canceled."; return res; }
            progress(i, frames.size(), "Aligning");

            if (frames[i] == reference) {
                offsets[i].ok = true;
                offsets[i].dx = 0.0;
                offsets[i].dy = 0.0;
                continue;
            }
            if (!align) {
                offsets[i].ok = true;
                continue;
            }
            const FitsColorData d = FitsPixelReader::readColor(frames[i], wantColor);
            if (!d.valid || d.width != W || d.height != H || d.channels != refChannels)
                continue;
            const std::vector<StarPoint> stars = StarFinder::detectStars(lumaOf(d), 60);
            offsets[i] = matchOffset(refStars, stars);
        }

        // Phase 2: accumulate per-channel mean (and variance, for sigma clipping).
        std::vector<double> mean((size_t)C * N, 0.0);
        std::vector<double> m2((size_t)C * N, 0.0);
        std::vector<int>    cnt((size_t)N, 0);
        int used = 0;

        for (int i = 0; i < frames.size(); ++i) {
            if (canceled()) { res.error = "Canceled."; return res; }
            if (!offsets[i].ok) continue;
            progress(i, frames.size(), sigmaClip ? "Measuring" : "Combining");

            const FitsColorData d = FitsPixelReader::readColor(frames[i], wantColor);
            if (!d.valid || d.width != W || d.height != H || d.channels != refChannels)
                continue;

            std::vector<const std::vector<float> *> src(C);
            for (int ci = 0; ci < C; ++ci) src[ci] = &planeOf(d, sel[ci]);

            const int rx = (int)std::lround(offsets[i].dx);
            const int ry = (int)std::lround(offsets[i].dy);
            ++used;

            for (int oy = 0; oy < H; ++oy) {
                const int sy = oy + ry;
                if (sy < 0 || sy >= H) continue;
                for (int ox = 0; ox < W; ++ox) {
                    const int sx = ox + rx;
                    if (sx < 0 || sx >= W) continue;
                    const qint64 p = (qint64)oy * W + ox;
                    const qint64 sp = (qint64)sy * W + sx;
                    const int n = ++cnt[(size_t)p];
                    for (int ci = 0; ci < C; ++ci) {
                        const double v = (*src[ci])[(size_t)sp];
                        double &mn = mean[(size_t)ci * N + p];
                        const double delta = v - mn;
                        mn += delta / n;
                        m2[(size_t)ci * N + p] += delta * (v - mn);
                    }
                }
            }
        }

        if (used < 2) {
            res.error = align
                ? "Fewer than two frames could be aligned to the reference."
                : "Fewer than two frames could be read.";
            return res;
        }

        std::vector<float> out((size_t)C * N, 0.0f);

        if (!sigmaClip) {
            for (size_t k = 0; k < (size_t)C * N; ++k)
                out[k] = (float)mean[k];
        } else {
            // Phase 3: clipped mean, re-reading frames with their stored offsets.
            const double kappa = 3.0;
            std::vector<double> clipSum((size_t)C * N, 0.0);
            std::vector<int>    clipCnt((size_t)C * N, 0);

            for (int i = 0; i < frames.size(); ++i) {
                if (canceled()) { res.error = "Canceled."; return res; }
                if (!offsets[i].ok) continue;
                progress(i, frames.size(), "Combining");

                const FitsColorData d = FitsPixelReader::readColor(frames[i], wantColor);
                if (!d.valid || d.width != W || d.height != H || d.channels != refChannels)
                    continue;

                std::vector<const std::vector<float> *> src(C);
                for (int ci = 0; ci < C; ++ci) src[ci] = &planeOf(d, sel[ci]);

                const int rx = (int)std::lround(offsets[i].dx);
                const int ry = (int)std::lround(offsets[i].dy);

                for (int oy = 0; oy < H; ++oy) {
                    const int sy = oy + ry;
                    if (sy < 0 || sy >= H) continue;
                    for (int ox = 0; ox < W; ++ox) {
                        const int sx = ox + rx;
                        if (sx < 0 || sx >= W) continue;
                        const qint64 p = (qint64)oy * W + ox;
                        if (cnt[(size_t)p] < 2) continue;
                        const qint64 sp = (qint64)sy * W + sx;
                        for (int ci = 0; ci < C; ++ci) {
                            const size_t cp = (size_t)ci * N + p;
                            const double sigma = std::sqrt(std::max(0.0, m2[cp] / cnt[(size_t)p]));
                            const double v = (*src[ci])[(size_t)sp];
                            if (sigma <= 0.0 || std::abs(v - mean[cp]) <= kappa * sigma) {
                                clipSum[cp] += v;
                                clipCnt[cp] += 1;
                            }
                        }
                    }
                }
            }

            for (size_t k = 0; k < (size_t)C * N; ++k)
                out[k] = clipCnt[k] > 0 ? (float)(clipSum[k] / clipCnt[k]) : (float)mean[k];
        }

        if (canceled()) { res.error = "Canceled."; return res; }
        progress(frames.size(), frames.size(), "Writing");

        QString baseName = object.trimmed();
        baseName.replace(QRegularExpression("[^A-Za-z0-9_-]+"), "_");
        if (baseName.isEmpty()) baseName = "stack";

        const QDir refDir = QFileInfo(reference).absoluteDir();
        QDir outDir(refDir.absoluteFilePath("stacked"));
        if (!outDir.exists())
            refDir.mkpath("stacked");

        const QString method = sigmaClip ? "sigma" : "avg";
        const QString outPath = outDir.absoluteFilePath(
            QString("Stacked_%1_%2f_%3_%4.fit").arg(baseName).arg(used).arg(method).arg(modeTag));

        if (!writeFloatFits(outPath, W, H, C, out, object, used)) {
            res.error = "Could not write the stacked FITS file.";
            return res;
        }

        res.ok = true;
        res.outputPath = outPath;
        res.framesUsed = used;
        return res;
    });

    m_watcher->setFuture(future);
}

void StackingService::onFinished()
{
    const StackResult res = m_watcher->future().result();

    m_stacking = false;
    m_framesUsed  = res.framesUsed;
    m_framesTotal = res.framesTotal;

    if (res.ok) {
        m_resultPath = res.outputPath;
        m_lastError.clear();
    } else {
        m_resultPath.clear();
        m_lastError = res.error;
    }

    emit stackingChanged();
    emit resultChanged();
    emit finished(res.ok, res.outputPath, res.error);
}
