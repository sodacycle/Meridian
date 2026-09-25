#ifndef STARFINDER_H
#define STARFINDER_H

#include "fitspixelreader.h"

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

class StarFinder
{
public:
    static FrameQuality analyze(const FitsPixelData &data);
};

#endif
