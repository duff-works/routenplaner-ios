import Foundation

/// Normalizes user-entered server input into an origin string `scheme://host[:port]`
/// with no path. Defaults to http and port 8003. Returns nil for invalid input.
public func normalizeServerInput(_ raw: String) -> String? {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }
    if !s.contains("://") { s = "http://" + s }
    while s.hasSuffix("/") { s.removeLast() }
    guard var comps = URLComponents(string: s),
          let host = comps.host, !host.isEmpty else { return nil }
    if comps.port == nil { comps.port = 8003 }
    comps.path = ""
    comps.query = nil
    comps.fragment = nil
    return comps.string
}

/// Overlays `origin`'s scheme/host/port onto `path` (+ optional query items).
/// Mirrors Android's DynamicBaseUrlInterceptor: only scheme/host/port come from
/// the origin; the path and query come from the caller.
public func composeURL(origin: String, path: String,
                       queryItems: [URLQueryItem] = []) -> URL? {
    guard let originComps = URLComponents(string: origin),
          let scheme = originComps.scheme,
          let host = originComps.host else { return nil }
    var comps = URLComponents()
    comps.scheme = scheme
    comps.host = host
    comps.port = originComps.port
    comps.path = path.hasPrefix("/") ? path : "/" + path
    comps.queryItems = queryItems.isEmpty ? nil : queryItems
    return comps.url
}
