import Foundation
import ReactiveSwift
import NIO

final class EventLoopScheduler: DateScheduler {
    private let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)

    var currentDate: Date {
        return Date()
    }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }

    func schedule(_ action: @escaping () -> Void) -> Disposable? {
        let disposable = AnyDisposable()

        eventLoopGroup.next()
            .execute {
                if disposable.isDisposed == false {
                    action()
                }
            }

        return disposable
    }

    func schedule(after date: Date, action: @escaping () -> Void) -> Disposable? {
        let disposable = AnyDisposable()

        eventLoopGroup.next()
            .scheduleTask(in: date.timeIntervalSince(currentDate).timeAmount) {
                if disposable.isDisposed == false {
                    action()
                }
            }

        return disposable
    }

    func schedule(
        after date: Date,
        interval: DispatchTimeInterval,
        leeway: DispatchTimeInterval,
        action: @escaping () -> Void
    ) -> Disposable? {
        let disposable = AnyDisposable()

        let delay = interval.timeInterval + leeway.timeInterval

        eventLoopGroup.next()
            .scheduleRepeatedTask(
                initialDelay: date.timeIntervalSince(currentDate).timeAmount,
                delay: delay.timeAmount
            ) { task -> Void in
                if disposable.isDisposed {
                    task.cancel()
                } else {
                    action()
                }
            }

        return disposable
    }
}

extension TimeInterval {

    var timeAmount: TimeAmount {
        return TimeAmount.seconds(TimeAmount.Value(self))
    }
}

// Reference: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Sources/FoundationExtensions.swift

#if os(Linux)
import let CDispatch.NSEC_PER_USEC
import let CDispatch.NSEC_PER_SEC
#endif

extension DispatchTimeInterval {
    internal var timeInterval: TimeInterval {
        switch self {
        case let .seconds(s):
            return TimeInterval(s)
        case let .milliseconds(ms):
            return TimeInterval(TimeInterval(ms) / 1000.0)
        case let .microseconds(us):
            return TimeInterval(Int64(us)) * TimeInterval(NSEC_PER_USEC) / TimeInterval(NSEC_PER_SEC)
        case let .nanoseconds(ns):
            return TimeInterval(ns) / TimeInterval(NSEC_PER_SEC)
        case .never:
            return .infinity
        }
    }
}
