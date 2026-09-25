#include "starfinder.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

namespace {

struct BackgroundStats {
    double median = 0.0;
    double sigma  = 0.0;
};

// Sigma-clipped median/MAD over a sample of the frame. Iterative clipping
// pushes bright star pixels out of the statistic, approximating "mask
// detected stars and measure background noise" without a separate masking
// pass.
BackgroundStats estimateBackground(const std::vector<float> &pixels)
{
    BackgroundStats stats;
    const size_t n = pixels.size();
    if (n == 0) return stats;

    const size_t sampleN = std::min<size_t>(n, 200000);
    const double step = (double)n / (double)sampleN;
    std::vector<float> sample(sampleN);
    for (size_t i = 0; i < sampleN; ++i)
        sample[i] = pixels[(size_t)(i * step)];

    for (int pass = 0; pass < 3; ++pass) {
        std::vector<float> work = sample;
        std::sort(work.begin(), work.end());
        const double median = work[work.size() / 2];

        std::vector<float> absDev(work.size());
        for (size_t i = 0; i < work.size(); ++i)
            absDev[i] = std::abs(work[i] - median);
        std::sort(absDev.begin(), absDev.end());
        const double mad = absDev[absDev.size() / 2];
        const double sigma = std::max(mad * 1.4826, 1e-6);

        stats.median = median;
        stats.sigma  = sigma;

        const double lo = median - 3.0 * sigma;
        const double hi = median + 3.0 * sigma;
        std::vector<float> clipped;
        clipped.reserve(sample.size());
        for (float v : sample)
            if (v >= lo && v <= hi) clipped.push_back(v);

        if (clipped.size() < 20) break;
        sample.swap(clipped);
    }
    return stats;
}

struct StarCandidate {
    double flux = 0.0;
    double cx = 0.0, cy = 0.0;
    double fwhm = 0.0;
    double eccentricity = 0.0;
};

double medianOf(std::vector<double> values)
{
    if (values.empty()) return 0.0;
    std::sort(values.begin(), values.end());
    const size_t mid = values.size() / 2;
    if (values.size() % 2 == 0)
        return (values[mid - 1] + values[mid]) * 0.5;
    return values[mid];
}

} // namespace

FrameQuality StarFinder::analyze(const FitsPixelData &data)
{
    FrameQuality result;
    if (!data.valid || data.width < 8 || data.height < 8 || data.pixels.empty())
        return result;

    const int W = data.width, H = data.height;
    const std::vector<float> &px = data.pixels;

    const BackgroundStats bg = estimateBackground(px);
    const double threshold = bg.median + 5.0 * bg.sigma;

    constexpr int kMinBlobPixels = 3;
    constexpr int kMaxBlobPixels = 2000;
    constexpr int kMaxStars      = 4000;

    std::vector<uint8_t> visited(px.size(), 0);
    std::vector<StarCandidate> stars;
    stars.reserve(256);

    std::vector<int> stack;
    stack.reserve(256);
    std::vector<int> blobPixels;
    blobPixels.reserve(64);

    for (int y = 0; y < H && (int)stars.size() < kMaxStars; ++y) {
        for (int x = 0; x < W && (int)stars.size() < kMaxStars; ++x) {
            const int idx0 = y * W + x;
            if (visited[idx0] || px[idx0] < threshold) continue;

            stack.clear();
            blobPixels.clear();
            stack.push_back(idx0);
            visited[idx0] = 1;

            bool touchesBorder = false;
            bool overflowed = false;

            while (!stack.empty()) {
                const int idx = stack.back();
                stack.pop_back();
                blobPixels.push_back(idx);

                const int bx = idx % W, by = idx / W;
                if (bx == 0 || by == 0 || bx == W - 1 || by == H - 1)
                    touchesBorder = true;

                if ((int)blobPixels.size() > kMaxBlobPixels) { overflowed = true; continue; }

                static const int ddx[4] = {-1, 1, 0, 0};
                static const int ddy[4] = {0, 0, -1, 1};
                for (int k = 0; k < 4; ++k) {
                    const int nx = bx + ddx[k], ny = by + ddy[k];
                    if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                    const int nIdx = ny * W + nx;
                    if (visited[nIdx] || px[nIdx] < threshold) continue;
                    visited[nIdx] = 1;
                    stack.push_back(nIdx);
                }
            }

            if (overflowed || touchesBorder) continue;
            if ((int)blobPixels.size() < kMinBlobPixels) continue;

            double sumW = 0.0, sumWX = 0.0, sumWY = 0.0;
            for (int idx : blobPixels) {
                const double w = std::max(0.0, (double)px[idx] - bg.median);
                const int bx = idx % W, by = idx / W;
                sumW  += w;
                sumWX += w * bx;
                sumWY += w * by;
            }
            if (sumW <= 0.0) continue;

            const double cx = sumWX / sumW;
            const double cy = sumWY / sumW;

            double ixx = 0.0, iyy = 0.0, ixy = 0.0;
            for (int idx : blobPixels) {
                const double w  = std::max(0.0, (double)px[idx] - bg.median);
                const int bx = idx % W, by = idx / W;
                const double dx = bx - cx, dy = by - cy;
                ixx += w * dx * dx;
                iyy += w * dy * dy;
                ixy += w * dx * dy;
            }
            ixx /= sumW; iyy /= sumW; ixy /= sumW;

            const double trace = ixx + iyy;
            const double diff  = ixx - iyy;
            const double disc  = std::sqrt(std::max(0.0, diff * diff + 4.0 * ixy * ixy));
            const double lambda1 = 0.5 * (trace + disc);
            const double lambda2 = 0.5 * (trace - disc);
            if (lambda1 <= 0.0) continue;

            const double ecc = (lambda2 <= 0.0) ? 1.0
                              : std::sqrt(std::max(0.0, 1.0 - lambda2 / lambda1));
            const double fwhm = 2.3548 * std::sqrt(std::max(0.0, trace * 0.5));

            StarCandidate star;
            star.flux = sumW;
            star.cx = cx; star.cy = cy;
            star.fwhm = fwhm;
            star.eccentricity = ecc;
            stars.push_back(star);
        }
    }

    result.starCount = (int)stars.size();

    // "Reasonably bright, isolated" subset used for shape/flux statistics,
    // so a close double star or a noise-driven false split doesn't skew the
    // FWHM/eccentricity medians.
    constexpr double kIsolationRadius = 20.0;
    std::vector<double> fluxList, fwhmList, eccList;
    fluxList.reserve(stars.size());
    fwhmList.reserve(stars.size());
    eccList.reserve(stars.size());

    for (size_t i = 0; i < stars.size(); ++i) {
        bool isolated = true;
        for (size_t j = 0; j < stars.size() && isolated; ++j) {
            if (i == j) continue;
            const double dx = stars[i].cx - stars[j].cx;
            const double dy = stars[i].cy - stars[j].cy;
            if (dx * dx + dy * dy < kIsolationRadius * kIsolationRadius)
                isolated = false;
        }
        if (!isolated) continue;

        fluxList.push_back(stars[i].flux);
        fwhmList.push_back(stars[i].fwhm);
        eccList.push_back(stars[i].eccentricity);
    }

    result.usableStarCount    = (int)fluxList.size();
    result.medianStarFlux     = medianOf(fluxList);
    result.medianFwhm         = medianOf(fwhmList);
    result.medianEccentricity = medianOf(eccList);
    result.backgroundLevel    = bg.median;
    result.backgroundNoise    = bg.sigma;
    result.valid              = true;

    return result;
}
