import Foundation

extension JSONDecoder {

    static func with(dateDecodingStrategy strategy: DateDecodingStrategy) -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = strategy
        return decoder
    }

    func decode<T: Decodable>(_ payload: Data) -> Result<T, Error> {
        return Result(catching: { () -> T in
            try decode(T.self, from: payload)
        })
    }
}
