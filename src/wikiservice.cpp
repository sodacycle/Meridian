#include "wikiservice.h"
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QUrl>
#include <QUrlQuery>

// ── Constellation abbreviation table (ported from wiki-parser.js) ─────────────

const QHash<QString, QString> &WikiService::constellationMap()
{
    static const QHash<QString, QString> map = {
        {"And", "Andromeda"},      {"Ant", "Antlia"},          {"Aps", "Apus"},
        {"Aqr", "Aquarius"},       {"Aql", "Aquila"},          {"Ara", "Ara"},
        {"Ari", "Aries"},          {"Aur", "Auriga"},          {"Boo", "Boötes"},
        {"Cae", "Caelum"},         {"Cam", "Camelopardalis"},  {"Cnc", "Cancer"},
        {"CVn", "Canes Venatici"}, {"CMa", "Canis Major"},     {"CMi", "Canis Minor"},
        {"Cap", "Capricornus"},    {"Car", "Carina"},          {"Cas", "Cassiopeia"},
        {"Cen", "Centaurus"},      {"Cep", "Cepheus"},         {"Cet", "Cetus"},
        {"Cha", "Chamaeleon"},     {"Cir", "Circinus"},        {"Col", "Columba"},
        {"Com", "Coma Berenices"}, {"CrA", "Corona Australis"},{"CrB", "Corona Borealis"},
        {"Crv", "Corvus"},         {"Crt", "Crater"},          {"Cru", "Crux"},
        {"Cyg", "Cygnus"},         {"Del", "Delphinus"},       {"Dor", "Dorado"},
        {"Dra", "Draco"},          {"Equ", "Equuleus"},        {"Eri", "Eridanus"},
        {"For", "Fornax"},         {"Gem", "Gemini"},          {"Gru", "Grus"},
        {"Her", "Hercules"},       {"Hor", "Horologium"},      {"Hya", "Hydra"},
        {"Hyi", "Hydrus"},         {"Ind", "Indus"},           {"Lac", "Lacerta"},
        {"Leo", "Leo"},            {"LMi", "Leo Minor"},       {"Lep", "Lepus"},
        {"Lib", "Libra"},          {"Lup", "Lupus"},           {"Lyn", "Lynx"},
        {"Lyr", "Lyra"},           {"Men", "Mensa"},           {"Mic", "Microscopium"},
        {"Mon", "Monoceros"},      {"Mus", "Musca"},           {"Nor", "Norma"},
        {"Oct", "Octans"},         {"Oph", "Ophiuchus"},       {"Ori", "Orion"},
        {"Pav", "Pavo"},           {"Peg", "Pegasus"},         {"Per", "Perseus"},
        {"Phe", "Phoenix"},        {"Pic", "Pictor"},          {"Psc", "Pisces"},
        {"PsA", "Piscis Austrinus"},{"Pup", "Puppis"},         {"Pyx", "Pyxis"},
        {"Ret", "Reticulum"},      {"Sge", "Sagitta"},         {"Sgr", "Sagittarius"},
        {"Sco", "Scorpius"},       {"Scl", "Sculptor"},        {"Sct", "Scutum"},
        {"Ser", "Serpens"},        {"Sex", "Sextans"},         {"Tau", "Taurus"},
        {"Tel", "Telescopium"},    {"Tri", "Triangulum"},      {"TrA", "Triangulum Australe"},
        {"Tuc", "Tucana"},         {"UMa", "Ursa Major"},      {"UMi", "Ursa Minor"},
        {"Vel", "Vela"},           {"Vir", "Virgo"},           {"Vol", "Volans"},
        {"Vul", "Vulpecula"},
    };
    return map;
}

