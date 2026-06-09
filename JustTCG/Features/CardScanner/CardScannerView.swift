import SwiftUI
import AVFoundation
import SwiftData

struct CardScannerView: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var vm: CardScannerViewModel? = nil

    var body: some View {
        Group {
            if let vm {
                scannerContent(vm: vm)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            if vm == nil {
                vm = CardScannerViewModel(deck: deck, context: context)
            }
        }
        .onDisappear { vm?.stopSession() }
    }

    @ViewBuilder
    private func scannerContent(vm: CardScannerViewModel) -> some View {
        ZStack {
            if vm.permissionDenied {
                permissionDeniedView
            } else {
                cameraLayer(vm: vm)
                overlayLayer(vm: vm)
            }
        }
        .ignoresSafeArea()
        .alert("Camera Access Required", isPresented: .constant(vm.permissionDenied)) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("Please enable camera access in Settings to scan cards.")
        }
    }

    // MARK: - Camera layer

    @ViewBuilder
    private func cameraLayer(vm: CardScannerViewModel) -> some View {
        CameraPreviewView(session: vm.session) { pixelBuffer in
            vm.processFrame(pixelBuffer)
        }
        .ignoresSafeArea()
    }

    // MARK: - Overlay

    @ViewBuilder
    private func overlayLayer(vm: CardScannerViewModel) -> some View {
        GeometryReader { geo in
            ZStack {
                // dimming
                Color.black.opacity(0.35).ignoresSafeArea()

                // card guide
                cardOutline(vm: vm, geo: geo)

                // top bar
                VStack {
                    topBar(vm: vm)
                    Spacer()
                }

                // bottom sheet
                VStack {
                    Spacer()
                    bottomSheet(vm: vm)
                }
            }
        }
    }

    private func cardOutline(vm: CardScannerViewModel, geo: GeometryProxy) -> some View {
        let width = geo.size.width * 0.7
        let height = width * 10 / 7
        let color = outlineColor(vm: vm)
        return RoundedRectangle(cornerRadius: 12)
            .strokeBorder(color, lineWidth: 3)
            .frame(width: width, height: height)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: color)
    }

    private func outlineColor(vm: CardScannerViewModel) -> Color {
        switch vm.state {
        case .matched(let primary, _):
            _ = primary
            return .green
        case .paused:  return .yellow
        case .scanning: return .white.opacity(0.6)
        }
    }

    // MARK: - Top bar

    private func topBar(vm: CardScannerViewModel) -> some View {
        HStack {
            Text("\(vm.addedCount) added")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            Button("Done") { dismiss() }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    // MARK: - Bottom sheet

    @ViewBuilder
    private func bottomSheet(vm: CardScannerViewModel) -> some View {
        if case .matched(let primary, _) = vm.state {
            matchSheet(vm: vm, card: primary)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func matchSheet(vm: CardScannerViewModel, card: CachedCard) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: card.imageURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                }
                .frame(width: 60, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.headline)
                    Text("\(card.setName) · \(card.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let qty = vm.quantityInDeck(for: card)
                    Text("In deck: \(qty)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    if case .matched(let p, _) = vm.state {
                        vm.state = .scanning
                        _ = p
                    }
                } label: {
                    Text("Not right?")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button { vm.addCard(card) } label: {
                    Text("+ Add")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    // MARK: - Permission denied

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera Access Required")
                .font(.title3.bold())
            Text("Enable camera access in Settings to scan cards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}
