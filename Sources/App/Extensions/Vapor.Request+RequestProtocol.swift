import Foundation
import Bot
import Vapor
import Result
import ReactiveSwift

extension Vapor.HTTPBody: HTTPBodyProtocol {}

extension Vapor.Request: RequestProtocol {

    public var body: HTTPBodyProtocol {
        return self.http.body
    }

    public func header(named name: String) -> String? {
        return http.headers[name].first
    }

    public func decodeBody<T>(
        _ type: T.Type,
        using scheduler: Scheduler
    ) -> SignalProducer<T, AnyError> where T: Decodable {
        return SignalProducer { [content] observer, disposable in
            guard disposable.hasEnded == false else { return }

            do {
                let value = try content.syncDecode(type)
                observer.send(value: value)
                observer.sendCompleted()
            } catch let error {
                observer.send(error: AnyError(error))
            }
        }.start(on: scheduler)
    }
}

