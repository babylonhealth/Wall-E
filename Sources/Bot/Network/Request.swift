import Foundation
import ReactiveSwift

public protocol HTTPBodyProtocol {
    var data: Data? { get }
}

public protocol RequestProtocol {
    var body: HTTPBodyProtocol { get }

    func header(named name: String) -> String?
    func decodeBody<T>(
        _ type: T.Type,
        using scheduler: Scheduler
    ) -> SignalProducer<T, Error> where T: Decodable
}
