import Foundation
import UniformTypeIdentifiers
import CoreTransferable

struct ShareableBackup: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .json) { backup in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(backup.filename)
            try backup.data.write(to: url)
            return SentTransferredFile(url)
        } importing: { received in
            let data = try Data(contentsOf: received.file)
            return ShareableBackup(data: data, filename: received.file.lastPathComponent)
        }
    }
}
