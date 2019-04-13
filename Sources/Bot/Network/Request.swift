import Foundation

public protocol RequestProtocol {
    func header(named name: String) -> String?
    func decodeBody<T>(_ type: T.Type) -> T? where T: Decodable
}
