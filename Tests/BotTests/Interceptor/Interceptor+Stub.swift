import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension Interceptor {
    struct Stub: Equatable, Codable {
        let request: Request?
        let response: Response

        init(request: Request? = nil, response: Response) {
            self.request = request
            self.response = response
        }
    }
}

extension Interceptor.Stub {

    struct Request: Equatable, Codable {
        let url: URL
        let method: String
        let headers: [String : String]?
        let body: Base64Data?
    }

    struct Response: Equatable {
        let url: URL
        let statusCode: Int
        let headers: [String : String]?
        let body: Base64Data?

        init(url: URL, statusCode: Int, headers: [String: String]? = nil, body: Data? = nil) {
            self.url = url
            self.statusCode = statusCode
            self.headers = headers
            self.body = body.map(Base64Data.init)
        }

        var urlResponse: HTTPURLResponse {
            return HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
        }
    }
}

extension Interceptor.Stub.Response: Codable {
    private enum CodingKeys: String, CodingKey {
        case url
        case statusCode = "status_code"
        case headers
        case body
    }
}

struct Base64Data: Equatable, Codable {
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        guard let data = Data(base64Encoded: try container.decode(String.self))
            else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Data not found") }

        self.data = data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data.base64EncodedString())
    }
}
