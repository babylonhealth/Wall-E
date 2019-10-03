import Foundation
import ReactiveSwift

public struct GitHubClient {
    private let session: URLSession

    private var baseURL: URL {
        return URL(string: "https://api.github.com")!
    }

    private var authorizationHeaders: () -> [String : String]

    public init(session: URLSession = .shared, token: String) {
        self.session = session
        self.authorizationHeaders = { token.isEmpty ? [:] : ["Authorization": "token \(token)"] }
    }

    func request<T>(_ resource: Resource<T>) -> SignalProducer<T, Error> {
        return request(urlRequest(for: resource))
            .attemptMap(resource.decoder)
    }

    func request<T>(_ resource: Resource<[T]>) -> SignalProducer<[T], Error> {

        func requestPage(for resource: Resource<[T]>, pageNumber: Int = 1) -> SignalProducer<[T], Error> {
            return request(urlRequest(for: resource, additionalQueryItems: queryItemsForPage(pageNumber)))
                .attemptMap { response -> Result<(Response, [T]), Error> in
                    return resource.decoder(response)
                        .map { (response, $0) }
                }
                .flatMap(.concat) { response, result -> SignalProducer<[T], Error> in
                    let current = SignalProducer<[T], Error>(value: result)

                    guard response.containsReferenceForNextPage
                        else { return current }

                    return current.concat(requestPage(for: resource, pageNumber: pageNumber + 1))
                }
        }

        return requestPage(for: resource)
    }

    private func request(_ request: URLRequest) -> SignalProducer<Response, Error> {
        return session
            .reactive
            .data(with: request)
            .mapError(GitHubClient.Error.network)
            .map { data, response -> Response in
                let response = response as! HTTPURLResponse
                let headers = response.allHeaderFields as! [String:String]
                return Response(statusCode: response.statusCode, headers: headers, body: data)
        }
    }

    private func urlRequest<Value>(
        for resource: Resource<Value>,
        additionalQueryItems: [URLQueryItem] = []
    ) -> URLRequest {

        let url = baseURL
            .appendingPathComponent(resource.path)
            .addingQueryItems(resource.queryItems)
            .addingQueryItems(additionalQueryItems)

        var request = URLRequest(url: url)

        request.httpMethod = resource.method.rawValue
        request.allHTTPHeaderFields = resource.headers.merging(authorizationHeaders(), uniquingKeysWith: { first, _ in first })
        request.httpBody = resource.body

        return request
    }
}

extension GitHubClient {
    public enum Error: Swift.Error {
        case network(Swift.Error)
        case api(Response)
        case decoding(Swift.Error)
    }
}

private func queryItemsForPage(_ page: Int, pageSize: Int = 100) -> [URLQueryItem] {
    return [
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "per_page", value: "\(pageSize)")
    ]
}
