#ifndef STARFINDER_H
#define STARFINDER_H

#include "fitspixelreader.h"
#include <vector>

struct FrameQuality {
    bool   valid = false;
    int    starCount = 0;
    int    usableStarCount = 0;
    double medianFwhm = 0.0;
    double medianEccentricity = 0.0;
    double medianStarFlux = 0.0;
    double backgroundLevel = 0.0;
    double backgroundNoise = 0.0;
};

struct StarPoint {
    double x = 0.0;
    double y = 0.0;
    double flux = 0.0;
};

class StarFinder
{
public:
    static FrameQuality analyze(const FitsPixelData &data);
    static std::vector<StarPoint> detectStars(const FitsPixelData &data, int maxStars = 200);
};

#endif
