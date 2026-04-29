import DotEnv
import Foundation

struct AppConfiguration {
    static let fallbackDatabaseURL = "postgresql://localhost:5432/pagila"

    let database: DatabaseConfiguration
    let environment: EnvironmentStatus

    static func load(
        fileManager: FileManager = .default,
        processInfo: ProcessInfo = .processInfo
    ) -> AppConfiguration {
        let envPath = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent(".env")
            .path
        let environment = loadEnvironmentIfPresent(at: envPath, fileManager: fileManager)
        let databaseURL = processInfo.environment["DATABASE_URL"] ?? fallbackDatabaseURL

        return AppConfiguration(
            database: DatabaseConfiguration(databaseURL: databaseURL),
            environment: environment
        )
    }

    private static func loadEnvironmentIfPresent(
        at path: String,
        fileManager: FileManager
    ) -> EnvironmentStatus {
        guard fileManager.fileExists(atPath: path) else {
            return .missing(path: path)
        }

        do {
            try DotEnv.load(path: path)
            return .loaded(path: path)
        } catch {
            return .failed(path: path, message: error.localizedDescription)
        }
    }
}

enum EnvironmentStatus {
    case loaded(path: String)
    case missing(path: String)
    case failed(path: String, message: String)

    var displayText: String {
        switch self {
        case .loaded:
            "Loaded .env"
        case .missing:
            "DATABASE_URL missing"
        case .failed(_, let message):
            "Env load issue: \(message)"
        }
    }
}

struct DatabaseConfiguration {
    let rawURL: String
    let scheme: String
    let host: String
    let port: Int
    let database: String
    let username: String?
    let password: String?
    let isFallback: Bool

    init(databaseURL: String) {
        self.rawURL = databaseURL
        self.isFallback = databaseURL == AppConfiguration.fallbackDatabaseURL

        guard let components = URLComponents(string: databaseURL) else {
            self.scheme = "postgresql"
            self.host = "localhost"
            self.port = 5432
            self.database = "pagila"
            self.username = nil
            self.password = nil
            return
        }

        self.scheme = components.scheme ?? "postgresql"
        self.host = components.host ?? "localhost"
        self.port = components.port ?? 5432
        self.database = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.username = components.user
        self.password = components.password
    }
}
