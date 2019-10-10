import XCTest
import Nimble
import ReactiveSwift
import Result
@testable import Bot

class MergeServiceHealthcheckTests: XCTestCase {

    private let statusChecksTimeout = 30.minutes

    func test_healthcheck_passing() {

        perform(
            when: { input, scheduler in
                scheduler.advance()

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .starting))

                scheduler.advance()

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .idle))

                scheduler.advance()

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .ready))

                scheduler.advance()

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .integrating(defaultTarget)))

                scheduler.advance()

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .ready))

                scheduler.advance()

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .idle))

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

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .starting))

                scheduler.advance()

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .idle))

                scheduler.advance()

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .ready))

                scheduler.advance()

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .runningStatusChecks(defaultTarget)))

                scheduler.advance(by: .minutes(2 * defaultStatusChecksTimeout))

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .integrationFailed(defaultTarget, .checksFailing)))

                scheduler.advance()

                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .ready))
                input.send(value: .init(integrationLabel: .init(name: "Merge"), statusChecksTimeout: statusChecksTimeout, pullRequests: [], status: .idle))

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
