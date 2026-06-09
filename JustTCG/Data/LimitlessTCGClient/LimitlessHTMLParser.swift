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

    // MARK: - Player list  (/players  or  /players?q=<query>)
    //
    // Leaderboard row (5 cols):
    //   <tr><td>{rank}</td><td><a href="/players/{id}">{name}</a></td>
    //       <td>[social]</td><td><img class="flag" alt="{country}"></td><td>{points}</td></tr>
    //
    // Search-result row (3 cols):
    //   <tr><td><a href="/players/{id}">{name}</a></td>
    //       <td>[social]</td><td><img class="flag" alt="{country}"></td></tr>
    //
    // No data-* attributes — all data is in td/img content.
    static func parsePlayerRows(from html: String) -> [LimitlessPlayerSearchResult] {
        html.components(separatedBy: "<tr>").dropFirst().compactMap { chunk in
            guard let end = chunk.range(of: "</tr>") else { return nil }
            let row = String(chunk[..<end.lowerBound])

            guard
                let id   = firstCapture(#/href="\/players\/(\d+)"/#, in: row),
                let name = firstCapture(#/<a[^>]*href="\/players\/\d+"[^>]*>([^<]+)<\/a>/#, in: row)
            else { return nil }

            let country = firstCapture(#/class="flag"[^>]*alt="([^"]+)"/#, in: row) ?? ""
            let digits  = row.matches(of: #/<td>(\d+)<\/td>/#).map { String($0.1) }

            return LimitlessPlayerSearchResult(
                id:      id,
                name:    name.htmlDecoded,
                country: country,
                rank:    digits.count >= 2 ? digits.first.flatMap(Int.init) : nil,
                points:  digits.count >= 2 ? digits.last.flatMap(Int.init) : nil
            )
        }
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
    //
    // Actual page structure (no data-* attributes on containers):
    //   Name/country: <div class="infobox-heading"> Henry Chao <img class="flag" alt="US">
    //   Finishes:     plain <tr> rows — date | tournament link | "25th" | deck span | list link | cash | pts
    //   Career cuts:  <tr><td>International</td><td>0</td><td>0</td><td>0</td><td>1</td>...</tr>
    //   Summary:      <tr><td>84,000$</td><td>379</td><td><a...>2</a></td></tr>
    static func parsePlayerProfile(id: String, from html: String) -> LimitlessPlayerProfile? {
        // -- Name --
        var name = ""
        if let range = html.range(of: "infobox-heading") {
            let after = html[range.upperBound...]
            if let gt = after.firstIndex(of: ">"),
               let lt = after[after.index(after: gt)...].firstIndex(of: "<") {
                name = String(after[after.index(after: gt)..<lt])
                    .trimmingCharacters(in: .whitespaces)
                    .htmlDecoded
            }
        }
        guard !name.isEmpty else { return nil }

        // -- Country (first flag image on the page) --
        let country = firstCapture(#/<img[^>]*class="flag"[^>]*alt="([^"]+)"/#, in: html) ?? ""

        // -- Split into sections --
        let careerStart = html.range(of: "Career stats")
        let finishesEnd = careerStart?.lowerBound ?? html.endIndex
        let finishesHTML: String = {
            guard let start = html.range(of: "Latest tournament finishes") else { return "" }
            return String(html[start.lowerBound..<finishesEnd])
        }()
        let careerHTML: String = careerStart.map { String(html[$0.lowerBound...]) } ?? ""

        // -- Tournament results --
        let results: [PlayerTournamentResult] = splitBareRows(finishesHTML).compactMap { row in
            guard row.contains("/tournaments/") else { return nil }  // skip header row
            let cols = tdsContent(in: row)
            guard cols.count >= 3 else { return nil }

            let date      = parseProfileDate(cols[0]) ?? Date.distantPast
            let placement = Int(cols[2].filter(\.isNumber)) ?? 0

            guard let tid   = firstCapture(#/href="\/tournaments\/(\d+)"/#, in: row),
                  let tName = firstCapture(#/<a[^>]*href="\/tournaments\/\d+"[^>]*>([^<]+)<\/a>/#, in: row)
            else { return nil }

            let archetype  = firstCapture(#/<span[^>]*data-tooltip="([^"]+)"[^>]*>/#, in: row)?.htmlDecoded ?? ""
            let deckListId = firstCapture(#/href="\/decks\/list\/(\d+)"/#, in: row)
            let prize      = cols.first(where: { $0.contains("$") }).flatMap { parseMoneyAmount($0) }
            // Points: last column that is a plain integer
            let points     = cols.last(where: { Int($0) != nil }).flatMap { Int($0) } ?? 0

            return PlayerTournamentResult(
                tournamentId:   tid,
                tournamentName: tName.htmlDecoded,
                date:           date,
                placement:      placement,
                record:         "",
                archetype:      archetype,
                points:         points,
                prizeMoney:     prize,
                deckListId:     deckListId
            )
        }

        // -- Career top cuts --
        var topCuts = PlayerTopCuts(
            internationalWins: 0, internationalTop2: 0, internationalTop4: 0, internationalTop8: 0,
            regionalWins: 0, regionalTop2: 0, regionalTop4: 0, regionalTop8: 0
        )
        for row in splitBareRows(careerHTML) {
            let cols = tdsContent(in: row)
            guard cols.count >= 5 else { continue }
            let nums = cols[1...4].compactMap { Int($0) }
            guard nums.count == 4 else { continue }
            if cols[0].contains("International") || cols[0].contains("IC") {
                topCuts = PlayerTopCuts(
                    internationalWins: nums[0], internationalTop2: nums[1],
                    internationalTop4: nums[2], internationalTop8: nums[3],
                    regionalWins: topCuts.regionalWins, regionalTop2: topCuts.regionalTop2,
                    regionalTop4: topCuts.regionalTop4, regionalTop8: topCuts.regionalTop8
                )
            } else if cols[0].contains("Regional") {
                topCuts = PlayerTopCuts(
                    internationalWins: topCuts.internationalWins, internationalTop2: topCuts.internationalTop2,
                    internationalTop4: topCuts.internationalTop4, internationalTop8: topCuts.internationalTop8,
                    regionalWins: nums[0], regionalTop2: nums[1],
                    regionalTop4: nums[2], regionalTop8: nums[3]
                )
            }
        }

        // -- Summary stats (money / points / travel awards) --
        var totalMoney = 0
        var totalPoints = 0
        var travelAwards = 0
        for row in splitBareRows(careerHTML) {
            let cols = tdsContent(in: row)
            guard cols.count >= 3, cols[0].contains("$") else { continue }
            totalMoney   = parseMoneyAmount(cols[0]) ?? 0
            totalPoints  = Int(cols[1]) ?? 0
            travelAwards = Int(cols[2]) ?? 0
            break
        }

        return LimitlessPlayerProfile(
            id: id,
            name: name,
            country: country,
            totalPoints: totalPoints,
            totalPrizeMoney: totalMoney,
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

    // Splits HTML on bare <tr> tags (no attributes).
    private static func splitBareRows(_ html: String) -> [String] {
        html.components(separatedBy: "<tr>").dropFirst().compactMap { chunk in
            guard let end = chunk.range(of: "</tr>") else { return nil }
            return String(chunk[..<end.lowerBound])
        }
    }

    // Returns stripped plain-text content of each <td> in a row.
    private static func tdsContent(in rowHTML: String) -> [String] {
        rowHTML.components(separatedBy: "<td").dropFirst().compactMap { chunk in
            guard let gt = chunk.firstIndex(of: ">"),
                  let end = chunk.range(of: "</td>") else { return nil }
            let inner = String(chunk[chunk.index(after: gt)..<end.lowerBound])
            return inner.replacing(#/<[^>]+>/#, with: "")
                        .trimmingCharacters(in: .whitespaces)
        }
    }

    // Parses profile-page dates like "30 May 26" → 2026-05-30.
    private static func parseProfileDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string.trimmingCharacters(in: .whitespaces))
    }

    // Parses money strings like "84,000$", "1K$", "5K$" → Int.
    private static func parseMoneyAmount(_ s: String) -> Int? {
        let t = s.replacingOccurrences(of: ",", with: "")
                 .replacingOccurrences(of: "$", with: "")
                 .trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if t.uppercased().hasSuffix("K"), let n = Int(t.dropLast()) { return n * 1_000 }
        return Int(t)
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
