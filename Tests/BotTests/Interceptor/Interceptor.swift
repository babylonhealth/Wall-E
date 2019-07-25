import Foundation

final class Coordinator {
    fileprivate var stubs: [Interceptor.Stub] = []
    fileprivate var recordingContext: RecordingContext? = nil

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
    }

    deinit {
        Interceptor.stopRecording()
    }
}

private let coordinator = Coordinator()

final class Interceptor: URLProtocol {

    class func load(stubs newStubs: [Stub]) {
        coordinator.stubs.append(contentsOf: newStubs)
    }

    class func loadOrRecordStubs(into url: URL) {
        coordinator.loadOrRecordStubs(into: url)
    }

    class func stopRecording() {
        coordinator.stopRecording()
    }

    private func stub(for request: URLRequest) -> Stub? {
        guard coordinator.stubs.isEmpty == false else { return nil }

        return coordinator.stubs.remove(at: 0)
    }

    override open class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override open class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if let availableStub = stub(for: request) {
            return send(response: availableStub.response)
        } else if let recordingContext = coordinator.recordingContext {
            recordingContext.session.dataTask(with: request) { data, response, error in

                guard
                    let response = response as? HTTPURLResponse,
                    let url = response.url,
                    let headers  = response.allHeaderFields as? [String : String]
                    else { fatalError() }

                let stub = Stub(
                    response: Stub.Response(url: url, statusCode: response.statusCode, headers: headers, body: data)
                )

                recordingContext.recordedStubs.append(stub)

                self.send(response: stub.response)

            }.resume()
        } else {
            fatalError("No stub found for \(request) and recording is not enabled")
        }
    }

    override func stopLoading() {}

    private func send(response: Stub.Response) {
        client?.urlProtocol(self, didReceive: response.urlResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body?.data ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }
}
