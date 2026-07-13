import Foundation

/// URLSession client. Reproduces Android's DynamicBaseUrlInterceptor (origin from
/// ConnectionStore) + AuthInterceptor (?token= on authenticated data requests).
/// Auth endpoints (login/verify/logout) carry the token in the BODY, per the backend.
final class APIClient {
    private let store: ConnectionStore
    private let session: URLSession
    private let decoder = makeAPIJSONDecoder()

    init(store: ConnectionStore, session: URLSession = .shared) {
        self.store = store
        self.session = session
    }

    private func url(path: String, query: [URLQueryItem] = []) throws -> URL {
        guard let origin = store.serverURL,
              let u = composeURL(origin: origin, path: path, queryItems: query) else {
            throw APIError.transport("Kein Server konfiguriert")
        }
        return u
    }

    private func postJSON<Body: Encodable, Out: Decodable>(
        path: String, body: Body, authenticated: Bool
    ) async throws -> Out {
        var query: [URLQueryItem] = []
        if authenticated, let token = Keychain.token() {
            query.append(URLQueryItem(name: "token", value: token))
        }
        var req = URLRequest(url: try url(path: path, query: query))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        req.timeoutInterval = 30

        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let e as URLError where e.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let apiErr = mapHTTPStatus(status, body: data) { throw apiErr }
        do {
            return try decoder.decode(Out.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    /// Login sends username+password (plaintext) in the body; server SHA-256s it.
    func login(username: String, password: String) async throws -> LoginResponse {
        try await postJSON(path: "/auth/login",
                           body: LoginRequest(username: username, password: password),
                           authenticated: false)
    }

    func verify(token: String) async throws -> VerifyResponse {
        try await postJSON(path: "/auth/verify",
                           body: VerifyRequest(token: token),
                           authenticated: false)
    }

    /// Best-effort logout; token travels in the body.
    func logout(token: String) async {
        let _: SuccessResponse? = try? await postJSON(
            path: "/auth/logout", body: LogoutRequest(token: token), authenticated: false)
    }

    // MARK: - Data (authenticated GET; ?token= query)

    private func getJSON<Out: Decodable>(path: String, query: [URLQueryItem] = []) async throws -> Out {
        var q = query
        if let token = Keychain.token() {
            q.append(URLQueryItem(name: "token", value: token))
        }
        var req = URLRequest(url: try url(path: path, query: q))
        req.httpMethod = "GET"
        req.timeoutInterval = 30

        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let e as URLError where e.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let apiErr = mapHTTPStatus(status, body: data) { throw apiErr }
        do {
            return try decoder.decode(Out.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    func getCustomers(search: String? = nil) async throws -> [Customer] {
        var q: [URLQueryItem] = []
        if let s = search, !s.isEmpty { q.append(URLQueryItem(name: "search", value: s)) }
        let resp: CustomerListResponse = try await getJSON(path: "/kunden", query: q)
        return resp.customers
    }

    func getVisits() async throws -> [Visit] {
        let resp: VisitListResponse = try await getJSON(path: "/besuche")
        return resp.visits
    }
}
