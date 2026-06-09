import SwiftUI
import AVFoundation
import SwiftData

enum ScanState {
    case scanning
    case matched(primary: CachedCard, alternatives: [CachedCard])
    case paused
}

@Observable
@MainActor
final class CardScannerViewModel {

    var state: ScanState = .scanning
    var addedCount: Int = 0
    var permissionDenied: Bool = false
    var isTorchOn: Bool = false
    let session: AVCaptureSession = AVCaptureSession()

    private let scanner = CardScannerService()
    private var matcher: CardScanMatcher
    private var deck: Deck
    private var context: ModelContext
    private var isProcessing = false
    private var captureDevice: AVCaptureDevice? = nil

    init(deck: Deck, context: ModelContext) {
        self.deck = deck
        self.context = context
        self.matcher = CardScanMatcher(context: context)
        setupSession()
    }

    // MARK: - Camera setup

    private func setupSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted { self?.configureSession() }
                    else { self?.permissionDenied = true }
                }
            }
        default:
            permissionDenied = true
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.commitConfiguration()
        captureDevice = device
        Task.detached { [session] in session.startCapture() }
    }

    // MARK: - Frame processing

    nonisolated func processFrame(_ pixelBuffer: CVPixelBuffer) {
        Task { @MainActor in
            guard !isProcessing, case .scanning = state else { return }
            isProcessing = true
            defer { isProcessing = false }
            guard let result = try? await scanner.scan(pixelBuffer: pixelBuffer),
                  result.confidence != .low else { return }
            let matches = await matcher.match(result: result)
            guard let primary = matches.first else { return }
            state = .matched(primary: primary, alternatives: Array(matches.dropFirst()))
        }
    }

    // MARK: - Actions

    func addCard(_ card: CachedCard) {
        let isEnergy = card.supertype == "Energy"
        DeckRepository(modelContext: context).addCard(cardId: card.id, to: deck, isBasicEnergy: isEnergy, cardName: card.name)
        addedCount += 1
        state = .paused
        Task {
            try? await Task.sleep(for: .seconds(1))
            state = .scanning
        }
    }

    func quantityInDeck(for card: CachedCard) -> Int {
        deck.cards.first(where: { $0.cardId == card.id })?.quantity ?? 0
    }

    func toggleTorch() {
        guard let device = captureDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            isTorchOn.toggle()
            device.torchMode = isTorchOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Torch unavailable on this device
        }
    }

    func stopSession() {
        // Ensure torch is off when leaving the scanner
        if isTorchOn, let device = captureDevice, device.hasTorch,
           (try? device.lockForConfiguration()) != nil {
            device.torchMode = .off
            device.unlockForConfiguration()
        }
        Task.detached { [session] in session.stopCapture() }
    }
}

private extension AVCaptureSession {
    func startCapture() { startRunning() }
    func stopCapture() { stopRunning() }
}
