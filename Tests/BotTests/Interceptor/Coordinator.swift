import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class RecordingContext {
    var destination: URL
    var recordedStubs: [Interceptor.Stub] = []
    var session: URLSession

    init(destination: URL) {
        self.destination = destination
        self.session = URLSession(configuration: {
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.urlCache = nil
            return config
        }())
    }
}

final class Coordinator {
    private var stubs: [Interceptor.Stub] = []
    private var recordingContext: RecordingContext? = nil

    var isRecordingAvailable: Bool = false

    var isRecording: Bool {
        guard isRecordingAvailable else { return false }

        return recordingContext != nil
    }

    deinit {
        Interceptor.stopRecording()
    }

    func load(stubs newStubs: [Interceptor.Stub]) {
        stubs.append(contentsOf: newStubs)
    }

    func loadOrRecordStubs(into url: URL) {

        if FileManager.default.fileExists(atPath: url.absoluteString) {

            guard
                let data = FileManager.default.contents(atPath: url.absoluteString),
                let loadedStubs = try? JSONDecoder().decode([Interceptor.Stub].self, from: data)
                else { fatalError("Failed to decode the existent stubs at `\(url)`") }

            stubs.append(contentsOf: loadedStubs)

        } else {
            recordingContext = RecordingContext(destination: url)
        }
    }

    func stopRecording() {
        guard let context = recordingContext else { return }

        guard
            let data = try? JSONEncoder().encode(context.recordedStubs),
            FileManager.default.createFile(atPath: context.destination.absoluteString, contents: data, attributes: nil)
            else { fatalError("Failed to record stubs at `\(context.destination)`") }

        recordingContext = nil

        fail("Record mode is on. Turn record mode off and re-run your test against the newly-recorded stub.")
    }

    func stub(for request: URLRequest) -> Interceptor.Stub? {
        guard stubs.isEmpty == false else { return nil }

        return stubs.remove(at: 0)
    }

    func record(request: URLRequest, completion: @escaping (Interceptor.Stub) -> Void) {
        guard let recordingContext = recordingContext
            else { fatalError("Trying to record a stub outside of a recording session") }

        recordingContext.session.dataTask(with: request) { data, response, error in

            guard
                let response = response as? HTTPURLResponse,
                let url = response.url,
                let headers  = response.allHeaderFields as? [String : String]
                else { fatalError() }

            let stub = Interceptor.Stub(
                response: Interceptor.Stub.Response(
                    url: url,
                    statusCode: response.statusCode,
                    headers: headers,
                    body: data
                )
            )

            recordingContext.recordedStubs.append(stub)

            completion(stub)
            
        }.resume()
    }
}

#if canImport(XCTest)
import XCTest
func fail(_ message: String, file: StaticString = #file, line: UInt = #line) {
    XCTFail(message)
}
#else
func fail(_ message: String, file: StaticString = #file, line: UInt = #line) {}
#endif
