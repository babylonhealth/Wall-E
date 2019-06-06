import Bot
import Vapor

enum ConfigurationError: Error {
    case missingConfiguration(message: String)
}

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {

    guard let githubWebhookSecret = Environment.githubWebhookSecret
        else { throw ConfigurationError.missingConfiguration(message: "💥 GitHub Webhook Secret is missing")}

    let gitHubService = GitHubService(signatureToken: githubWebhookSecret)

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router, gitHubService: gitHubService)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    // middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)
}
