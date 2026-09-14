import Foundation

/// Thin client for Sefaria's v3 texts API.
/// Docs: https://developers.sefaria.org/reference/get-v3-texts
actor SefariaClient {
    static let shared = SefariaClient()

    enum ClientError: LocalizedError {
        case badURL(String)
        case http(Int)
        case api(String)
        case noVersions

        var errorDescription: String? {
            switch self {
            case .badURL(let ref): "Could not build a URL for “\(ref)”."
            case .http(let code): "Sefaria returned HTTP \(code)."
            case .api(let message): message
            case .noVersions: "Sefaria has no text for this prayer."
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(ref: String) async throws -> PrayerLeafText {
        #if DEBUG
        // SIDDUR_OFFLINE=1 simulates no connectivity so the bundled-text path can be tested.
        if ProcessInfo.processInfo.environment["SIDDUR_OFFLINE"] != nil {
            throw URLError(.notConnectedToInternet)
        }
        #endif
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.sefaria.org"
        components.path = "/api/v3/texts/" + ref
        components.queryItems = [
            URLQueryItem(name: "version", value: "hebrew"),
            URLQueryItem(name: "version", value: "english"),
            URLQueryItem(name: "return_format", value: "default"),
        ]
        guard let url = components.url else { throw ClientError.badURL(ref) }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let err = try? JSONDecoder().decode(APIError.self, from: data) { throw ClientError.api(err.error) }
            throw ClientError.http(http.statusCode)
        }
        if let err = try? JSONDecoder().decode(APIError.self, from: data) { throw ClientError.api(err.error) }

        let payload = try JSONDecoder().decode(TextResponse.self, from: data)
        return try Self.makeLeafText(from: payload, requestedRef: ref)
    }

    // MARK: - Wire format

    private struct APIError: Decodable { let error: String }

    struct TextResponse: Decodable {
        let ref: String
        let heRef: String?
        let title: String?
        let heTitle: String?
        let versions: [Version]

        struct Version: Decodable {
            let language: String
            let versionTitle: String?
            let text: JaggedText
        }
    }

    /// Sefaria returns text as a string, an array of strings, or nested arrays.
    enum JaggedText: Decodable, Sendable {
        case string(String)
        case array([JaggedText])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) {
                self = .string(s)
            } else if let arr = try? container.decode([JaggedText].self) {
                self = .array(arr)
            } else if container.decodeNil() {
                self = .string("")
            } else {
                throw DecodingError.typeMismatch(JaggedText.self, .init(codingPath: decoder.codingPath, debugDescription: "Unexpected text shape"))
            }
        }

        /// Flattens to a list of paragraph strings in reading order.
        var flattened: [String] {
            switch self {
            case .string(let s): [s]
            case .array(let items): items.flatMap(\.flattened)
            }
        }
    }

    static func makeLeafText(from payload: TextResponse, requestedRef: String) throws -> PrayerLeafText {
        guard !payload.versions.isEmpty else { throw ClientError.noVersions }
        let he = payload.versions.first { $0.language == "he" }
        let en = payload.versions.first { $0.language == "en" }
        let heParas = he?.text.flattened ?? []
        let enParas = en?.text.flattened ?? []
        let count = max(heParas.count, enParas.count)

        var paragraphs: [PrayerParagraph] = []
        paragraphs.reserveCapacity(count)
        for i in 0..<count {
            let h = i < heParas.count ? heParas[i] : ""
            let e = i < enParas.count ? enParas[i] : ""
            let ht = h.trimmingCharacters(in: .whitespacesAndNewlines)
            let et = e.trimmingCharacters(in: .whitespacesAndNewlines)
            if ht.isEmpty && et.isEmpty { continue }
            paragraphs.append(PrayerParagraph(index: i, hebrewHTML: ht, englishHTML: et))
        }

        let titleFromRef = payload.ref.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? payload.ref
        let heTitleFromRef = payload.heRef?.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""

        return PrayerLeafText(
            ref: payload.ref.isEmpty ? requestedRef : payload.ref,
            heRef: payload.heRef ?? "",
            title: titleFromRef,
            heTitle: heTitleFromRef,
            hebrewVersionTitle: he?.versionTitle,
            englishVersionTitle: en?.versionTitle,
            paragraphs: paragraphs
        )
    }
}
