#include "stackingservice.h"
#include "fitspixelreader.h"
#include "starfinder.h"
#include "fitsparser.h"
#include "fitsscanner.h"

#include <QFile>
#include <QFileInfo>
#include <QFileInfoList>
#include <QDir>
#include <QFileDialog>
#include <QDataStream>
#include <QHash>
#include <QSet>
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

// Maps a reference coordinate to the frame's coordinate:
//   frame = [[a, b], [c, d]] * ref + (tx, ty)
struct Transform {
    bool   ok = false;
    double a = 1.0, b = 0.0, c = 0.0, d = 1.0, tx = 0.0, ty = 0.0;
};

// Gaussian elimination with partial pivoting for a 3x3 system.
bool solve3x3(const double S[3][3], const double rhs[3], double out[3])
{
    double m[3][4];
    for (int i = 0; i < 3; ++i) {
        for (int j = 0; j < 3; ++j) m[i][j] = S[i][j];
        m[i][3] = rhs[i];
    }
    for (int col = 0; col < 3; ++col) {
        int piv = col;
        for (int r = col + 1; r < 3; ++r)
            if (std::abs(m[r][col]) > std::abs(m[piv][col])) piv = r;
        if (std::abs(m[piv][col]) < 1e-9) return false;
        for (int j = 0; j < 4; ++j) std::swap(m[col][j], m[piv][j]);
        for (int r = 0; r < 3; ++r) {
            if (r == col) continue;
            const double f = m[r][col] / m[col][col];
            for (int j = col; j < 4; ++j) m[r][j] -= f * m[col][j];
        }
    }
    for (int i = 0; i < 3; ++i) out[i] = m[i][3] / m[i][i];
    return true;
}

// Rotation-aware registration. Each reference star-pair and frame star-pair of
// similar separation proposes a similarity transform (rotation + scale +
// translation); the proposal with the most reference stars landing on a frame
// star wins (a RANSAC-style vote through descriptor-matched pairs), then the
// inlier correspondences are refined into a full affine by least squares.
Transform estimateTransform(const std::vector<StarPoint> &ref, const std::vector<StarPoint> &frm)
{
    Transform best;
    const int K = std::min<int>(25, std::min<int>((int)ref.size(), (int)frm.size()));
    if (K < 3)
        return best;

    struct Pair { int i, j; double dist; };
    auto buildPairs = [](const std::vector<StarPoint> &s, int k) {
        std::vector<Pair> p;
        p.reserve((size_t)k * (k - 1) / 2);
        for (int i = 0; i < k; ++i)
            for (int j = i + 1; j < k; ++j) {
                const double dx = s[j].x - s[i].x, dy = s[j].y - s[i].y;
                p.push_back({ i, j, std::sqrt(dx * dx + dy * dy) });
            }
        return p;
    };
    const std::vector<Pair> rp = buildPairs(ref, K);
    std::vector<Pair> fp = buildPairs(frm, K);
    std::sort(fp.begin(), fp.end(), [](const Pair &x, const Pair &y) { return x.dist < y.dist; });

    const double inlierTol2 = 2.5 * 2.5;
    const int    minInliers = std::max(5, K / 4);
    const int    acceptInliers = (int)(0.7 * K);
    const int    maxHypo = 40000;

    int    bestInliers = 0;
    double bu = 1.0, bv = 0.0, btx = 0.0, bty = 0.0;
    int    hypo = 0;

    for (const Pair &r : rp) {
        if (r.dist < 5.0) continue;
        const double distTol = std::max(2.0, 0.02 * r.dist);
        int fi = (int)(std::lower_bound(fp.begin(), fp.end(), r.dist - distTol,
                       [](const Pair &p, double v) { return p.dist < v; }) - fp.begin());
        for (; fi < (int)fp.size() && fp[fi].dist <= r.dist + distTol; ++fi) {
            const Pair &f = fp[fi];
            for (int opt = 0; opt < 2; ++opt) {
                if (++hypo > maxHypo) { fi = (int)fp.size(); break; }
                const StarPoint &P1 = ref[r.i], &P2 = ref[r.j];
                const StarPoint &Q1 = (opt == 0) ? frm[f.i] : frm[f.j];
                const StarPoint &Q2 = (opt == 0) ? frm[f.j] : frm[f.i];
                const double rx = P2.x - P1.x, ry = P2.y - P1.y;
                const double qx = Q2.x - Q1.x, qy = Q2.y - Q1.y;
                const double rr = rx * rx + ry * ry;
                if (rr < 1e-6) continue;
                const double u = (qx * rx + qy * ry) / rr;
                const double v = (qy * rx - qx * ry) / rr;
                const double scale2 = u * u + v * v;
                if (scale2 < 0.25 || scale2 > 4.0) continue;
                const double tx = Q1.x - (u * P1.x - v * P1.y);
                const double ty = Q1.y - (v * P1.x + u * P1.y);

                int inl = 0;
                for (int s = 0; s < K; ++s) {
                    const double X = u * ref[s].x - v * ref[s].y + tx;
                    const double Y = v * ref[s].x + u * ref[s].y + ty;
                    for (int t = 0; t < K; ++t) {
                        const double ddx = frm[t].x - X, ddy = frm[t].y - Y;
                        if (ddx * ddx + ddy * ddy < inlierTol2) { ++inl; break; }
                    }
                }
                if (inl > bestInliers) {
                    bestInliers = inl; bu = u; bv = v; btx = tx; bty = ty;
                }
            }
            if (bestInliers >= acceptInliers) break;
        }
        if (bestInliers >= acceptInliers || hypo > maxHypo) break;
    }

    if (bestInliers < minInliers)
        return best;

    // Collect inlier correspondences (over all detected stars) and refine to a
    // full affine by least squares.
    double Sxx = 0, Sxy = 0, Sx = 0, Syy = 0, Sy = 0, Sn = 0;
    double bXx = 0, bXy = 0, bX = 0, bYx = 0, bYy = 0, bY = 0;
    for (size_t s = 0; s < ref.size(); ++s) {
        const double X = bu * ref[s].x - bv * ref[s].y + btx;
        const double Y = bv * ref[s].x + bu * ref[s].y + bty;
        int bt = -1; double bd = inlierTol2;
        for (size_t t = 0; t < frm.size(); ++t) {
            const double ddx = frm[t].x - X, ddy = frm[t].y - Y;
            const double dd = ddx * ddx + ddy * ddy;
            if (dd < bd) { bd = dd; bt = (int)t; }
        }
        if (bt < 0) continue;
        const double x = ref[s].x, y = ref[s].y;
        const double fx = frm[bt].x, fy = frm[bt].y;
        Sxx += x * x; Sxy += x * y; Sx += x; Syy += y * y; Sy += y; Sn += 1;
        bXx += fx * x; bXy += fx * y; bX += fx;
        bYx += fy * x; bYy += fy * y; bY += fy;
    }

    const double S[3][3] = { { Sxx, Sxy, Sx }, { Sxy, Syy, Sy }, { Sx, Sy, Sn } };
    double sol1[3], sol2[3];
    const double rhsX[3] = { bXx, bXy, bX };
    const double rhsY[3] = { bYx, bYy, bY };
    if (Sn >= 3 && solve3x3(S, rhsX, sol1) && solve3x3(S, rhsY, sol2)) {
        best.a = sol1[0]; best.b = sol1[1]; best.tx = sol1[2];
        best.c = sol2[0]; best.d = sol2[1]; best.ty = sol2[2];
    } else {
        best.a = bu; best.b = -bv; best.c = bv; best.d = bu; best.tx = btx; best.ty = bty;
    }
    best.ok = true;
    return best;
}

