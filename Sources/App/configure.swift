import Bot
import Vapor
import ReactiveSwift

enum ConfigurationError: Error {
    case missingConfiguration(message: String)
}

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {

    let logger = PrintLogger()
    let scheduler = EventLoopScheduler()

    _ = scheduler.schedule(after: scheduler.currentDate, interval: .seconds(20), leeway: .milliseconds(200)) {
        logger.log("Testing execution...")
    }
    
    let gitHubEventsService = GitHubEventsService(
        signatureToken: try Environment.gitHubWebhookSecret(),
        logger: logger,
        scheduler: scheduler
    )

    logger.log("👟 Starting up...")

    services.register(scheduler)
    services.register(try makeMergeService(with: logger, scheduler, gitHubEventsService))

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router, logger: logger, scheduler: scheduler, gitHubEventsService: gitHubEventsService)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    // middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)

    logger.log("🏁 Ready")
}

private func makeMergeService(with logger: LoggerProtocol, _ scheduler: DateScheduler, _ gitHubEventsService: GitHubEventsService) throws -> MergeService {

    let gitHubAPI = GitHubClient(session: URLSession(configuration: .default), token: try Environment.gitHubToken())
        .api(for: Repository(owner: try Environment.gitHubOrganization(), name: try Environment.gitHubRepository()))

    return MergeService(
        integrationLabel: try Environment.mergeLabel(),
        logger: logger,
        gitHubAPI: gitHubAPI,
        gitHubEvents: gitHubEventsService,
        scheduler: scheduler
    )
}

extension MergeService: Service {}
extension EventLoopScheduler: Service {}
