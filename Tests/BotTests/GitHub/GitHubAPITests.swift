import XCTest
import Nimble
@testable import Bot

class GitHubAPITests: XCTestCase {
    private var isRecoding = false

    var directory: URL {
        return URL(string: #file)!
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    func test_fetch_pull_requests() {

        perform(
            stub: Interceptor.loadOrRecordStubs(into: directory.appendingPathComponent("fetch_pull_requests.json"))
        ) { client in

            let api = RepositoryAPI(client: client, repository: .init(owner: "golang", name: "go"))

            let result = api.fetchPullRequests().first()?.value

            expect(result).toNot(beNil())
            expect(result?.count) == 125
            expect(result?.first) == PullRequest(
                number: 33277,
                title: "internal/fmtsort: restrict the for-range by len(key)",
                author: .init(login: "J-CIC"),
                source: .init(ref: "fix_fmtsort", sha: "57a206bf54e4242af1eae01b7b351f332c425c2f"),
                target: .init(ref: "master", sha: "919594830f17f25c9e971934d825615463ad8a10"),
                labels: [.init(name: "cla: yes")]
            )
        }
    }

    func test_fetch_pull_request_number() {

        perform(
            stub: Interceptor.loadOrRecordStubs(into: directory.appendingPathComponent("fetch_pull_request_number.json"))
        ) { client in

                let api = RepositoryAPI(client: client, repository: .init(owner: "golang", name: "go"))

                let result = api.fetchPullRequest(number: 33248).first()?.value

                expect(result).toNot(beNil())
                expect(result) == PullRequestMetadata(
                    reference: PullRequest(
                        number: 33248,
                        title: "runtime: fix gdb pretty print for slices",
                        author: .init(login: "elbeardmorez"),
                        source: .init(ref: "gdb_print_slice_fix", sha: "6e12bd85f5d71569cbfe574612210d3c925881b7"),
                        target: .init(ref: "master", sha: "e8c7e639ea6f4e2c66d8b17ca9283dba53667c9d"),
                        labels: [.init(name: "cla: yes")]
                    ),
                    isMerged: false,
                    mergeState: .clean
                )
        }
    }

    func test_fetch_commit_status() {
        perform(
            stub: Interceptor.loadOrRecordStubs(into: directory.appendingPathComponent("fetch_commit_status.json"))
        ) { client in

            let api = RepositoryAPI(client: client, repository: .init(owner: "golang", name: "go"))

            let target = PullRequest(
                number: 33248,
                title: "runtime: fix gdb pretty print for slices",
                author: .init(login: "elbeardmorez"),
                source: .init(ref: "gdb_print_slice_fix", sha: "6e12bd85f5d71569cbfe574612210d3c925881b7"),
                target: .init(ref: "master", sha: "e8c7e639ea6f4e2c66d8b17ca9283dba53667c9d"),
                labels: [.init(name: "cla: yes")]
            )

            let result = api.fetchCommitStatus(for: target).first()?.value

            expect(result).toNot(beNil())
            expect(result) == CommitState(
                state: .success,
                statuses: [
                    CommitState.Statuses(
                        state: .success,
                        description: "All necessary CLAs are signed",
                        context: "cla/google"
                    )
                ]
            )
        }
    }

    func test_delete_branch() {

        perform(stub:
            Interceptor.load(
                stubs: [
                    Interceptor.Stub(
                        response: Interceptor.Stub.Response(
                            url: URL(string: "https://api.github.com/repos/golang/go/git/refs/heads/gdb_print_slice_fix")!,
                            statusCode: 204,
                            body: Data()
                        )
                    )]
            )
        ) { client in

            let api = RepositoryAPI(client: client, repository: .init(owner: "golang", name: "go"))

            let target = PullRequest(
                number: 33248,
                title: "runtime: fix gdb pretty print for slices",
                author: .init(login: "elbeardmorez"),
                source: .init(ref: "gdb_print_slice_fix", sha: "6e12bd85f5d71569cbfe574612210d3c925881b7"),
                target: .init(ref: "master", sha: "e8c7e639ea6f4e2c66d8b17ca9283dba53667c9d"),
                labels: [.init(name: "cla: yes")]
            )

            let result: Void? = api.deleteBranch(named: target.source).first()?.value

            expect(result).toNot(beNil())
        }
    }

    private func perform(
        stub: @autoclosure () -> Void,
        execute: (GitHubClient) -> Void
    ) {

        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [Interceptor.self]

        let session = URLSession(configuration: configuration)

        let client = GitHubClient(session: session, token: "")

        stub()
        execute(client)
        
        Interceptor.stopRecording()
    }
}