// Affine composition: result maps x -> A(B(x)).
Transform composeT(const Transform &A, const Transform &B)
{
    Transform r;
    r.ok = A.ok && B.ok;
    r.a = A.a * B.a + A.b * B.c;
    r.b = A.a * B.b + A.b * B.d;
    r.c = A.c * B.a + A.d * B.c;
    r.d = A.c * B.b + A.d * B.d;
    r.tx = A.a * B.tx + A.b * B.ty + A.tx;
    r.ty = A.c * B.tx + A.d * B.ty + A.ty;
    return r;
}

bool invertT(const Transform &T, Transform &out)
{
    const double det = T.a * T.d - T.b * T.c;
    if (std::abs(det) < 1e-9)
        return false;
    out.a =  T.d / det; out.b = -T.b / det;
    out.c = -T.c / det; out.d =  T.a / det;
    out.tx = -(out.a * T.tx + out.b * T.ty);
    out.ty = -(out.c * T.tx + out.d * T.ty);
    out.ok = true;
    return true;
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

QStringList StackingService::selectCalibrationFolder()
{
    const QString dir = QFileDialog::getExistingDirectory(nullptr,
        QStringLiteral("Select a folder of calibration frames"));
    if (dir.isEmpty())
        return {};

    static const QStringList filters = { "*.fit", "*.fits", "*.FIT", "*.FITS" };
    const QFileInfoList fl = QDir(dir).entryInfoList(filters, QDir::Files);
    QStringList files;
    files.reserve(fl.size());
    for (const QFileInfo &fi : fl)
        files << fi.absoluteFilePath();
    files.sort(Qt::CaseInsensitive);
    return files;
}

QVariantMap StackingService::autoMatchCalibration(const QStringList &lightPaths)
{
    QVariantMap result;
    QStringList darks, flats, bias;
    if (lightPaths.isEmpty())
        return result;

    // Reference light: exposure, temperature, and raw dimensions.
    const QHash<QString, QVariant> refHdr = FitsParser::parseHeader(lightPaths.first());
    const double lightExp = FitsScanner::anyField(refHdr, {"EXPTIME", "EXPOSURE", "EXPOSURE_TIME"}, "0").toDouble();
    const int    lw = FitsScanner::anyField(refHdr, {"NAXIS1"}, "0").toInt();
    const int    lh = FitsScanner::anyField(refHdr, {"NAXIS2"}, "0").toInt();
    bool         lightHasTemp = false;
    const double lightTemp = FitsScanner::anyField(refHdr, {"CCD-TEMP", "CCD_TEMP"}, "").toDouble(&lightHasTemp);
    if (lw <= 0 || lh <= 0)
        return result;

    // Candidate calibration folders: darks/flats/bias sitting beside the lights
    // (sibling folders, and one directory up — e.g. a lights/ folder's parent).
    QSet<QString> darkDirs, flatDirs, biasDirs;
    auto addCandidates = [&](const QString &base) {
        const QDir d(base);
        const QStringList subs = d.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &s : subs) {
            const QString low = s.toLower();
            const QString abs = d.absoluteFilePath(s);
            if (low == "darks" || low == "dark")        darkDirs.insert(abs);
            else if (low == "flats" || low == "flat")   flatDirs.insert(abs);
            else if (low == "bias" || low == "biases")  biasDirs.insert(abs);
        }
    };
    QSet<QString> lightDirs;
    for (const QString &p : lightPaths)
        lightDirs.insert(QFileInfo(p).absolutePath());
    for (const QString &ld : lightDirs) {
        addCandidates(ld);
        addCandidates(QFileInfo(ld).absolutePath());
    }

    static const QStringList filters = { "*.fit", "*.fits", "*.FIT", "*.FITS" };
    auto gather = [&](const QSet<QString> &dirs, bool matchExposure, QStringList &out) {
        for (const QString &dir : dirs) {
            const QFileInfoList fl = QDir(dir).entryInfoList(filters, QDir::Files);
            for (const QFileInfo &fi : fl) {
                const QHash<QString, QVariant> h = FitsParser::parseHeader(fi.absoluteFilePath());
                if (FitsScanner::anyField(h, {"NAXIS1"}, "0").toInt() != lw ||
                    FitsScanner::anyField(h, {"NAXIS2"}, "0").toInt() != lh)
                    continue;
                if (matchExposure) {
                    const double e = FitsScanner::anyField(h, {"EXPTIME", "EXPOSURE", "EXPOSURE_TIME"}, "0").toDouble();
                    if (std::abs(e - lightExp) > std::max(0.5, 0.05 * lightExp))
                        continue;
                    bool hasT = false;
                    const double t = FitsScanner::anyField(h, {"CCD-TEMP", "CCD_TEMP"}, "").toDouble(&hasT);
                    if (lightHasTemp && hasT && std::abs(t - lightTemp) > 5.0)
                        continue;
                }
                out << fi.absoluteFilePath();
            }
        }
    };
    gather(darkDirs, true, darks);
    gather(flatDirs, false, flats);
    gather(biasDirs, false, bias);

    darks.sort(Qt::CaseInsensitive);
    flats.sort(Qt::CaseInsensitive);
    bias.sort(Qt::CaseInsensitive);
    result["darks"] = darks;
    result["flats"] = flats;
    result["bias"]  = bias;
    return result;
}

