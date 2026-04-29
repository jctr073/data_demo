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

    func loadFilmDetails(filmID: Int) async throws -> FilmDetails {
        let client = PostgresClient(configuration: postgresConfiguration)
        let clientTask = Task {
            await client.run()
        }
        defer {
            clientTask.cancel()
        }

        let rows = try await client.query("""
            select
                f.film_id,
                f.title,
                coalesce(f.description, ''),
                coalesce(f.release_year::text, ''),
                f.language_id,
                l.name,
                f.original_language_id,
                coalesce(ol.name, ''),
                f.rental_duration::text,
                f.rental_rate::text,
                coalesce(f.length::text, ''),
                f.replacement_cost::text,
                f.rating::text,
                f.last_update::text,
                coalesce(array_to_string(f.special_features, ', '), ''),
                f.fulltext::text
            from film f
            join language l on l.language_id = f.language_id
            left join language ol on ol.language_id = f.original_language_id
            where f.film_id = \(filmID)
            """)

        for try await row in rows.decode((
            Int,
            String,
            String,
            String,
            Int,
            String,
            Int?,
            String,
            String,
            String,
            String,
            String,
            String,
            String,
            String,
            String
        ).self) {
            return FilmDetails(
                filmID: row.0,
                title: row.1,
                description: row.2,
                releaseYear: row.3,
                languageID: row.4,
                language: row.5,
                originalLanguageID: row.6,
                originalLanguage: row.7,
                rentalDuration: row.8,
                rentalRate: row.9,
                length: row.10,
                replacementCost: row.11,
                rating: row.12,
                lastUpdate: row.13,
                specialFeatures: row.14,
                fulltext: row.15
            )
        }

        throw DataNodeRepositoryError.filmNotFound(filmID)
    }

    func loadLanguageOptions() async throws -> [LanguageOption] {
        let client = PostgresClient(configuration: postgresConfiguration)
        let clientTask = Task {
            await client.run()
        }
        defer {
            clientTask.cancel()
        }

        let rows = try await client.query("""
            select l.language_id, l.name
            from language l
            order by l.name
            """)

        var languages: [LanguageOption] = []
        for try await (languageID, name) in rows.decode((Int, String).self) {
            languages.append(LanguageOption(id: languageID, name: name))
        }
        return languages
    }

    func saveFilmDetails(_ draft: FilmDetailsDraft) async throws -> FilmDetails {
        let client = PostgresClient(configuration: postgresConfiguration)
        let clientTask = Task {
            await client.run()
        }
        defer {
            clientTask.cancel()
        }

        let description = draft.description.nilIfEmpty
        let releaseYear = draft.releaseYear.nilIfEmpty
        let length = draft.length.nilIfEmpty

        try await client.query("""
            update film
            set title = \(draft.title),
                description = \(description),
                release_year = \(releaseYear)::integer,
                language_id = \(draft.languageID),
                original_language_id = \(draft.originalLanguageID),
                rental_duration = \(draft.rentalDuration)::integer,
                rental_rate = \(draft.rentalRate)::numeric,
                length = \(length)::integer,
                replacement_cost = \(draft.replacementCost)::numeric,
                rating = \(draft.rating)::mpaa_rating,
                special_features = array_remove(regexp_split_to_array(\(draft.specialFeatures), '\\s*,\\s*'), ''),
                fulltext = to_tsvector('english', coalesce(\(draft.title), '') || ' ' || coalesce(\(draft.description), '')),
                last_update = now()
            where film_id = \(draft.filmID)
            """)

        return try await loadFilmDetails(filmID: draft.filmID)
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

struct FilmDetails: Sendable {
    let filmID: Int
    let title: String
    let description: String
    let releaseYear: String
    let languageID: Int
    let language: String
    let originalLanguageID: Int?
    let originalLanguage: String
    let rentalDuration: String
    let rentalRate: String
    let length: String
    let replacementCost: String
    let rating: String
    let lastUpdate: String
    let specialFeatures: String
    let fulltext: String
}

struct LanguageOption: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct FilmDetailsDraft: Equatable, Sendable {
    let filmID: Int
    var title: String
    var description: String
    var releaseYear: String
    var languageID: Int
    var originalLanguageID: Int?
    var rentalDuration: String
    var rentalRate: String
    var length: String
    var replacementCost: String
    var rating: String
    var specialFeatures: String
}

private enum DataNodeRepositoryError: LocalizedError {
    case filmNotFound(Int)

    var errorDescription: String? {
        switch self {
        case .filmNotFound(let filmID):
            "No film found for film_id \(filmID)."
        }
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

    var nilIfEmpty: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
