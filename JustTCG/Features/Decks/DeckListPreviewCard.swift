import SwiftUI

struct DeckListPreviewCard: View {
    let deckList: String
    var onImport: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(deckList)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 14))
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = deckList
                        } label: {
                            Label("Copy Deck", systemImage: "doc.on.doc")
                        }
                    }
                Spacer(minLength: 60)
            }

            Button {
                onImport(deckList)
            } label: {
                Label("Import Deck", systemImage: "arrow.down.doc.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }
}
