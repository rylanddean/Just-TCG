import Foundation

// Parses HTML from limitlesstcg.com pages.
// All data is stored in data-* attributes — no full HTML parser required.
enum LimitlessHTMLParser {

    // MARK: - Tournament list  (/tournaments)

    // Rows: <tr data-date="2026-05-30" data-name="Regional Indianapolis, IN"
    //            data-format="standard" data-players="1974" data-country="US">
    //         <td>...<a href="/tournaments/559">...</a>...
    static func parseTournaments(from html: String) -> [LimitlessTournament] {
        splitRows(html, anchorAttr: "data-date").compactMap { rowHTML in
            let attrs = dataAttributes(in: rowHTML)
            guard
                let dateStr  = attrs["date"],
                let name     = attrs["name"],
                let format   = attrs["format"],
                let playersStr = attrs["players"],
                let players  = Int(playersStr),
                let id       = firstCapture(#/href="\/tournaments\/(\d+)"/#, in: rowHTML)
            else { return nil }

            return LimitlessTournament(
                id: id,
                name: name.htmlDecoded,
                date: parseDate(dateStr) ?? Date.distantPast,
                country: attrs["country"] ?? "",
                format: format,
                playerCount: players
            )
        }
    }

    // MARK: - Tournament detail  (/tournaments/{id})

    // Rows: <tr data-rank="1" data-name="Cerys Jones"
    //            data-country="US" data-deck="Alakazam Dudunsparce">
    //         ...  <a href="/decks/list/27608"> ...
    static func parsePlacements(from html: String) -> [LimitlessPlacement] {
        splitRows(html, anchorAttr: "data-rank").compactMap { rowHTML in
            let attrs = dataAttributes(in: rowHTML)
            guard
                let rankStr = attrs["rank"],
                let rank    = Int(rankStr),
                let name    = attrs["name"],
                let deck    = attrs["deck"]
            else { return nil }

            // Try explicit data-wins/losses/ties; fall back to parsing data-record="W-L-T"
            let (wins, losses, ties) = parseRecord(attrs: attrs, rowHTML: rowHTML)

            return LimitlessPlacement(
                rank: rank,
                playerName: name.htmlDecoded,
                country: attrs["country"] ?? "",
                archetype: deck.htmlDecoded,
                wins: wins,
                losses: losses,
                ties: ties,
                deckListId: firstCapture(#/href="\/decks\/list\/(\d+)"/#, in: rowHTML),
                playerId: attrs["player"] ?? firstCapture(#/href="\/players\/(\d+)"/#, in: rowHTML)
            )
        }
    }

    private static func parseRecord(attrs: [String: String], rowHTML: String) -> (Int, Int, Int) {
        if let w = attrs["wins"].flatMap(Int.init),
           let l = attrs["losses"].flatMap(Int.init),
           let t = attrs["ties"].flatMap(Int.init) {
            return (w, l, t)
        }
        if let record = attrs["record"] {
            let parts = record.split(separator: "-").compactMap { Int($0) }
            if parts.count >= 3 { return (parts[0], parts[1], parts[2]) }
            if parts.count == 2 { return (parts[0], parts[1], 0) }
        }
        return (0, 0, 0)
    }

    // MARK: - Deck list  (/decks/list/{id})

    // Cards: <div class="decklist-card" data-set="MEG" data-number="54" ...>
    //          <a class="card-link" ...>
    //            <span class="card-count">4</span>
    //            <span class="card-name">Abra</span>
    //          </a>
    static func parseDeckList(listId: String, from html: String) -> LimitlessDeckList {
        // Split on the start of each decklist-card div
        let marker = #"class="decklist-card""#
        let chunks = html.components(separatedBy: marker).dropFirst()

        let entries: [LimitlessDeckEntry] = chunks.compactMap { chunk in
            // The opening tag attributes come before the first >
            guard let closeAngle = chunk.firstIndex(of: ">") else { return nil }
            let tagPart = String(chunk[chunk.startIndex..<closeAngle])
            let attrs   = dataAttributes(in: tagPart)

            guard
                let setCode  = attrs["set"],
                let number   = attrs["number"],
                let countStr = firstCapture(#/<span[^>]*class="[^"]*card-count[^"]*"[^>]*>(\d+)<\/span>/#, in: chunk),
                let quantity = Int(countStr),
                let name     = firstCapture(#/<span[^>]*class="[^"]*card-name[^"]*"[^>]*>([^<]+)<\/span>/#, in: chunk)
            else { return nil }

            return LimitlessDeckEntry(
                setCode: setCode,
                number: number,
                name: name.htmlDecoded,
                quantity: quantity
            )
        }

        return LimitlessDeckList(listId: listId, entries: entries)
    }

    // MARK: - Player profile  (/players/{id})

    // Profile header expected attributes:
    //   data-name, data-country, data-points, data-prize, data-travel on a profile div
    // Career top cuts in data-* attributes:
    //   data-ic1, data-ic2, data-ic4, data-ic8 (internationals)
    //   data-reg1, data-reg2, data-reg4, data-reg8 (regionals)
    // Tournament results rows anchored by data-placement:
    //   <tr data-placement="1" data-name="Regional Indianapolis, IN" data-date="2026-05-30"
    //       data-deck="Charizard ex" data-record="9-2-0" data-points="200"
    //       data-id="559" data-list="27608" data-prize="1000">
    static func parsePlayerProfile(id: String, from html: String) -> LimitlessPlayerProfile? {
        // Pull all data-* attributes from the full page (profile header values live here)
        let pageAttrs = dataAttributes(in: html)

        let name = pageAttrs["name"]?.htmlDecoded
            ?? firstCapture(#/<h1[^>]*>([^<]+)<\/h1>/#, in: html)?.htmlDecoded
            ?? ""
        let country      = pageAttrs["country"] ?? ""
        let totalPoints  = pageAttrs["points"].flatMap(Int.init) ?? 0
        let totalPrize   = pageAttrs["prize"].flatMap(Int.init) ?? 0
        let travelAwards = pageAttrs["travel"].flatMap(Int.init) ?? 0

        let topCuts = PlayerTopCuts(
            internationalWins: pageAttrs["ic1"].flatMap(Int.init) ?? 0,
            internationalTop2: pageAttrs["ic2"].flatMap(Int.init) ?? 0,
            internationalTop4: pageAttrs["ic4"].flatMap(Int.init) ?? 0,
            internationalTop8: pageAttrs["ic8"].flatMap(Int.init) ?? 0,
            regionalWins:      pageAttrs["reg1"].flatMap(Int.init) ?? 0,
            regionalTop2:      pageAttrs["reg2"].flatMap(Int.init) ?? 0,
            regionalTop4:      pageAttrs["reg4"].flatMap(Int.init) ?? 0,
            regionalTop8:      pageAttrs["reg8"].flatMap(Int.init) ?? 0
        )

        // Tournament results: rows anchored by data-placement
        let results: [PlayerTournamentResult] = splitRows(html, anchorAttr: "data-placement").compactMap { rowHTML in
            let attrs = dataAttributes(in: rowHTML)
            guard
                let placementStr = attrs["placement"],
                let placement    = Int(placementStr),
                let tName        = attrs["name"],
                let dateStr      = attrs["date"],
                let deck         = attrs["deck"],
                let tid          = attrs["id"]
            else { return nil }

            return PlayerTournamentResult(
                tournamentId:   tid,
                tournamentName: tName.htmlDecoded,
                date:           parseDate(dateStr) ?? Date.distantPast,
                placement:      placement,
                record:         attrs["record"] ?? "",
                archetype:      deck.htmlDecoded,
                points:         attrs["points"].flatMap(Int.init) ?? 0,
                prizeMoney:     attrs["prize"].flatMap(Int.init),
                deckListId:     attrs["list"] ?? firstCapture(#/href="\/decks\/list\/(\d+)"/#, in: rowHTML)
            )
        }

        return LimitlessPlayerProfile(
            id: id,
            name: name,
            country: country,
            totalPoints: totalPoints,
            totalPrizeMoney: totalPrize,
            travelAwards: travelAwards,
            topCuts: topCuts,
            results: results
        )
    }

    // MARK: - Private helpers

    // Split HTML into blocks that start with a tag containing anchorAttr.
    private static func splitRows(_ html: String, anchorAttr: String) -> [String] {
        var result: [String] = []
        var searchRange = html.startIndex..<html.endIndex
        let openTag = "<tr "

        while let rowStart = html.range(of: openTag, range: searchRange) {
            // Check this <tr ...> contains our anchor attribute before the closing >
            let lineEnd = html[rowStart.upperBound...].firstIndex(of: ">") ?? html.endIndex
            let tagContent = html[rowStart.lowerBound...lineEnd]
            guard tagContent.contains(anchorAttr) else {
                searchRange = rowStart.upperBound..<html.endIndex
                continue
            }
            // Find the matching </tr>
            if let closeTag = html.range(of: "</tr>", range: rowStart.upperBound..<html.endIndex) {
                result.append(String(html[rowStart.lowerBound..<closeTag.upperBound]))
                searchRange = closeTag.upperBound..<html.endIndex
            } else {
                break
            }
        }
        return result
    }

    // Extracts all data-key="value" pairs from a string into a dictionary.
    private static func dataAttributes(in html: String) -> [String: String] {
        var dict: [String: String] = [:]
        for match in html.matches(of: #/data-(?<key>\w+)="(?<value>[^"]*)"/#) {
            dict[String(match.key)] = String(match.value)
        }
        return dict
    }

    // Returns the first capture group from a regex match, or nil.
    private static func firstCapture<R: RegexComponent>(_ pattern: R, in string: String) -> String?
    where R.RegexOutput == (Substring, Substring) {
        string.firstMatch(of: pattern).map { String($0.1) }
    }

    private static func parseDate(_ string: String) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string)
    }
}

// MARK: - HTML entity decoding

private extension String {
    var htmlDecoded: String {
        var s = self

        // Named entities — covers characters common in Pokémon names and tournament titles
        let named: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'"),
            ("&ndash;", "–"), ("&mdash;", "—"), ("&nbsp;", "\u{A0}"), ("&hellip;", "…"),
            ("&eacute;", "é"), ("&ecirc;", "ê"), ("&egrave;", "è"), ("&euml;", "ë"),
            ("&aacute;", "á"), ("&acirc;", "â"), ("&agrave;", "à"), ("&auml;", "ä"),
            ("&iacute;", "í"), ("&icirc;", "î"), ("&igrave;", "ì"), ("&iuml;", "ï"),
            ("&oacute;", "ó"), ("&ocirc;", "ô"), ("&ograve;", "ò"), ("&ouml;", "ö"),
            ("&uacute;", "ú"), ("&ucirc;", "û"), ("&ugrave;", "ù"), ("&uuml;", "ü"),
        ]
        for (entity, char) in named {
            s = s.replacingOccurrences(of: entity, with: char)
        }

        // Decimal numeric references: &#NNNN;
        s = s.replacing(/&#(\d+);/) { match in
            guard let cp = UInt32(match.1), let scalar = Unicode.Scalar(cp) else { return String(match.0) }
            return String(Character(scalar))
        }

        // Hex numeric references: &#xNNNN; or &#XNNNN;
        s = s.replacing(/&#[xX]([0-9a-fA-F]+);/) { match in
            guard let cp = UInt32(match.1, radix: 16), let scalar = Unicode.Scalar(cp) else { return String(match.0) }
            return String(Character(scalar))
        }

        return s
    }
}
