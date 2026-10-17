import Foundation

/// Uploads tracks to a WordPress site via the REST API (application passwords),
/// creating a draft post containing the Fotospur block.
struct WordPressClient {
    static let siteURLKey = "wordpressSiteURL"
    static let usernameKey = "wordpressUsername"
    static let passwordAccount = "wordpressApplicationPassword"

    enum WPError: LocalizedError {
        case notConfigured
        case invalidURL
        case insecureURL
        case unauthorized
        case forbidden
        case network(String)
        case http(Int, String?)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "WordPress ist nicht eingerichtet. Bitte Website, Benutzername und Anwendungspasswort in den Einstellungen eintragen."
            case .invalidURL:
                return "Die Website-URL ist ungültig. Beispiel: https://meine-website.de"
            case .insecureURL:
                return "Die Website muss über https erreichbar sein, damit dein Passwort verschlüsselt übertragen wird."
            case .unauthorized:
                return "Anmeldung fehlgeschlagen. Bitte Benutzername und Anwendungspasswort prüfen."
            case .forbidden:
                return "Keine Berechtigung. Der Benutzer darf keine Medien oder Beiträge anlegen."
            case .network(let message):
                return "Netzwerkfehler: \(message)"
            case .http(let status, let message):
                if let message, !message.isEmpty {
                    return "Fehler vom Server (HTTP \(status)): \(message)"
                }
                return "Fehler vom Server (HTTP \(status))."
            case .invalidResponse:
                return "Unerwartete Antwort vom Server."
            }
        }
    }

    let siteURL: URL
    let username: String
    let password: String

    /// Builds a client from the stored settings.
    static func fromSettings() throws -> WordPressClient {
        let defaults = UserDefaults.standard
        let site = (defaults.string(forKey: siteURLKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let user = (defaults.string(forKey: usernameKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let password = KeychainHelper.read(account: passwordAccount) ?? ""
        guard !site.isEmpty, !user.isEmpty, !password.isEmpty else { throw WPError.notConfigured }
        return try WordPressClient(site: site, username: user, password: password)
    }

    init(site: String, username: String, password: String) throws {
        var site = site.trimmingCharacters(in: .whitespacesAndNewlines)
        while site.hasSuffix("/") { site.removeLast() }
        // Accept pasted admin or REST URLs and keep only the site root.
        for suffix in ["/wp-admin", "/wp-json", "/wp-login.php"] {
            if let range = site.range(of: suffix, options: .caseInsensitive) {
                site = String(site[..<range.lowerBound])
            }
        }
        while site.hasSuffix("/") { site.removeLast() }
        if site.lowercased().hasPrefix("http://") { throw WPError.insecureURL }
        if !site.lowercased().hasPrefix("https://") { site = "https://" + site }
        guard let url = URL(string: site), let host = url.host, host.contains(".") else { throw WPError.invalidURL }
        self.siteURL = url
        self.username = username
        // Application passwords are displayed with spaces; WordPress accepts them either way.
        self.password = password.replacingOccurrences(of: " ", with: "")
    }

    // MARK: - API

    /// Returns the display name of the authenticated user.
    func testConnection() async throws -> String {
        var components = URLComponents(url: endpoint("users/me"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "context", value: "edit")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        let json = try await send(request)
        return (json["name"] as? String) ?? (json["slug"] as? String) ?? username
    }

    /// Uploads the GPX file and returns the media attachment id.
    func uploadGPX(_ data: Data, fileName: String) async throws -> Int {
        try await uploadMedia(data, fileName: fileName, contentType: "application/gpx+xml")
    }

    /// Uploads a JPEG photo and returns the media attachment id.
    func uploadPhoto(_ data: Data, fileName: String) async throws -> Int {
        try await uploadMedia(data, fileName: fileName, contentType: "image/jpeg")
    }

    private func uploadMedia(_ data: Data, fileName: String, contentType: String) async throws -> Int {
        var request = URLRequest(url: endpoint("media"))
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("attachment; filename=\"\(fileName)\"", forHTTPHeaderField: "Content-Disposition")
        request.httpBody = data
        let json = try await send(request)
        guard let id = json["id"] as? Int else { throw WPError.invalidResponse }
        return id
    }

    /// Creates a draft post containing the Fotospur block and returns the post id.
    func createDraftPost(title: String, gpxId: Int, imageIds: [Int] = []) async throws -> Int {
        var attributes: [String: Any] = ["gpxId": gpxId, "name": title]
        if !imageIds.isEmpty {
            attributes["imageIds"] = imageIds
        }
        let attributeData = try JSONSerialization.data(withJSONObject: attributes, options: [.sortedKeys, .withoutEscapingSlashes])
        // Escape characters that would break the HTML comment, like Gutenberg's serializer does.
        let attributeJSON = String(decoding: attributeData, as: UTF8.self)
            .replacingOccurrences(of: "--", with: "\\u002d\\u002d")
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: ">", with: "\\u003e")
            .replacingOccurrences(of: "&", with: "\\u0026")
        let content = "<!-- wp:tourspur/fotospur \(attributeJSON) /-->"

        var request = URLRequest(url: endpoint("posts"))
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "title": title,
            "status": "draft",
            "content": content,
        ])
        let json = try await send(request)
        guard let id = json["id"] as? Int else { throw WPError.invalidResponse }
        return id
    }

    /// ASCII-only file name for the Content-Disposition header, e.g. "Strecke-08102026-0542.gpx".
    static func uploadFileName(for trackName: String, fileExtension: String = "gpx") -> String {
        let folded = trackName
            .replacingOccurrences(of: "ß", with: "ss")
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let base = String(folded.map { $0 == " " ? "-" : $0 }.filter { allowed.contains($0) })
        return (base.isEmpty ? "Strecke" : base) + "." + fileExtension
    }

    /// URL of the WordPress editor for a post.
    func editURL(postId: Int) -> URL {
        var components = URLComponents(url: siteURL.appendingPathComponent("wp-admin/post.php"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "post", value: String(postId)),
            URLQueryItem(name: "action", value: "edit"),
        ]
        return components.url!
    }

    // MARK: - Helpers

    private func endpoint(_ path: String) -> URL {
        siteURL.appendingPathComponent("wp-json/wp/v2/" + path)
    }

    private func send(_ request: URLRequest) async throws -> [String: Any] {
        var request = request
        let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw WPError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw WPError.invalidResponse }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        switch http.statusCode {
        case 200..<300:
            guard let json else { throw WPError.invalidResponse }
            return json
        case 401:
            throw WPError.unauthorized
        case 403:
            throw WPError.forbidden
        default:
            throw WPError.http(http.statusCode, json?["message"] as? String)
        }
    }
}
