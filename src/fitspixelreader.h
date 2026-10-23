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

struct FitsColorData {
    bool   valid = false;
    int    width  = 0;
    int    height = 0;
    int    channels = 1;            // 1 = mono, 3 = RGB
    std::vector<float> luma;        // width*height, used for alignment
    std::vector<float> r, g, b;     // width*height each; r holds the plane when channels == 1
};

class FitsPixelReader
{
public:
    static FitsPixelData read(const QString &filePath);
    static FitsColorData readColor(const QString &filePath, bool wantColor);
};

#endif
