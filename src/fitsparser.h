#ifndef FITSPARSER_H
#define FITSPARSER_H

#include <QString>
#include <QHash>
#include <QVariant>

struct FitsCard {
    QString key;
    QVariant value;
};

class FitsParser
{
public:
    static QHash<QString, QVariant> parseHeader(const QString &filePath);
};

#endif
