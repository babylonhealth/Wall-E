import Foundation
import Result

func decode<T: Decodable>(_ response: Response) -> Result<T, GitHubClient.Error> {
    return decode(response) { JSONDecoder.iso8601Decoder.decode($0.body) }
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
