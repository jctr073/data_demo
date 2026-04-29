import Foundation
import PostgresNIO

struct DataNodeRepository: Sendable {
    let configuration: DatabaseConfiguration

    func loadNodes() async throws -> [DataNode] {
        let client = PostgresClient(configuration: postgresConfiguration)
        let clientTask = Task {
            await client.run()
        }
        defer {
            clientTask.cancel()
        }

        var categoryNodes: [DataNode] = []
        let categories = try await loadCategories(using: client)

        for category in categories {
            let films = try await loadFilms(categoryID: category.id, using: client)
            var filmNodes: [DataNode] = []

            for film in films {
                let actors = try await loadActors(filmID: film.id, using: client)
                let actorNodes = actors.map { actor in
                    DataNode(
                        id: actor.id,
                        title: actor.fullName.displayCapitalized,
                        source: "actor",
                        systemImage: "person.2",
                        children: nil
                    )
                }

                filmNodes.append(
                    DataNode(
                        id: film.id,
                        title: film.title.displayCapitalized,
                        source: "film",
                        systemImage: "film",
                        children: actorNodes.isEmpty ? nil : actorNodes
                    )
                )
            }

            categoryNodes.append(
                DataNode(
                    id: category.id,
                    title: category.name,
                    source: "category",
                    systemImage: "folder",
                    children: filmNodes.isEmpty ? nil : filmNodes
                )
            )
        }

        return categoryNodes
    }

    private var postgresConfiguration: PostgresClient.Configuration {
        var options = PostgresClient.Configuration.Options()
        options.maximumConnections = 4

        var clientConfiguration = PostgresClient.Configuration(
            host: configuration.host,
            port: configuration.port,
            username: configuration.username ?? NSUserName(),
            password: configuration.password,
            database: configuration.database.isEmpty ? nil : configuration.database,
            tls: .disable
        )
        clientConfiguration.options = options
        return clientConfiguration
    }

    private func loadCategories(using client: PostgresClient) async throws -> [CategoryRecord] {
        let rows = try await client.query("""
            select c.category_id, c.name
            from category c
            order by c.name
            """)

        var categories: [CategoryRecord] = []
        for try await (categoryID, name) in rows.decode((Int, String).self) {
            categories.append(CategoryRecord(id: categoryID, name: name))
        }
        return categories
    }

    private func loadFilms(categoryID: Int, using client: PostgresClient) async throws -> [FilmRecord] {
        let rows = try await client.query("""
            select f.film_id, f.title
            from film_category fc join film f on fc.film_id = f.film_id
            where fc.category_id = \(categoryID)
            order by f.title
            """)

        var films: [FilmRecord] = []
        for try await (filmID, title) in rows.decode((Int, String).self) {
            films.append(FilmRecord(id: filmID, title: title))
        }
        return films
    }

    private func loadActors(filmID: Int, using client: PostgresClient) async throws -> [ActorRecord] {
        let rows = try await client.query("""
            select a.actor_id, a.first_name, a.last_name
            from film_actor fa join actor a on fa.actor_id = a.actor_id
            where fa.film_id = \(filmID)
            order by a.last_name, a.first_name
            """)

        var actors: [ActorRecord] = []
        for try await (actorID, firstName, lastName) in rows.decode((Int, String, String).self) {
            actors.append(
                ActorRecord(
                    id: actorID,
                    firstName: firstName,
                    lastName: lastName
                )
            )
        }
        return actors
    }
}

private struct CategoryRecord: Sendable {
    let id: Int
    let name: String
}

private struct FilmRecord: Sendable {
    let id: Int
    let title: String
}

private struct ActorRecord: Sendable {
    let id: Int
    let firstName: String
    let lastName: String

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

private extension String {
    var displayCapitalized: String {
        lowercased().capitalized
    }
}
