import Foundation

public struct GitHubUser: Identifiable, Equatable, Decodable {
    public let id: Int
    let login: String
    let name: String?
}
