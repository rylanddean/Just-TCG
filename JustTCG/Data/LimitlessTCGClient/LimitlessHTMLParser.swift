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

            return LimitlessPlacement(
                rank: rank,
                playerName: name.htmlDecoded,
                country: attrs["country"] ?? "",
                archetype: deck.htmlDecoded,
                deckListId: firstCapture(#/href="\/decks\/list\/(\d+)"/#, in: rowHTML)
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
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'"),
        ]
        for (entity, char) in entities {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        return s
    }
}
