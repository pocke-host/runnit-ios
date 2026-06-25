import Foundation
import UIKit

@MainActor
final class MediaUploadService: ObservableObject {
    static let shared = MediaUploadService()
    @Published var isUploading = false

    private let api = APIClient.shared
    private init() {}

    // MARK: - Upload

    /// Compresses image to JPEG, obtains a presigned S3 URL, PUTs the data, returns the public CDN URL.
    func upload(image: UIImage, folder: String = "media") async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.compressionFailed
        }

        isUploading = true
        defer { isUploading = false }

        let fileName = "\(folder)/\(UUID().uuidString).jpg"
        let sign = try await signUpload(fileName: fileName, contentType: "image/jpeg")

        try await putToS3(data: data, uploadURL: sign.uploadUrl)
        return sign.publicUrl
    }

    // MARK: - Private

    private struct SignResponse: Decodable {
        let uploadUrl: String
        let publicUrl: String
    }

    private struct SignBody: Encodable {
        let fileName: String
        let contentType: String
    }

    private func signUpload(fileName: String, contentType: String) async throws -> SignResponse {
        try await api.request(
            "/uploads/sign",
            method: "POST",
            body: SignBody(fileName: fileName, contentType: contentType)
        )
    }

    private func putToS3(data: Data, uploadURL: String) async throws {
        guard let url = URL(string: uploadURL) else { throw UploadError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UploadError.s3Failed
        }
    }

    enum UploadError: LocalizedError {
        case compressionFailed, invalidURL, s3Failed
        var errorDescription: String? {
            switch self {
            case .compressionFailed: return "Failed to compress image"
            case .invalidURL:        return "Invalid upload URL"
            case .s3Failed:          return "Upload to storage failed"
            }
        }
    }
}
