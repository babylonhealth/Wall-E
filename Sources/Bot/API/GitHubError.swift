
// Copied from https://github.com/mdiep/Tentacle

public struct GitHubError: CustomStringConvertible, Error, Decodable {
    /// The error message from the API.
    public let message: String

    public var description: String {
        return message
    }

    public init(message: String) {
        self.message = message
    }
}
