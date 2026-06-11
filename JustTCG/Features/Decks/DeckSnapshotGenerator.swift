import SwiftUI
import UIKit

enum DeckSnapshotError: Error { case renderFailed }

struct DeckSnapshotGenerator {

    struct CardItem {
        let imageURL: String
        let name: String
        let quantity: Int
    }

    @MainActor
    static func generate(cards: [CardItem], deckName: String) async throws -> UIImage {
        let images = await downloadAll(urls: cards.map(\.imageURL))
        let pairs = Array(zip(cards, images))
        let view = DeckSnapshotLayout(pairs: pairs, deckName: deckName)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        guard let uiImage = renderer.uiImage else { throw DeckSnapshotError.renderFailed }
        return uiImage
    }

    private static func downloadAll(urls: [String]) async -> [UIImage?] {
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (i, urlString) in urls.enumerated() {
                group.addTask {
                    guard let url = URL(string: urlString),
                          let (data, _) = try? await URLSession.shared.data(from: url),
                          let img = UIImage(data: data)
                    else { return (i, nil) }
                    return (i, img)
                }
            }
            var result = [UIImage?](repeating: nil, count: urls.count)
            for await (i, img) in group { result[i] = img }
            return result
        }
    }
}

// MARK: - Layout

private let snapshotCols: Int     = 10
private let snapshotCardW: CGFloat = 115
private let snapshotCardH: CGFloat = 161   // ≈ 5:7 aspect ratio
private let snapshotHGap: CGFloat  = 8
private let snapshotVGap: CGFloat  = 8
private let snapshotEdge: CGFloat  = 16

private struct DeckSnapshotLayout: View {
    let pairs: [(DeckSnapshotGenerator.CardItem, UIImage?)]
    let deckName: String

    private var canvasWidth: CGFloat {
        snapshotEdge * 2
            + CGFloat(snapshotCols) * snapshotCardW
            + CGFloat(snapshotCols - 1) * snapshotHGap
    }

    private var rows: [[(DeckSnapshotGenerator.CardItem, UIImage?)]] {
        stride(from: 0, to: pairs.count, by: snapshotCols).map { start in
            Array(pairs[start..<min(start + snapshotCols, pairs.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            cardGrid
        }
        .frame(width: canvasWidth)
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(deckName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                let total = pairs.reduce(0) { $0 + $1.0.quantity }
                Text("\(total) cards · \(pairs.count) unique")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Text("Just TCG")
                .font(.system(size: 15, weight: .black))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, snapshotEdge)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: Card grid

    private var cardGrid: some View {
        VStack(alignment: .leading, spacing: snapshotVGap) {
            ForEach(rows.indices, id: \.self) { rIdx in
                HStack(alignment: .top, spacing: snapshotHGap) {
                    ForEach(rows[rIdx].indices, id: \.self) { cIdx in
                        cardCell(rows[rIdx][cIdx])
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, snapshotEdge)
        .padding(.bottom, 16)
    }

    private func cardCell(_ pair: (DeckSnapshotGenerator.CardItem, UIImage?)) -> some View {
        let (item, image) = pair
        return ZStack(alignment: .bottomLeading) {
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.08))
                }
            }
            .frame(width: snapshotCardW, height: snapshotCardH)
            .clipShape(RoundedRectangle(cornerRadius: 7))

            // Count badge
            ZStack {
                Circle()
                    .fill(Color.red)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                Text("\(item.quantity)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)
            .padding(5)
        }
        .frame(width: snapshotCardW, height: snapshotCardH)
    }
}
