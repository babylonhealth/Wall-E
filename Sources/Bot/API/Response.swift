
// Based on https://github.com/mdiep/Tentacle

import Foundation

let linksRegex = try! NSRegularExpression(pattern: "(?<=\\A|,) *<([^>]+)>( *; *\\w+ *= *\"[^\"]+\")* *(?=\\z|,)")
let linkParamRegex = try! NSRegularExpression(pattern: "; *(\\w+) *= *\"([^\"]+)\"")

/// Returns any links, keyed by `rel`, from the RFC 5988 link header.
private func linksInLinkHeader(_ header: String) -> [String: URL] {
    var links: [String: URL] = [:]
    for match in linksRegex.matches(in: header, range: NSRange(header.startIndex..., in: header)) {
        let URI = String(header[Range(match.range(at: 1), in: header)!])
        let params = String(header[Range(match.range(at: 2), in: header)!])
        guard let url = URL(string: URI) else { continue }

        var relName: String? = nil
        for match in linkParamRegex.matches(in: params, range: NSRange(params.startIndex..., in: params)) {
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
    let statusCode: Int
    let headers: [String : String]
    let body: Data
    let containsReferenceForNextPage: Bool


    internal init(statusCode: Int, headers: [String : String], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.containsReferenceForNextPage = linksInLinkHeader(headers["Link"] as String? ?? "")["next"] != nil
    }
}
