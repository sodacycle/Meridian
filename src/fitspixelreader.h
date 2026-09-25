#ifndef FITSPIXELREADER_H
#define FITSPIXELREADER_H

#include <QString>
#include <vector>

struct FitsPixelData {
    bool   valid = false;
    int    width  = 0;
    int    height = 0;
    std::vector<float> pixels;
    QString bayerPattern;
};

class FitsPixelReader
{
public:
    static FitsPixelData read(const QString &filePath);
};

#endif
