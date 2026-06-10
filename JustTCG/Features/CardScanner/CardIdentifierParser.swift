import Foundation

struct CardIdentifierParser {

    func parse(lines: [String]) -> CardScanResult {
        let number = extractCardNumber(from: lines)
        let setCode = extractSetCode(from: lines, nearLine: number?.lineIndex)
        let cardName = extractCardName(from: lines)

        let confidence: ScanConfidence
        if number != nil && setCode != nil {
            confidence = .high
        } else if number != nil || (cardName != nil && number == nil) {
            confidence = .medium
        } else {
            confidence = .low
        }

        return CardScanResult(
            rawLines: lines,
            cardName: cardName,
            setCode: setCode,
            cardNumber: number?.value,
            confidence: confidence
        )
    }

    // MARK: - Extraction helpers

    private struct NumberMatch {
        let value: String
        let lineIndex: Int
    }

    private func extractCardNumber(from lines: [String]) -> NumberMatch? {
        let pattern = #/\b(\d{1,3})\s*/\s*\d{1,3}\b/#
        for (idx, line) in lines.enumerated() {
            if let match = line.firstMatch(of: pattern) {
                return NumberMatch(value: String(match.1), lineIndex: idx)
            }
        }
        return nil
    }

    private static let excludedSetTokens: Set<String> = [
        "HP", "GX", "EX", "VS", "TAG", "ACE", "ATK", "DEF", "SP", "LV",
        "V", "VMAX", "VSTAR"
    ]

    private func extractSetCode(from lines: [String], nearLine: Int?) -> String? {
        let setPattern = #/\b([A-Z]{2,4})\b/#
        let searchRange: Range<Int>
        if let near = nearLine {
            let lo = max(0, near - 1)
            let hi = min(lines.count, near + 2)
            searchRange = lo..<hi
        } else {
            searchRange = 0..<lines.count
        }

        for idx in searchRange {
            let line = lines[idx]
            for match in line.matches(of: setPattern) {
                let candidate = String(match.1)
                if !Self.excludedSetTokens.contains(candidate) {
                    return candidate
                }
            }
        }
        return nil
    }

    private func extractCardName(from lines: [String]) -> String? {
        let topThirdCount = max(1, lines.count / 3)
        let topLines = lines.prefix(topThirdCount)
        return topLines
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 3 else { return false }
                guard !trimmed.allSatisfy({ $0.isNumber || $0 == "/" || $0 == " " }) else { return false }
                // Reject purely-uppercase lines (set codes, HP labels, etc.)
                guard trimmed.contains(where: { $0.isLowercase }) else { return false }
                return true
            }
            .max(by: { $0.count < $1.count })
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
