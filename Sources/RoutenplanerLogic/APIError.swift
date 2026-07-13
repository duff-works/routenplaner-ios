import Foundation

public enum APIError: Error, Equatable {
    case transport(String)
    case timeout
    case http(status: Int, detail: String?)
    case decoding(String)
    case unauthorized
}

/// Extracts the FastAPI `{"detail": "..."}` message if present.
public func parseErrorDetail(_ body: Data) -> String? {
    guard let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
          let detail = obj["detail"] as? String else { return nil }
    return detail
}

/// Maps an HTTP status to an APIError. Returns nil for 2xx (success).
public func mapHTTPStatus(_ status: Int, body: Data) -> APIError? {
    switch status {
    case 200..<300: return nil
    case 401:       return .unauthorized
    default:        return .http(status: status, detail: parseErrorDetail(body))
    }
}
