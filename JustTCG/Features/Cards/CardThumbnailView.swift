import SwiftUI

struct CardThumbnailView: View {
    let card: CachedCard

    @State private var attempt = 0

    var body: some View {
        AsyncImage(url: URL(string: card.imageURL)) { phase in
            switch phase {
            case .empty:
                placeholder
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            case .failure:
                placeholder
                    .task {
                        // Back off and retry up to 3 times before giving up.
                        guard attempt < 3 else { return }
                        try? await Task.sleep(for: .seconds(Double(attempt + 1) * 2))
                        attempt += 1
                    }
            @unknown default:
                EmptyView()
            }
        }
        .id("\(card.id)-\(attempt)")
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.15))
            .aspectRatio(7/10, contentMode: .fit)
    }
}
