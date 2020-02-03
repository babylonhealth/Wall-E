import Bot
import Vapor
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum ConfigurationError: Error {
    case missingConfiguration(message: String)
}

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {

    let logger = LogzIOLogger()
    let gitHubEventsService = GitHubEventsService(signatureToken: try Environment.gitHubWebhookSecret())

    logger.info("👟 Starting up...")

    let dispatchService = try makeDispatchService(logger: logger, gitHubEventsService: gitHubEventsService)

    services.register(dispatchService)
    services.register(logger, as: Logger.self)
    services.register(RequestLoggerMiddleware.self)

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router, logger: logger, dispatchService: dispatchService, gitHubEventsService: gitHubEventsService)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    // middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    middlewares.use(RequestLoggerMiddleware.self)
    services.register(middlewares)

    logger.info("🏁 Ready")
}

private func makeDispatchService(logger: Logger, gitHubEventsService: GitHubEventsService) throws -> DispatchService {

    let gitHubAPI = GitHubClient(session: URLSession(configuration: .default), token: try Environment.gitHubToken())
        .api(for: Repository(owner: try Environment.gitHubOrganization(), name: try Environment.gitHubRepository()))

    return DispatchService(
        integrationLabel: try Environment.mergeLabel(),
        topPriorityLabels: try Environment.topPriorityLabels(),
        requiresAllStatusChecks: try Environment.requiresAllGitHubStatusChecks(),
        statusChecksTimeout: Environment.statusChecksTimeout() ?? 90.minutes,
        idleMergeServiceCleanupDelay: Environment.idleMergeServiceCleanupDelay() ?? 5.minutes,
        logger: logger,
        gitHubAPI: gitHubAPI,
        gitHubEvents: gitHubEventsService
    )
}

extension DispatchService: Service {}
