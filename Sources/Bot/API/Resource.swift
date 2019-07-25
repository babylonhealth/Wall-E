import Foundation

internal struct Resource<T: Decodable>: Hashable {
    internal var method: Method
    internal var path: String
    internal var queryItems: [URLQueryItem]
    internal var headers: [String: String]
    internal var body: Data?

    internal init(
        method: Method,
        path: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
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
