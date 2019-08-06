import Foundation
import Result

extension JSONDecoder {

    static func with(dateDecodingStrategy strategy: DateDecodingStrategy) -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = strategy
        return decoder
    }

    func decode<T: Decodable>(_ payload: Data) -> Result<T, DecodingError> {
        return Result(catching: { () -> T in
            try decode(T.self, from: payload)
        })
    }
}
