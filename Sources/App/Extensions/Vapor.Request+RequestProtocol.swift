import Foundation
import Bot
import Vapor
import Result
import ReactiveSwift

extension Vapor.HTTPBody: HTTPBodyProtocol {}

extension Vapor.Request: RequestProtocol {

    public var body: HTTPBodyProtocol {
        return self.http.body
    }

    public func header(named name: String) -> String? {
        return http.headers[name].first
    }

    public func decodeBody<T>(_ type: T.Type) -> Result<T, AnyError> where T: Decodable {
        return Result(catching: { try content.syncDecode(type) })
    }
}

