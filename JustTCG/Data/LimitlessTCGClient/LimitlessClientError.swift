import Foundation

enum LimitlessClientError: LocalizedError {
    case decodingFailed(String)
    case networkError(Error)
    case invalidResponse(Int)
    case offline
    case retryExhausted(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .decodingFailed(let detail):
            return "Unable to read card data — check for an app update. (\(detail))"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        case .invalidResponse(let code):
            return "Unexpected server response (HTTP \(code))"
        case .offline:
            return "No internet connection"
        case .retryExhausted(let err):
            return "Request failed after retries: \(err.localizedDescription)"
        }
    }
}
