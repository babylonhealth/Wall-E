import Foundation
import ReactiveSwift
import Result

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

    private func request(_ request: URLRequest) -> SignalProducer<(Response, Data), Error> {
        return session
            .reactive
            .data(with: request)
            .mapError { .network($0.error) }
            .flatMap(.concat) { data, response -> SignalProducer<(Response, Data), Error> in
                let response = response as! HTTPURLResponse
                let headers = response.allHeaderFields as! [String:String]

                return SignalProducer { observer, disposable in
                    switch response.statusCode {
                    case 200...299:
                        observer.send(value: (Response(headerFields: headers), data))
                        observer.sendCompleted()
                    default:
                        observer.send(error: .api(response.statusCode, Response(headerFields: headers), data))
                    }
                }
            }
    }

    // TODO: Replace () by Never
    func request(_ resource: Resource<NoContent>) -> SignalProducer<(), Error> {
        return request(urlRequest(for: resource))
            .map { _ in }
    }

    func request<T: Decodable>(_ resource: Resource<T>) -> SignalProducer<T, Error> {
        return request(urlRequest(for: resource))
            .attemptMap { response, data -> Result<T, Error> in
                JSONDecoder.iso8601Decoder.decode(data)
                    .mapError(Error.decoding)
            }
    }

    func request<T: Decodable>(_ resource: Resource<[T]>) -> SignalProducer<[T], Error> {

        func requestPage(for resource: Resource<[T]>, pageNumber: Int = 1) -> SignalProducer<[T], Error> {
            return request(urlRequest(for: resource, additionalQueryItems: queryItemsForPage(pageNumber)))
                .attemptMap { response, data -> Result<(Response, [T]), Error> in
                    JSONDecoder.iso8601Decoder.decode(data)
                        .map { (response, $0) }
                        .mapError(Error.decoding)
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
    enum Error: Swift.Error {
        case network(Swift.Error)
        case api(Int, Response, Data)
        case decoding(DecodingError)
    }
}

private func queryItemsForPage(_ page: Int, pageSize: Int = 100) -> [URLQueryItem] {
    return [
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "per_page", value: "\(pageSize)")
    ]
}
