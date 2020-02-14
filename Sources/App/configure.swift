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

    let logger = PrintLogger()
    let gitHubEventsService = GitHubEventsService(signatureToken: try Environment.gitHubWebhookSecret())

    logger.log("👟 Starting up...")

    let dispatchService = try makeDispatchService(with: logger, gitHubEventsService)

    services.register(dispatchService)
    services.register(logger, as: PrintLogger.self)
    #if LOG_FULL_NETWORK_REQUESTS
    services.register(RequestLoggerMiddleware.self)
    #endif

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router, logger: logger, dispatchService: dispatchService, gitHubEventsService: gitHubEventsService)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    #if LOG_FULL_NETWORK_REQUESTS
    middlewares.use(RequestLoggerMiddleware.self)
    #endif
    services.register(middlewares)

    logger.log("🏁 Ready")
}

private func makeDispatchService(with logger: LoggerProtocol, _ gitHubEventsService: GitHubEventsService) throws -> DispatchService {

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
