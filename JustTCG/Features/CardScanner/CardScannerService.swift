import Foundation
import Vision
import CoreVideo

struct CardScanResult {
    let rawLines: [String]
    let cardName: String?
    let setCode: String?
    let cardNumber: String?
    let confidence: ScanConfidence
}

enum ScanConfidence { case high, medium, low }

@globalActor
actor ScannerActor: GlobalActor {
    static let shared = ScannerActor()
}

final class CardScannerService {

    func scan(pixelBuffer: CVPixelBuffer) async throws -> CardScanResult {
        let lines = try await recognizeText(in: pixelBuffer)
        return CardIdentifierParser().parse(lines: lines)
    }

    @ScannerActor
    private func recognizeText(in pixelBuffer: CVPixelBuffer) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = req.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
