import Bot
import Vapor

enum ConfigurationError: Error {
    case missingConfiguration(message: String)
}

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {

    let logger = PrintLogger()
    let gitHubEventsService = GitHubEventsService(signatureToken: try Environment.gitHubWebhookSecret())

    logger.log("👟 Starting up...")

    let mergeService = try makeMergeService(with: logger, gitHubEventsService)

    services.register(mergeService)
    services.register(logger, as: PrintLogger.self)
    services.register(RequestLoggerMiddleware.self)

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router, logger: logger, mergeService: mergeService, gitHubEventsService: gitHubEventsService)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    // middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    middlewares.use(RequestLoggerMiddleware.self)
    services.register(middlewares)

    logger.log("🏁 Ready")
}

private func makeMergeService(with logger: LoggerProtocol, _ gitHubEventsService: GitHubEventsService) throws -> MergeService {

    let gitHubAPI = GitHubClient(session: URLSession(configuration: .default), token: try Environment.gitHubToken())
        .api(for: Repository(owner: try Environment.gitHubOrganization(), name: try Environment.gitHubRepository()))

    return MergeService(
        integrationLabel: try Environment.mergeLabel(),
        topPriorityLabels: try Environment.topPriorityLabels(),
        requiresAllStatusChecks: try Environment.requiresAllGitHubStatusChecks(),
        statusChecksTimeout: try Environment.statusChecksTimeout() ?? 90.minutes,
        logger: logger,
        gitHubAPI: gitHubAPI,
        gitHubEvents: gitHubEventsService,
        extendedLogging: Environment.extendedLogging()
    )
}

extension MergeService: Service {}
