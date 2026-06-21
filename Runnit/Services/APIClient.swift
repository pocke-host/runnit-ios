import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:         return "Invalid URL"
        case .noData:             return "No data received"
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .unauthorized:       return "Session expired. Please log in again."
        case .networkError(let e): return e.localizedDescription
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    #if DEBUG
    private let baseURL = "http://localhost:8080/api"
    #else
    private let baseURL = "https://ati-runnit-java.onrender.com/api"
    #endif

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Core request

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = KeychainHelper.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw APIError.noData }

            if http.statusCode == 401 {
                // Token expired — notify app to log out
                await MainActor.run { NotificationCenter.default.post(name: .apiUnauthorized, object: nil) }
                throw APIError.unauthorized
            }

            if !(200...299).contains(http.statusCode) {
                let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(http.statusCode, msg)
            }

            do {
                return try JSONDecoder.runnit.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // Void response (204 / no body)
    func requestVoid(
        _ path: String,
        method: String = "POST",
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = KeychainHelper.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        do {
            let (_, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 401 {
                await MainActor.run { NotificationCenter.default.post(name: .apiUnauthorized, object: nil) }
                throw APIError.unauthorized
            }

            if !(200...299).contains(http.statusCode) {
                throw APIError.serverError(http.statusCode, "Request failed")
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}

// MARK: - JSONDecoder with ISO8601

extension JSONDecoder {
    static let runnit: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            // ISO8601 with timezone (Instant fields)
            let isoFmts: [ISO8601DateFormatter] = [
                { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }(),
                { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }(),
            ]
            for fmt in isoFmts {
                if let date = fmt.date(from: str) { return date }
            }
            // LocalDateTime from Spring (no timezone offset) — treat as UTC
            let localFmt = DateFormatter()
            localFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            localFmt.locale = Locale(identifier: "en_US_POSIX")
            localFmt.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = localFmt.date(from: str) { return date }

            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Cannot parse date: \(str)")
        }
        return d
    }()
}

extension Notification.Name {
    static let apiUnauthorized = Notification.Name("APIClientUnauthorized")
}
