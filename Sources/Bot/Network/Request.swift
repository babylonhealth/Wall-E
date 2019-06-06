import Foundation
import Result
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
    ) -> SignalProducer<T, AnyError> where T: Decodable
}
