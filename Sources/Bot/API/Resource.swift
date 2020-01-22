import Foundation

internal struct Resource<T> {
    typealias Decoder = (Response) -> Result<T, GitHubClient.Error>

    internal var method: Method
    internal var path: String
    internal var queryItems: [URLQueryItem]
    internal var headers: [String: String]
    internal var body: Data?
    internal let decoder: Decoder

    internal init(
        method: Method,
        path: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        decoder: @escaping Decoder
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.decoder = decoder
    }
}

extension Resource {
    internal enum Method: String {
        case GET
        case POST
        case PUT
        case DELETE
        case HEAD
        case PATCH
        case OPTIONS
    }
}