WikiService::WikiService(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{}

QString WikiService::fullConstellation(const QString &abbr) const
{
    return constellationMap().value(abbr, abbr.isEmpty() ? QStringLiteral("N/A") : abbr);
}

// ── Article title derivation (matches wiki-parser.js extractTitleFromUrl) ─────

static QString articleTitle(const QString &objectName)
{
    // If the name contains a "/wiki/" path segment, extract the last part.
    if (objectName.contains(QStringLiteral("/wiki/"))) {
        QString slug = objectName.section('/', -1);
        return QString(slug).replace('_', ' ');
    }
    // For catalogue names like "NGC224", "M31", "IC 434" normalise to "NGC 224" etc.
    static const QRegularExpression catRx(
        QStringLiteral("^(NGC|IC|M)\\s*(\\d+)$"),
        QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch m = catRx.match(objectName.trimmed());
    if (m.hasMatch())
        return m.captured(1).toUpper() + QLatin1Char(' ') + m.captured(2);
    return objectName;
}

// ── Network fetch ─────────────────────────────────────────────────────────────

void WikiService::lookup(const QString &objectName)
{
    const QString title = articleTitle(objectName);

    QUrl url(QStringLiteral("https://en.wikipedia.org/w/api.php"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("action"), QStringLiteral("parse"));
    query.addQueryItem(QStringLiteral("page"),   title);
    query.addQueryItem(QStringLiteral("prop"),   QStringLiteral("text"));
    query.addQueryItem(QStringLiteral("format"), QStringLiteral("json"));
    url.setQuery(query);

    QNetworkReply *reply = m_network->get(QNetworkRequest(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply, objectName]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit lookupFailed(objectName, reply->errorString());
            reply->deleteLater();
            return;
        }

        const QByteArray raw = reply->readAll();
        reply->deleteLater();

        const QJsonDocument doc = QJsonDocument::fromJson(raw);
        if (!doc.isObject()) {
            emit lookupFailed(objectName, QStringLiteral("Invalid JSON response"));
            return;
        }
        const QJsonObject root = doc.object();
        if (root.contains(QStringLiteral("error"))) {
            const QString info = root[QStringLiteral("error")]
                                     .toObject()[QStringLiteral("info")].toString();
            emit lookupFailed(objectName, info.isEmpty()
                              ? QStringLiteral("Wikipedia page not found") : info);
            return;
        }

        const QString html = root[QStringLiteral("parse")]
                                 .toObject()[QStringLiteral("text")]
                                 .toObject()[QStringLiteral("*")].toString();
        if (html.isEmpty()) {
            emit lookupFailed(objectName, QStringLiteral("No content found"));
            return;
        }

        parseResponse(html.toUtf8(), objectName);
    });
}

// ── HTML infobox parser ───────────────────────────────────────────────────────

static QString stripTags(const QString &html)
{
    QString s = html;
    s.remove(QRegularExpression(QStringLiteral("<[^>]*>")));
    // Collapse HTML entities most common in infoboxes
    s.replace(QStringLiteral("&amp;"),  QStringLiteral("&"));
    s.replace(QStringLiteral("&lt;"),   QStringLiteral("<"));
    s.replace(QStringLiteral("&gt;"),   QStringLiteral(">"));
    s.replace(QStringLiteral("&nbsp;"), QStringLiteral(" "));
    s.replace(QStringLiteral("&#160;"), QStringLiteral(" "));
    return s.simplified();
}

void WikiService::parseResponse(const QByteArray &rawHtml, const QString &objectName)
{
    const QString html = QString::fromUtf8(rawHtml);
    QVariantMap result;

    // Wikipedia infobox rows consistently use class="infobox-label" on <th>
    // and class="infobox-data" on <td>. Match each <tr> that has both.
    // DotMatchesEverythingOption lets .* span newlines within a row.
    static const QRegularExpression rowRx(
        QStringLiteral(
            "<tr[^>]*>"
            ".*?<th[^>]*>(.*?)</th>"
            ".*?<td[^>]*>(.*?)</td>"
            ".*?</tr>"),
        QRegularExpression::DotMatchesEverythingOption
        | QRegularExpression::CaseInsensitiveOption);

    auto it = rowRx.globalMatch(html);
    while (it.hasNext()) {
        const QRegularExpressionMatch m = it.next();
        const QString label = stripTags(m.captured(1)).toLower();
        const QString value = stripTags(m.captured(2));

        if (value.isEmpty()) continue;

        if (label.contains(QStringLiteral("constellation")))
            result[QStringLiteral("constellation")] = value;
        else if (label.contains(QStringLiteral("right ascension")))
            result[QStringLiteral("rightAscension")] = value;
        else if (label.contains(QStringLiteral("declination")))
            result[QStringLiteral("declination")] = value;
        else if (label.contains(QStringLiteral("distance")))
            result[QStringLiteral("distance")] = value;
        else if (label.contains(QStringLiteral("apparent visual magnitude"))
              || label.contains(QStringLiteral("apparent magnitude")))
            result[QStringLiteral("apparentMagnitude")] = value;
        else if (label.contains(QStringLiteral("type")))
            result[QStringLiteral("type")] = value;
        else if (label.contains(QStringLiteral("apparent size")))
            result[QStringLiteral("apparentSize")] = value;
        else if (label.contains(QStringLiteral("size"))
              && !label.contains(QStringLiteral("apparent")))
            result[QStringLiteral("size")] = value;
    }

    if (result.isEmpty()) {
        emit lookupFailed(objectName, QStringLiteral("No infobox found"));
        return;
    }

    emit infoboxReady(result, objectName);
}
