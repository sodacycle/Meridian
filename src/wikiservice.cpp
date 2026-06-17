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

    // Single request: thumbnail + intro extract, with redirect following.
    // action=query handles redirects natively (e.g. "M 31" → Andromeda Galaxy).
    QUrl url(QStringLiteral("https://en.wikipedia.org/w/api.php"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("action"),      QStringLiteral("query"));
    q.addQueryItem(QStringLiteral("titles"),      title);
    q.addQueryItem(QStringLiteral("prop"),        QStringLiteral("pageimages|extracts"));
    q.addQueryItem(QStringLiteral("pithumbsize"), QStringLiteral("300"));
    q.addQueryItem(QStringLiteral("exintro"),     QStringLiteral("1"));
    q.addQueryItem(QStringLiteral("explaintext"), QStringLiteral("1"));
    q.addQueryItem(QStringLiteral("redirects"),   QStringLiteral("1"));
    q.addQueryItem(QStringLiteral("format"),      QStringLiteral("json"));
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  QStringLiteral("Meridian/1.0 (https://github.com/sodacycle/Meridian)"));
    QNetworkReply *reply = m_network->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply, objectName]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit lookupFailed(objectName, reply->errorString());
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isObject()) {
            emit lookupFailed(objectName, QStringLiteral("Invalid JSON"));
            return;
        }

        const QJsonObject pages = doc.object()
                                      .value(QStringLiteral("query")).toObject()
                                      .value(QStringLiteral("pages")).toObject();
        if (pages.isEmpty()) {
            emit lookupFailed(objectName, QStringLiteral("No results"));
            return;
        }

        const QJsonObject page = pages.begin().value().toObject();
        if (page.contains(QStringLiteral("missing"))) {
            emit lookupFailed(objectName, QStringLiteral("No Wikipedia article found"));
            return;
        }

        QVariantMap data;
        data[QStringLiteral("wikiTitle")] = page.value(QStringLiteral("title")).toString();

        const QString thumbUrl = page.value(QStringLiteral("thumbnail")).toObject()
                                     .value(QStringLiteral("source")).toString();
        if (!thumbUrl.isEmpty())
            data[QStringLiteral("thumbnailUrl")] = thumbUrl;

        const QString extract = page.value(QStringLiteral("extract")).toString().trimmed();
        if (!extract.isEmpty())
            data[QStringLiteral("extract")] = extract.left(600);

        emit infoboxReady(data, objectName);
    });
}


