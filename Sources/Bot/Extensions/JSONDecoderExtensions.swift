import Foundation
import Result

private let iso8601: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier:"en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    formatter.timeZone = TimeZone(abbreviation:"UTC")
    return formatter
}()

extension JSONDecoder {

    static var iso8601Decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(iso8601)
        return decoder
    }

    func decode<T: Decodable>(_ payload: Data) -> Result<T, DecodingError> {
        return Result(catching: { () -> T in
            try decode(T.self, from: payload)
        })
    }
}
