import XCTest
import Nimble
import ReactiveSwift
import Result
@testable import Bot

class MergeServiceHealthcheckTests: XCTestCase {

    private let statusChecksTimeout = 30.minutes

    private func makeState(status: MergeService.State.Status) -> MergeService.State {
        return .init(
            integrationLabel: .init(name: "Merge"),
            topPriorityLabels: [.init(name: "TP"), .init(name: "HotFix")],
            statusChecksTimeout: statusChecksTimeout,
            pullRequests: [],
            status: .starting
        )
    }

    func test_healthcheck_passing() {

        perform(
            when: { input, scheduler in
                scheduler.advance()

                input.send(value: makeState(status: .starting))

                scheduler.advance()

                input.send(value: makeState(status: .idle))

                scheduler.advance()

                input.send(value: makeState(status: .ready))

                scheduler.advance()

                input.send(value: makeState(status: .integrating(defaultTarget)))

                scheduler.advance()

                input.send(value: makeState(status: .ready))

                scheduler.advance()

                input.send(value: makeState(status: .idle))

                scheduler.advance()
            },
            assert: { statuses in
                expect(statuses) == [.ok, .ok, .ok]
            }
        )
    }

    func test_healthcheck_failing() {

        perform(
            when: { input, scheduler in

                scheduler.advance()

                input.send(value: makeState(status: .starting))

                scheduler.advance()

                input.send(value: makeState(status: .idle))

                scheduler.advance()

                input.send(value: makeState(status: .ready))

                scheduler.advance()

                input.send(value: makeState(status: .runningStatusChecks(defaultTarget)))

                scheduler.advance(by: .minutes(2 * defaultStatusChecksTimeout))

                input.send(value: makeState(status: .integrationFailed(defaultTarget, .checksFailing)))

                scheduler.advance()

                input.send(value: makeState(status: .ready))
                input.send(value: makeState(status: .idle))

                scheduler.advance()

            },
            assert: { statuses in
                expect(statuses) == [.ok, .ok, .unhealthy(.potentialDeadlock), .ok]
            }
        )
    }

    private func perform(
        when: (Signal<MergeService.State, NoError>.Observer, TestScheduler) -> Void,
        assert: ([MergeService.Healthcheck.Status]) -> Void
    ) {
        let state = Signal<MergeService.State, NoError>.pipe()
        let scheduler = TestScheduler()

        var statuses: [MergeService.Healthcheck.Status] = []

        let healthcheck = MergeService.Healthcheck(
            state: state.output,
            statusChecksTimeout: statusChecksTimeout,
            scheduler: scheduler
        )

        healthcheck.status.producer.startWithValues { status in
            statuses.append(status)
        }

        when(state.input, scheduler)
        assert(statuses)
    }
}
