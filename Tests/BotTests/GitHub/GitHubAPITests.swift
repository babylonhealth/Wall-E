import XCTest
import Nimble
@testable import Bot

class GitHubAPITests: XCTestCase {

    var directory: URL {
        return URL(string: #file)!
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    var target: PullRequest {
        return PullRequest(
            number: 33248,
            title: "runtime: fix gdb pretty print for slices",
            author: .init(login: "elbeardmorez"),
            source: .init(ref: "gdb_print_slice_fix", sha: "6e12bd85f5d71569cbfe574612210d3c925881b7"),
            target: .init(ref: "master", sha: "e8c7e639ea6f4e2c66d8b17ca9283dba53667c9d"),
            labels: [.init(name: "cla: yes")]
        )
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

            let result = api.fetchCommitStatus(for: target).first()?.value

            expect(result).toNot(beNil())
            expect(result) == CommitState(
                state: .success,
                statuses: [
                    CommitState.Status(
                        state: .success,
                        description: "All necessary CLAs are signed",
                        context: "cla/google"
                    )
                ]
            )
        }
    }

    func test_fetch_required_status_checks() {
        perform(stub:
            Interceptor.load(
                stubs: [
                    Interceptor.Stub(
                        response: Interceptor.Stub.Response(
                            url: URL(string: "https://api.github.com/repos/babylonhealth/babylon-ios/branches/develop/protection/required_status_checks")!,
                            statusCode: 200,
                            body: GitHubRequiredStatusChecks.data(using: .utf8)!
                        )
                    )]
            )
        ) { client in

            let api = RepositoryAPI(client: client, repository: .init(owner: "golang", name: "go"))

            let result = api.fetchRequiredStatusChecks(for: target.target).first()?.value

            expect(result).toNot(beNil())
            expect(result) == RequiredStatusChecks(
                strict: true,
                contexts: [
                    "ci/circleci: Build: SDK",
                    "ci/circleci: UnitTests: Ascension",
                    "ci/circleci: UnitTests: BabylonKSA",
                    "ci/circleci: UnitTests: BabylonUS",
                    "ci/circleci: UnitTests: Telus",
                    "ci/circleci: SnapshotTests: BabylonChatBotUI",
                    "ci/circleci: SnapshotTests: BabylonUI",
                    "ci/circleci: SnapshotTests: Babylon"
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

            let result: Void? = api.deleteBranch(named: target.source).first()?.value

            expect(result).toNot(beNil())
        }
    }

    func test_remove_label() {

        perform(stub:
            Interceptor.load(
                stubs: [
                    Interceptor.Stub(
                        response: Interceptor.Stub.Response(
                            url: URL(string: "https://api.github.com/repos/golang/go/issues/33248/labels/cla:%20yes")!,
                            statusCode: 200,
                            body: Data()
                        )
                    )]
            )
        ) { client in

            let api = RepositoryAPI(client: client, repository: .init(owner: "golang", name: "go"))

            let result: Void? = api.removeLabel(target.labels.first!, from: target).first()?.value

            expect(result).toNot(beNil())
        }
    }

    func test_publish_comment() {

        perform(stub:
            Interceptor.load(
                stubs: [
                    Interceptor.Stub(
                        response: Interceptor.Stub.Response(
                            url: URL(string: "https://api.github.com/repos/golang/go/issues/33248/comments")!,
                            statusCode: 201,
                            body: Data()
                        )
                    )]
            )
        ) { client in

            let api = RepositoryAPI(client: client, repository: .init(owner: "golang", name: "go"))

            let result: Void? = api.postComment("Hello World", in: target).first()?.value

            expect(result).toNot(beNil())
        }
    }

    func test_merge_branch_with_success() {

        perform(stub:
            Interceptor.load(
                stubs: [
                    Interceptor.Stub(
                        response: Interceptor.Stub.Response(
                            url: URL(string: "https://api.github.com/repos/golang/go/merges")!,
                            statusCode: 201,
                            body: Data()
                        )
                    )]
            )
        ) { client in

            let api = RepositoryAPI(client: client, repository: .init(owner: "golang", name: "go"))

            let result = api.merge(
                head: PullRequest.Branch(ref: "develop", sha: "5678"),
                into: PullRequest.Branch(ref: "master", sha: "1234")
                ).first()?.value

            expect(result) == .success
        }
    }

    func test_merge_branch_up_to_date() {

        perform(stub:
            Interceptor.load(
                stubs: [
                    Interceptor.Stub(
                        response: Interceptor.Stub.Response(
                            url: URL(string: "https://api.github.com/repos/golang/go/merges")!,
                            statusCode: 204,
                            body: Data()
                        )
                    )]
            )
        ) { client in

            let api = RepositoryAPI(client: client, repository: .init(owner: "golang", name: "go"))

            let result = api.merge(
                head: PullRequest.Branch(ref: "develop", sha: "5678"),
                into: PullRequest.Branch(ref: "master", sha: "1234")
                ).first()?.value

            expect(result) == .upToDate
        }
    }

    func test_merge_pull_request_with_conflicts() {

        perform(stub:
            Interceptor.load(
                stubs: [
                    Interceptor.Stub(
                        response: Interceptor.Stub.Response(
                            url: URL(string: "https://api.github.com/repos/golang/go/merges")!,
                            statusCode: 409,
                            body: Data()
                        )
                    )]
            )
        ) { client in

            let api = RepositoryAPI(client: client, repository: .init(owner: "golang", name: "go"))

            let result = api.merge(
                head: PullRequest.Branch(ref: "develop", sha: "5678"),
                into: PullRequest.Branch(ref: "master", sha: "1234")
                ).first()?.value

            expect(result) == .conflict
        }
    }

    func test_merge_pull_request() {

        perform(stub:
            Interceptor.load(
                stubs: [
                    Interceptor.Stub(
                        response: Interceptor.Stub.Response(
                            url: URL(string: "https://api.github.com/repos/golang/go/pulls/123/merge")!,
                            statusCode: 200,
                            body: Data()
                        )
                    )]
            )
        ) { client in

            let api = RepositoryAPI(client: client, repository: .init(owner: "golang", name: "go"))

            let result: Void? = api.mergePullRequest(target).first()?.value

            expect(result).toNot(beNil())
        }
    }

    // TODO: [CNSMR-2525] Add test for failure cases

    // MARK: - Template

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
