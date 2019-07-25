import XCTest
import Nimble
import Vinyl
@testable import Bot

class GitHubAPITests: XCTestCase {
    private var isRecoding = false

    func test_fetch_pull_requests() {

        perform(with: .vinylNamed("fetch_pull_requests")) { api in

            let result = api.fetchPullRequests().logEvents().first()?.value

            expect(result).toNot(beNil())
            expect(result?.count) == 124
            expect(result?.first) == PullRequest(
                number: 33248,
                title: "runtime: fix gdb pretty print for slices",
                author: .init(login: "elbeardmorez"),
                source: .init(ref: "gdb_print_slice_fix", sha: "6e12bd85f5d71569cbfe574612210d3c925881b7"),
                target: .init(ref: "master", sha: "e8c7e639ea6f4e2c66d8b17ca9283dba53667c9d"),
                labels: [.init(name: "cla: yes")]
            )
        }
    }

    func test_fetch_pull_request_number() {

        perform(with: .vinylNamed("fetch_pull_request_number")) { api in

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

        perform(with: .vinylNamed("fetch_commit_status")) { api in

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

        let vinyl = Vinyl(tracks: [
            TrackFactory.createTrack(
                url: URL(string: "https://api.github.com/repos/golang/go/git/refs/heads/gdb_print_slice_fix")!,
                statusCode: 204,
                body: Data(),
                error: nil,
                headers: [:]
            )]
        )

        perform(with: .preLoadedVinyl(vinyl)) { api in

            let target = PullRequest(
                number: 33248,
                title: "runtime: fix gdb pretty print for slices",
                author: .init(login: "elbeardmorez"),
                source: .init(ref: "gdb_print_slice_fix", sha: "6e12bd85f5d71569cbfe574612210d3c925881b7"),
                target: .init(ref: "master", sha: "e8c7e639ea6f4e2c66d8b17ca9283dba53667c9d"),
                labels: [.init(name: "cla: yes")]
            )

            let result: Void? = api.deleteBranch(named: target.source).logEvents().first()?.value

            expect(result).toNot(beNil())
        }
    }

    enum Strategy {
        case vinylNamed(String)
        case preLoadedVinyl(Vinyl)
    }

    private func perform(
        with strategy: Strategy,
        setup: (URLSession) -> RepositoryAPI = defaultRepositoryAPI(),
        execute: (RepositoryAPI) -> Void
    ) {

        let turntable: Turntable

        switch strategy {
        case let .vinylNamed(name):

            var directory: URL {
                return URL(string: #file)!
                    .deletingLastPathComponent()
                    .appendingPathComponent("Fixtures")
            }

            let recordingPath = directory.appendingPathComponent(name).appendingPathExtension("json").absoluteString

            turntable = Turntable(
                configuration: TurntableConfiguration(
                    matchingStrategy: .requestAttributes(types: [.url, .method], playTracksUniquely: true),
                    recordingMode: isRecoding ? .missingVinyl(recordingPath: recordingPath) : .none
                )
            )

            defer {
                if isRecoding {
                    turntable.stopRecording()
                }
            }

            turntable.load(vinyl: loadVinyl(from: recordingPath))

        case let .preLoadedVinyl(vinyl):

            turntable = Turntable(
                configuration: TurntableConfiguration(
                    // NOTE: We can't match the method due a limitation of Vinyl
                    matchingStrategy: .requestAttributes(types: [.url], playTracksUniquely: true),
                    recordingMode: .none
                )
            )

            turntable.load(vinyl: vinyl)
        }

        execute(setup(turntable))
    }

    private static func defaultRepositoryAPI() -> (URLSession) -> RepositoryAPI {
        return { session in
            return RepositoryAPI(
                client: GitHubClient(session: session, token: ""),
                repository: .init(owner: "golang", name: "go"))
        }
    }

    private func loadVinyl(from path: String) -> Vinyl {
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let plastic = try? JSONSerialization.jsonObject(with: data) as? Plastic
            else { return Vinyl(tracks: []) }

        return Vinyl(plastic: plastic ?? [])
    }
}
