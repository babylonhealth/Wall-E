import Foundation

private let coordinator = Coordinator()

final class Interceptor: URLProtocol {

    static var isRecordingAvailable: Bool {
        get { return coordinator.isRecordingAvailable }
        set { coordinator.isRecordingAvailable = newValue }
    }

    class func load(stubs newStubs: [Stub]) {
        coordinator.load(stubs: newStubs)
    }

    class func loadOrRecordStubs(into url: URL) {
        coordinator.loadOrRecordStubs(into: url)
    }

    class func stopRecording() {
        coordinator.stopRecording()
    }

    private func stub(for request: URLRequest) -> Stub? {
        return coordinator.stub(for: request)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if let availableStub = stub(for: request) {
            return send(response: availableStub.response)
        } else if coordinator.isRecording {
            coordinator.record(request: request) { stub in
                self.send(response: stub.response)
            }
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
