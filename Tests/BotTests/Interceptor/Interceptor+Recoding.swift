import Foundation

final class RecordingContext {
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
