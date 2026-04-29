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
        let environment = loadEnvironmentIfPresent(
            at: envSearchPaths(fileManager: fileManager),
            fileManager: fileManager
        )
        let databaseURL = environmentValue("DATABASE_URL", processInfo: processInfo) ?? fallbackDatabaseURL

        return AppConfiguration(
            database: DatabaseConfiguration(databaseURL: databaseURL),
            environment: environment
        )
    }

    private static func loadEnvironmentIfPresent(
        at paths: [String],
        fileManager: FileManager
    ) -> EnvironmentStatus {
        guard let path = paths.first(where: { fileManager.fileExists(atPath: $0) }) else {
            return .missing(paths: paths)
        }

        do {
            try DotEnv.load(path: path)
            return .loaded(path: path)
        } catch {
            return .failed(path: path, message: error.localizedDescription)
        }
    }

    private static func envSearchPaths(fileManager: FileManager) -> [String] {
        var paths: [String] = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(".env")
                .path
        ]

        if let resourceURL = Bundle.main.resourceURL {
            paths.append(resourceURL.appendingPathComponent(".env").path)
        }

        if let executableURL = Bundle.main.executableURL {
            paths.append(
                executableURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(".env")
                    .path
            )
        }

        var seenPaths = Set<String>()
        return paths.filter { seenPaths.insert($0).inserted }
    }

    private static func environmentValue(_ key: String, processInfo: ProcessInfo) -> String? {
        if let value = processInfo.environment[key], !value.isEmpty {
            return value
        }

        guard let cValue = getenv(key) else {
            return nil
        }

        let value = String(cString: cValue)
        return value.isEmpty ? nil : value
    }
}

enum EnvironmentStatus {
    case loaded(path: String)
    case missing(paths: [String])
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
