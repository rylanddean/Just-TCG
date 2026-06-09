import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession
    var onFrame: (CVPixelBuffer) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFrame: onFrame)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "scanner.frames"))
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) { session.addOutput(output) }

        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onFrame = onFrame
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var onFrame: (CVPixelBuffer) -> Void
        private var lastProcessed: CMTime = .invalid

        init(onFrame: @escaping (CVPixelBuffer) -> Void) {
            self.onFrame = onFrame
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if lastProcessed != .invalid {
                let elapsed = CMTimeGetSeconds(CMTimeSubtract(ts, lastProcessed))
                guard elapsed >= 0.5 else { return }
            }
            lastProcessed = ts
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            onFrame(pixelBuffer)
        }
    }

    // MARK: - Preview UIView

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