void StackingService::integrate(const QStringList &paths,
                                const QString &referencePath,
                                const QString &targetName,
                                bool align,
                                const QString &combineMethod,
                                const QString &outputMode,
                                bool autoBalance,
                                const QVariantMap &calibration,
                                const QVariantList &panelIds,
                                bool mosaic)
{
    if (m_stacking)
        return;

    // Build the frame list and its parallel panel assignment in lockstep, so
    // dropping blanks keeps the two aligned. Panels only matter for mosaics.
    const bool havePanels = mosaic && align && panelIds.size() == paths.size();
    QStringList frames;
    std::vector<int> panels;
    frames.reserve(paths.size());
    panels.reserve(paths.size());
    for (int i = 0; i < paths.size(); ++i) {
        if (paths[i].isEmpty())
            continue;
        frames << paths[i];
        panels.push_back(havePanels ? panelIds[i].toInt() : 0);
    }
    const bool mosaicRun = havePanels && frames.size() >= 2;
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

    const int refPanel = mosaicRun ? panels[frames.indexOf(reference)] : 0;

    const bool sigmaClip = (combineMethod.compare("sigma", Qt::CaseInsensitive) == 0
                            || combineMethod.contains("sigma", Qt::CaseInsensitive));

    // Plane ids: 0 = luma, 1 = R, 2 = G, 3 = B. The selected set defines the
    // output channels (one for mono / single-channel, three for colour).
    const QString mode = outputMode.trimmed().toLower();
    QList<int> sel;
    QString modeTag;
    bool fullRes = false;
    if (mode == "colorfull" || mode == "colourfull" || mode == "rgbfull") { sel = {1, 2, 3}; modeTag = "color_full"; fullRes = true; }
    else if (mode == "color" || mode == "colour" || mode == "rgb") { sel = {1, 2, 3}; modeTag = "color"; }
    else if (mode == "r" || mode == "red")                    { sel = {1};       modeTag = "R"; }
    else if (mode == "g" || mode == "green")                  { sel = {2};       modeTag = "G"; }
    else if (mode == "b" || mode == "blue")                   { sel = {3};       modeTag = "B"; }
    else                                                      { sel = {0};       modeTag = "mono"; }
    const bool wantColor = (modeTag != "mono");
    const bool balance = autoBalance && (sel.size() == 3);

    const QStringList darkPaths = calibration.value("darks").toStringList();
    const QStringList flatPaths = calibration.value("flats").toStringList();
    const QStringList biasPaths = calibration.value("bias").toStringList();

    m_cancel.storeRelease(0);
    m_stacking = true;
    m_resultPath.clear();
    m_lastError.clear();
    m_lastWarning.clear();
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
        [this, frames, reference, object, align, sigmaClip, wantColor, fullRes, balance, sel, modeTag,
         darkPaths, flatPaths, biasPaths, panels, mosaicRun, refPanel]() -> StackResult
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

        FitsColorData refData = FitsPixelReader::readColor(reference, wantColor, fullRes);
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

        // Calibration masters by per-pixel 3-sigma-clipped mean (robust to hot
        // pixels and cosmic rays), built with the same geometry as the lights.
        // Each set is optional and independent. Plane 0 = luma, 1/2/3 = R/G/B.
        const int masterPlanes = (refChannels == 3) ? 4 : 1;
        auto srcPlane = [](const FitsColorData &d, int k) -> const std::vector<float> & {
            switch (k) { case 1: return d.r; case 2: return d.g; case 3: return d.b; default: return d.luma; }
        };
        auto buildMaster = [&](const QStringList &paths, const char *phaseName, int &matched) -> FitsColorData {
            matched = 0;
            FitsColorData m;
            if (paths.isEmpty()) return m;

            std::vector<std::vector<double>> mn(masterPlanes), m2(masterPlanes);
            for (int k = 0; k < masterPlanes; ++k) { mn[k].assign((size_t)N, 0.0); m2[k].assign((size_t)N, 0.0); }

            int seen = 0;
            for (int i = 0; i < paths.size(); ++i) {
                if (canceled()) return m;
                progress(i, paths.size(), phaseName);
                const FitsColorData d = FitsPixelReader::readColor(paths[i], wantColor, fullRes);
                if (!d.valid || d.width != W || d.height != H || d.channels != refChannels)
                    continue;
                ++seen;
                for (int k = 0; k < masterPlanes; ++k) {
                    const std::vector<float> &pl = srcPlane(d, k);
                    std::vector<double> &mk = mn[k];
                    std::vector<double> &vk = m2[k];
                    for (qint64 p = 0; p < N; ++p) {
                        const double v = pl[(size_t)p];
                        const double delta = v - mk[(size_t)p];
                        mk[(size_t)p] += delta / seen;
                        vk[(size_t)p] += delta * (v - mk[(size_t)p]);
                    }
                }
            }
            if (seen == 0) return m;
            matched = seen;

            std::vector<std::vector<double>> csum(masterPlanes);
            std::vector<std::vector<int>>    ccnt(masterPlanes);
            for (int k = 0; k < masterPlanes; ++k) { csum[k].assign((size_t)N, 0.0); ccnt[k].assign((size_t)N, 0); }

            const double kappa = 3.0;
            for (int i = 0; i < paths.size(); ++i) {
                if (canceled()) return m;
                const FitsColorData d = FitsPixelReader::readColor(paths[i], wantColor, fullRes);
                if (!d.valid || d.width != W || d.height != H || d.channels != refChannels)
                    continue;
                for (int k = 0; k < masterPlanes; ++k) {
                    const std::vector<float> &pl = srcPlane(d, k);
                    for (qint64 p = 0; p < N; ++p) {
                        const double sigma = std::sqrt(std::max(0.0, m2[k][(size_t)p] / seen));
                        const double v = pl[(size_t)p];
                        if (sigma <= 0.0 || std::abs(v - mn[k][(size_t)p]) <= kappa * sigma) {
                            csum[k][(size_t)p] += v;
                            ccnt[k][(size_t)p] += 1;
                        }
                    }
                }
            }

            auto finishPlane = [&](std::vector<float> &out, int k) {
                out.resize((size_t)N);
                for (qint64 p = 0; p < N; ++p)
                    out[(size_t)p] = ccnt[k][(size_t)p] > 0
                        ? (float)(csum[k][(size_t)p] / ccnt[k][(size_t)p])
                        : (float)mn[k][(size_t)p];
            };

            m.valid = true; m.width = W; m.height = H; m.channels = refChannels;
            finishPlane(m.luma, 0);
            if (refChannels == 3) { finishPlane(m.r, 1); finishPlane(m.g, 2); finishPlane(m.b, 3); }
            else                  { m.r = m.luma; }
            return m;
        };

        int darkMatched = 0, biasMatched = 0, flatMatched = 0;
        FitsColorData mDark = buildMaster(darkPaths, "Master dark", darkMatched);
        if (canceled()) { res.error = "Canceled."; return res; }
        FitsColorData mBias = buildMaster(biasPaths, "Master bias", biasMatched);
        if (canceled()) { res.error = "Canceled."; return res; }
        FitsColorData mFlat = buildMaster(flatPaths, "Master flat", flatMatched);
        if (canceled()) { res.error = "Canceled."; return res; }

        // Warn when supplied calibration frames didn't match the lights' geometry.
        {
            QStringList notes;
            auto note = [&](const char *name, const QStringList &paths, int matched) {
                if (!paths.isEmpty() && matched < paths.size())
                    notes << QString("%1 %2/%3").arg(name).arg(matched).arg(paths.size());
            };
            note("darks", darkPaths, darkMatched);
            note("flats", flatPaths, flatMatched);
            note("bias", biasPaths, biasMatched);
            if (!notes.isEmpty())
                res.warning = "Some calibration frames didn't match the lights' size and were skipped ("
                            + notes.join(", ") + " used).";
        }

        // Correct the flat (subtract bias) and normalise each plane to mean 1,
        // clamped away from zero so vignetted corners can't blow up on division.
        if (mFlat.valid) {
            auto normalizePlane = [&](std::vector<float> &fl, const std::vector<float> *bias) {
                double sum = 0.0;
                for (qint64 p = 0; p < N; ++p) {
                    if (bias) fl[(size_t)p] -= (*bias)[(size_t)p];
                    sum += fl[(size_t)p];
                }
                const double mean = sum / (double)N;
                if (mean <= 1e-6) { std::fill(fl.begin(), fl.end(), 1.0f); return; }
                for (qint64 p = 0; p < N; ++p)
                    fl[(size_t)p] = (float)std::max(0.1, fl[(size_t)p] / mean);
            };
            const bool hb = mBias.valid;
            normalizePlane(mFlat.luma, hb ? &mBias.luma : nullptr);
            if (refChannels == 3) {
                normalizePlane(mFlat.r, hb ? &mBias.r : nullptr);
                normalizePlane(mFlat.g, hb ? &mBias.g : nullptr);
                normalizePlane(mFlat.b, hb ? &mBias.b : nullptr);
            }
        }

        const bool calibrating = mDark.valid || mBias.valid || mFlat.valid;

        // (light - dark[or bias]) / normalised-flat, applied per plane in place.
        auto applyCalibration = [&](FitsColorData &L) {
            if (!calibrating) return;
            auto doPlane = [&](std::vector<float> &lp, const std::vector<float> *dk,
                               const std::vector<float> *bs, const std::vector<float> *fl) {
                for (qint64 p = 0; p < N; ++p) {
                    double v = lp[(size_t)p];
                    if (dk)      v -= (*dk)[(size_t)p];
                    else if (bs) v -= (*bs)[(size_t)p];
                    if (fl)      v /= (*fl)[(size_t)p];
                    lp[(size_t)p] = (float)v;
                }
            };
            doPlane(L.luma, mDark.valid ? &mDark.luma : nullptr,
                    mBias.valid ? &mBias.luma : nullptr, mFlat.valid ? &mFlat.luma : nullptr);
            if (refChannels == 3) {
                doPlane(L.r, mDark.valid ? &mDark.r : nullptr, mBias.valid ? &mBias.r : nullptr, mFlat.valid ? &mFlat.r : nullptr);
                doPlane(L.g, mDark.valid ? &mDark.g : nullptr, mBias.valid ? &mBias.g : nullptr, mFlat.valid ? &mFlat.g : nullptr);
                doPlane(L.b, mDark.valid ? &mDark.b : nullptr, mBias.valid ? &mBias.b : nullptr, mFlat.valid ? &mFlat.b : nullptr);
            }
        };

        applyCalibration(refData);

        std::vector<StarPoint> refStars;
        if (align) {
            refStars = StarFinder::detectStars(lumaOf(refData), 60);
            if (refStars.size() < 4) {
                res.error = "The reference frame has too few stars to align to.";
                return res;
            }
        }
        const int refIndex = frames.indexOf(reference);

        // Output canvas and the per-frame output->source map. For a single field
        // the canvas is the reference frame's own grid and F[i] registers frame i
        // onto it. For a mosaic the canvas is enlarged to hold every placed panel
        // and F[i] folds the panel's position into that same output->frame map.
        int    Wc = W, Hc = H;
        double padX = 0.0, padY = 0.0;
        std::vector<Transform> F(frames.size());

        // Per-frame, per-output-channel additive background offset. Zero for a
        // single field; for a mosaic it lifts each panel to a common background
        // level so the panel-to-panel steps disappear where they overlap.
        std::vector<std::vector<double>> frameOffset(frames.size(), std::vector<double>(C, 0.0));

        if (!mosaicRun) {
            // Phase 1: per-frame registration (reference maps to identity). Prefer a
            // rotation-aware affine fit; fall back to a translation-only match.
            for (int i = 0; i < frames.size(); ++i) {
                if (canceled()) { res.error = "Canceled."; return res; }
                progress(i, frames.size(), "Aligning");

                if (frames[i] == reference) { F[i].ok = true; continue; }
                if (!align)                 { F[i].ok = true; continue; }

                FitsColorData d = FitsPixelReader::readColor(frames[i], wantColor, fullRes);
                if (!d.valid || d.width != W || d.height != H || d.channels != refChannels)
                    continue;
                applyCalibration(d);
                const std::vector<StarPoint> stars = StarFinder::detectStars(lumaOf(d), 60);
                Transform t = estimateTransform(refStars, stars);
                if (!t.ok) {
                    const Offset o = matchOffset(refStars, stars);
                    if (o.ok) { t.ok = true; t.a = 1; t.b = 0; t.c = 0; t.d = 1; t.tx = o.dx; t.ty = o.dy; }
                }
                F[i] = t;
            }
        } else {
            // Mosaic placement. Each panel is tied, through the stars it shares
            // with an already-placed panel, into the reference panel's coordinate
            // frame (a star-based spanning tree rooted at the open image's panel).
            // Panels that share no stars with any placed panel are left out and
            // reported. Pure pixel geometry — no WCS, no pointing-to-pixel guess.
            QList<int> panelList;
            for (int pid : panels) if (!panelList.contains(pid)) panelList << pid;

            QHash<int, int> panelAnchor;            // panel id -> an anchor frame index
            for (int i = 0; i < frames.size(); ++i)
                if (!panelAnchor.contains(panels[i])) panelAnchor.insert(panels[i], i);

            auto starsOfFrame = [&](int fi) -> std::vector<StarPoint> {
                if (fi == refIndex) return refStars;
                FitsColorData d = FitsPixelReader::readColor(frames[fi], wantColor, fullRes);
                if (!d.valid || d.width != W || d.height != H || d.channels != refChannels)
                    return {};
                applyCalibration(d);
                return StarFinder::detectStars(lumaOf(d), 60);
            };

            QHash<int, std::vector<StarPoint>> anchorStars;
            for (int pid : panelList) anchorStars.insert(pid, starsOfFrame(panelAnchor.value(pid)));

            // G[pid] maps the reference panel's anchor coords -> panel pid's anchor.
            QHash<int, Transform> G;
            Transform ident; ident.ok = true;
            G.insert(refPanel, ident);

            bool progressMade = true;
            while (progressMade) {
                progressMade = false;
                for (int pid : panelList) {
                    if (G.contains(pid)) continue;
                    if (canceled()) { res.error = "Canceled."; return res; }
                    progress(G.size(), panelList.size(), "Placing panels");
                    for (int qid : panelList) {
                        if (!G.contains(qid)) continue;
                        const Transform Hqp = estimateTransform(anchorStars.value(qid), anchorStars.value(pid));
                        if (!Hqp.ok) continue;
                        G.insert(pid, composeT(Hqp, G.value(qid)));   // ref-anchor -> p-anchor
                        progressMade = true;
                        break;
                    }
                }
            }

            // Canvas bounds: map each placed panel's native corners back into the
            // reference-panel coordinate system (which the canvas mirrors, offset).
            double minX = 0.0, minY = 0.0, maxX = W, maxY = H;
            QHash<int, Transform> Ginv;
            for (int pid : panelList) {
                if (!G.contains(pid)) continue;
                Transform gi;
                if (!invertT(G.value(pid), gi)) continue;
                Ginv.insert(pid, gi);
                const double cx[4] = { 0.0, (double)W, 0.0, (double)W };
                const double cy[4] = { 0.0, 0.0, (double)H, (double)H };
                for (int k = 0; k < 4; ++k) {
                    const double rx = gi.a * cx[k] + gi.b * cy[k] + gi.tx;
                    const double ry = gi.c * cx[k] + gi.d * cy[k] + gi.ty;
                    minX = std::min(minX, rx); maxX = std::max(maxX, rx);
                    minY = std::min(minY, ry); maxY = std::max(maxY, ry);
                }
            }
            padX = -minX; padY = -minY;
            Wc = (int)std::ceil(maxX - minX);
            Hc = (int)std::ceil(maxY - minY);
            if ((qint64)Wc * Hc > 120000000LL) {
                res.error = "The mosaic canvas is too large to stack in memory.";
                return res;
            }

            // transPad maps output (canvas) coords -> reference-panel coords.
            Transform transPad; transPad.ok = true;
            transPad.tx = -padX; transPad.ty = -padY;

            int droppedPanels = 0;
            for (int pid : panelList) if (!G.contains(pid)) ++droppedPanels;

            for (int i = 0; i < frames.size(); ++i) {
                if (canceled()) { res.error = "Canceled."; return res; }
                progress(i, frames.size(), "Aligning");
                const int pid = panels[i];
                if (!G.contains(pid)) continue;             // unplaced panel: dropped

                Transform within;                           // panel anchor -> this frame
                if (i == panelAnchor.value(pid)) {
                    within.ok = true;                       // the anchor maps to itself
                } else {
                    const std::vector<StarPoint> stars = starsOfFrame(i);
                    within = estimateTransform(anchorStars.value(pid), stars);
                    if (!within.ok) {
                        const Offset o = matchOffset(anchorStars.value(pid), stars);
                        if (o.ok) { within.ok = true; within.tx = o.dx; within.ty = o.dy; }
                    }
                    if (!within.ok) continue;
                }
                // output -> frame = within . G[pid] . transPad
                F[i] = composeT(within, composeT(G.value(pid), transPad));
            }

            if (droppedPanels > 0)
                res.warning = QString("%1 of %2 mosaic panels shared no stars with the others and were left out.")
                                  .arg(droppedPanels).arg(panelList.size());

            // Background matching: estimate each placed panel's per-channel sky
            // background (the median of its anchor frame), match them all to the
            // common median level, and carry that offset to every frame in the
            // panel — so panels sitting at different sky levels blend seamlessly.
            auto anchorBackground = [&](int fi) -> std::vector<double> {
                std::vector<double> bg(C, 0.0);
                FitsColorData d = FitsPixelReader::readColor(frames[fi], wantColor, fullRes);
                if (!d.valid || d.width != W || d.height != H || d.channels != refChannels)
                    return bg;
                applyCalibration(d);
                for (int ci = 0; ci < C; ++ci) {
                    const std::vector<float> &pl = planeOf(d, sel[ci]);
                    const size_t stride = std::max<size_t>(1, pl.size() / 50000);
                    std::vector<float> s;
                    s.reserve(pl.size() / stride + 1);
                    for (size_t p = 0; p < pl.size(); p += stride) s.push_back(pl[p]);
                    if (!s.empty()) {
                        std::nth_element(s.begin(), s.begin() + s.size() / 2, s.end());
                        bg[ci] = s[s.size() / 2];
                    }
                }
                return bg;
            };
            QHash<int, std::vector<double>> panelBg;
            for (int pid : panelList)
                if (G.contains(pid)) panelBg.insert(pid, anchorBackground(panelAnchor.value(pid)));
            if (panelBg.size() >= 2) {
                std::vector<double> target(C, 0.0);
                for (int ci = 0; ci < C; ++ci) {
                    std::vector<double> levels;
                    for (auto it = panelBg.constBegin(); it != panelBg.constEnd(); ++it)
                        levels.push_back(it.value()[ci]);
                    std::nth_element(levels.begin(), levels.begin() + levels.size() / 2, levels.end());
                    target[ci] = levels[levels.size() / 2];
                }
                for (int i = 0; i < frames.size(); ++i) {
                    const int pid = panels[i];
                    if (!panelBg.contains(pid)) continue;
                    const std::vector<double> &bg = panelBg[pid];
                    for (int ci = 0; ci < C; ++ci)
                        frameOffset[i][ci] = target[ci] - bg[ci];
                }
            }
        }

        // Phase 2: accumulate per-channel mean (and variance, for sigma clipping)
        // over the output canvas, sampling each frame through its F[i] map.
        const qint64 Nc = (qint64)Wc * Hc;
        std::vector<double> mean((size_t)C * Nc, 0.0);
        std::vector<double> m2((size_t)C * Nc, 0.0);
        std::vector<int>    cnt((size_t)Nc, 0);
        int used = 0;

        for (int i = 0; i < frames.size(); ++i) {
            if (canceled()) { res.error = "Canceled."; return res; }
            if (!F[i].ok) continue;
            progress(i, frames.size(), sigmaClip ? "Measuring" : "Combining");

            FitsColorData d = FitsPixelReader::readColor(frames[i], wantColor, fullRes);
            if (!d.valid || d.width != W || d.height != H || d.channels != refChannels)
                continue;
            applyCalibration(d);

            std::vector<const std::vector<float> *> src(C);
            for (int ci = 0; ci < C; ++ci) src[ci] = &planeOf(d, sel[ci]);

            const Transform &t = F[i];
            const std::vector<double> &off = frameOffset[i];
            ++used;

            for (int oy = 0; oy < Hc; ++oy) {
                for (int ox = 0; ox < Wc; ++ox) {
                    const double sx = t.a * ox + t.b * oy + t.tx;
                    const double sy = t.c * ox + t.d * oy + t.ty;
                    const int x0 = (int)std::floor(sx), y0 = (int)std::floor(sy);
                    if (x0 < 0 || y0 < 0 || x0 >= W || y0 >= H) continue;
                    const int x1 = std::min(x0 + 1, W - 1), y1 = std::min(y0 + 1, H - 1);
                    const double fx = sx - x0, fy = sy - y0;
                    const size_t b00 = (size_t)y0 * W + x0, b10 = (size_t)y0 * W + x1;
                    const size_t b01 = (size_t)y1 * W + x0, b11 = (size_t)y1 * W + x1;
                    const qint64 p = (qint64)oy * Wc + ox;
                    const int n = ++cnt[(size_t)p];
                    for (int ci = 0; ci < C; ++ci) {
                        const std::vector<float> &pl = *src[ci];
                        const double top = pl[b00] + (pl[b10] - pl[b00]) * fx;
                        const double bot = pl[b01] + (pl[b11] - pl[b01]) * fx;
                        const double v = top + (bot - top) * fy + off[ci];
                        double &mn = mean[(size_t)ci * Nc + p];
                        const double delta = v - mn;
                        mn += delta / n;
                        m2[(size_t)ci * Nc + p] += delta * (v - mn);
                    }
                }
            }
        }

        if (used < 2) {
            res.error = align
                ? (mosaicRun ? "Fewer than two frames could be placed into the mosaic."
                             : "Fewer than two frames could be aligned to the reference.")
                : "Fewer than two frames could be read.";
            return res;
        }

        std::vector<float> out((size_t)C * Nc, 0.0f);

        if (!sigmaClip) {
            for (size_t k = 0; k < (size_t)C * Nc; ++k)
                out[k] = (float)mean[k];
        } else {
            // Phase 3: clipped mean, re-reading frames with their stored offsets.
            const double kappa = 3.0;
            std::vector<double> clipSum((size_t)C * Nc, 0.0);
            std::vector<int>    clipCnt((size_t)C * Nc, 0);

            for (int i = 0; i < frames.size(); ++i) {
                if (canceled()) { res.error = "Canceled."; return res; }
                if (!F[i].ok) continue;
                progress(i, frames.size(), "Combining");

                FitsColorData d = FitsPixelReader::readColor(frames[i], wantColor, fullRes);
                if (!d.valid || d.width != W || d.height != H || d.channels != refChannels)
                    continue;
                applyCalibration(d);

                std::vector<const std::vector<float> *> src(C);
                for (int ci = 0; ci < C; ++ci) src[ci] = &planeOf(d, sel[ci]);

                const Transform &t = F[i];
                const std::vector<double> &off = frameOffset[i];

                for (int oy = 0; oy < Hc; ++oy) {
                    for (int ox = 0; ox < Wc; ++ox) {
                        const qint64 p = (qint64)oy * Wc + ox;
                        if (cnt[(size_t)p] < 2) continue;
                        const double sx = t.a * ox + t.b * oy + t.tx;
                        const double sy = t.c * ox + t.d * oy + t.ty;
                        const int x0 = (int)std::floor(sx), y0 = (int)std::floor(sy);
                        if (x0 < 0 || y0 < 0 || x0 >= W || y0 >= H) continue;
                        const int x1 = std::min(x0 + 1, W - 1), y1 = std::min(y0 + 1, H - 1);
                        const double fx = sx - x0, fy = sy - y0;
                        const size_t b00 = (size_t)y0 * W + x0, b10 = (size_t)y0 * W + x1;
                        const size_t b01 = (size_t)y1 * W + x0, b11 = (size_t)y1 * W + x1;
                        for (int ci = 0; ci < C; ++ci) {
                            const std::vector<float> &pl = *src[ci];
                            const double top = pl[b00] + (pl[b10] - pl[b00]) * fx;
                            const double bot = pl[b01] + (pl[b11] - pl[b01]) * fx;
                            const double v = top + (bot - top) * fy + off[ci];
                            const size_t cp = (size_t)ci * Nc + p;
                            const double sigma = std::sqrt(std::max(0.0, m2[cp] / cnt[(size_t)p]));
                            if (sigma <= 0.0 || std::abs(v - mean[cp]) <= kappa * sigma) {
                                clipSum[cp] += v;
                                clipCnt[cp] += 1;
                            }
                        }
                    }
                }
            }

            for (size_t k = 0; k < (size_t)C * Nc; ++k)
                out[k] = clipCnt[k] > 0 ? (float)(clipSum[k] / clipCnt[k]) : (float)mean[k];
        }

        if (balance && C == 3) {
            // Grey-world white balance: equalise the per-channel medians (which
            // are dominated by sky background), neutralising the OSC green cast.
            auto channelMedian = [&](int ci) -> double {
                const size_t base = (size_t)ci * Nc;
                const size_t sampleN = std::min<size_t>((size_t)Nc, 100000);
                const double step = (double)Nc / (double)sampleN;
                std::vector<float> s;
                s.reserve(sampleN);
                for (size_t i = 0; i < sampleN; ++i) {
                    const float v = out[base + (size_t)(i * step)];
                    if (v != 0.0f) s.push_back(v);      // skip canvas no-data padding
                }
                if (s.empty()) return 0.0;
                std::nth_element(s.begin(), s.begin() + s.size() / 2, s.end());
                return s[s.size() / 2];
            };
            const double m0 = channelMedian(0), m1 = channelMedian(1), m2med = channelMedian(2);
            if (m0 > 1e-6 && m1 > 1e-6 && m2med > 1e-6) {
                const double target = (m0 + m1 + m2med) / 3.0;
                const double sc[3] = {
                    std::clamp(target / m0, 0.2, 5.0),
                    std::clamp(target / m1, 0.2, 5.0),
                    std::clamp(target / m2med, 0.2, 5.0)
                };
                for (int ci = 0; ci < 3; ++ci) {
                    const size_t base = (size_t)ci * Nc;
                    const float f = (float)sc[ci];
                    for (qint64 p = 0; p < Nc; ++p)
                        out[base + (size_t)p] *= f;
                }
            }
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
        const QString calTag = calibrating ? "_cal" : "";
        const QString mosaicTag = mosaicRun ? "_mosaic" : "";
        const QString outPath = outDir.absoluteFilePath(
            QString("Stacked_%1_%2f_%3_%4%5%6.fit").arg(baseName).arg(used).arg(method).arg(modeTag).arg(calTag).arg(mosaicTag));

        if (!writeFloatFits(outPath, Wc, Hc, C, out, object, used)) {
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

    m_lastWarning = res.warning;
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
