import Foundation
import Result

private let iso8601: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier:"en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    formatter.timeZone = TimeZone(abbreviation:"UTC")
    return formatter
}()

func decode<T: Decodable>(_ response: Response) -> Result<T, GitHubClient.Error> {
    return decode(response) {
        JSONDecoder
            .with(dateDecodingStrategy: .formatted(iso8601))
            .decode($0.body)
    }
}

func decode(_ response: Response) -> Result<Void, GitHubClient.Error> {
    return decode(response) { _ in .success(()) }
}

private func decode<T>(
    _ response: Response,
    with handler: (Response) -> Result<T, DecodingError>
) -> Result<T, GitHubClient.Error> {
    switch response.statusCode {
    case 200...299:
        return handler(response)
            .mapError(GitHubClient.Error.decoding)
    default:
        return .failure(.api(response))
    }
}
