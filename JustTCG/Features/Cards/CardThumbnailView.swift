import SwiftUI

struct CardThumbnailView: View {
    let card: CachedCard

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
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            @unknown default:
                EmptyView()
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.15))
            .aspectRatio(7/10, contentMode: .fit)
    }
}
