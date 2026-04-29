import Foundation

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

struct DataNodeDisplayUpdate: Sendable {
    let source: String
    let id: Int
    let title: String
}

extension FilmDetails {
    var nodeDisplayUpdate: DataNodeDisplayUpdate {
        DataNodeDisplayUpdate(
            source: "film",
            id: filmID,
            title: title.displayCapitalized
        )
    }
}
