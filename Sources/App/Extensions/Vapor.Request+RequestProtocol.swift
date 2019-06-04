import Foundation
import Bot
import Vapor

extension Vapor.Request: RequestProtocol {
    public func header(named name: String) -> String? {
        return http.headers[name].first
    }

    public func decodeBody<T>(_ type: T.Type) -> T? where T: Decodable {
        return try? content.decode(type).wait()
    }
}

