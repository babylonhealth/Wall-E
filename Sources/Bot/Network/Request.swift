import Foundation
import Result
import ReactiveSwift

public protocol RequestProtocol {
    func header(named name: String) -> String?
    func decodeBody<T>(
        _ type: T.Type,
        using scheduler: QueueScheduler
    ) -> SignalProducer<T, AnyError> where T: Decodable
}
