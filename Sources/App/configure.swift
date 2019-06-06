import Bot
import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {

    let logger = PrintLogger()

    logger.log("👟 Starting up...")

    let gitHubService = GitHubService()

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router, logger: logger, gitHubService: gitHubService)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    // middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)

    logger.log("🏁 Ready")
}
