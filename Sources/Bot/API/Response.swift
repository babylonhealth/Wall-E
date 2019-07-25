
// Copied from https://github.com/mdiep/Tentacle

import Foundation

let LinksRegex = try! NSRegularExpression(pattern: "(?<=\\A|,) *<([^>]+)>( *; *\\w+ *= *\"[^\"]+\")* *(?=\\z|,)")
let LinkParamRegex = try! NSRegularExpression(pattern: "; *(\\w+) *= *\"([^\"]+)\"")

/// Returns any links, keyed by `rel`, from the RFC 5988 link header.
private func linksInLinkHeader(_ header: String) -> [String: URL] {
    var links: [String: URL] = [:]
    for match in LinksRegex.matches(in: header, range: NSRange(header.startIndex..., in: header)) {
        let URI = String(header[Range(match.range(at: 1), in: header)!])
        let params = String(header[Range(match.range(at: 2), in: header)!])
        guard let url = URL(string: URI) else { continue }

        var relName: String? = nil
        for match in LinkParamRegex.matches(in: params, range: NSRange(params.startIndex..., in: params)) {
            let name = params[Range(match.range(at: 1), in: params)!]
            if name != "rel" { continue }

            relName = String(params[Range(match.range(at: 2), in: params)!])
        }

        if let relName = relName {
            links[relName] = url
        }
    }
    return links
}

/// A response from the GitHub API.
internal struct Response: Hashable {
    /// The number of requests remaining in the current rate limit window, or nil if the server
    /// isn't rate-limited.
    public let rateLimitRemaining: UInt?

    /// The time at which the current rate limit window resets, or nil if the server isn't
    /// rate-limited.
    public let rateLimitReset: Date?

    /// Any links that are included in the response.
    public let links: [String: URL]

    public init(rateLimitRemaining: UInt, rateLimitReset: Date, links: [String: URL]) {
        self.rateLimitRemaining = rateLimitRemaining
        self.rateLimitReset = rateLimitReset
        self.links = links
    }

    /// Initialize a response with HTTP header fields.
    internal init(headerFields: [String : String]) {
        self.rateLimitRemaining = headerFields["X-RateLimit-Remaining"].flatMap { UInt($0) }
        self.rateLimitReset = headerFields["X-RateLimit-Reset"]
            .flatMap { TimeInterval($0) }
            .map { Date(timeIntervalSince1970: $0) }
        self.links = linksInLinkHeader(headerFields["Link"] as String? ?? "")
    }
}

extension Response {

    var containsReferenceForNextPage: Bool {
        return links["next"] != nil
    }
}
