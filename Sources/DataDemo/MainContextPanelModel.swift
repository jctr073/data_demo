import SwiftUI

@MainActor
final class MainContextPanelModel: ObservableObject {
    @Published private(set) var filmDetails: FilmDetails?
    @Published private(set) var languageOptions: [LanguageOption] = []
    @Published private(set) var isLoadingFilmDetails = false
    @Published private(set) var filmDetailsError: String?

    private let configuration: DatabaseConfiguration
    private var activeSelectionID: String?

    init(configuration: DatabaseConfiguration) {
        self.configuration = configuration
    }

    func loadDetails(for selection: DataNode?) async {
        activeSelectionID = selection?.displayID
        resetFilmState()

        guard let selection else {
            return
        }

        switch selection.source {
        case "film":
            await loadFilmDetails(for: selection)
        default:
            break
        }
    }

    func saveFilmDetails(_ draft: FilmDetailsDraft, currentSelection: DataNode?) async throws -> FilmDetails {
        let savedDetails = try await DataNodeRepository(configuration: configuration)
            .saveFilmDetails(draft)

        if currentSelection?.source == "film", currentSelection?.id == draft.filmID {
            filmDetails = savedDetails
        }

        return savedDetails
    }

    private func loadFilmDetails(for selection: DataNode) async {
        let requestedSelectionID = selection.displayID
        isLoadingFilmDetails = true

        defer {
            if activeSelectionID == requestedSelectionID {
                isLoadingFilmDetails = false
            }
        }

        do {
            let repository = DataNodeRepository(configuration: configuration)
            async let details = repository.loadFilmDetails(filmID: selection.id)
            async let languages = repository.loadLanguageOptions()
            let loadedDetails = try await details
            let loadedLanguages = try await languages

            if !Task.isCancelled && activeSelectionID == requestedSelectionID {
                filmDetails = loadedDetails
                languageOptions = loadedLanguages
            }
        } catch {
            if !Task.isCancelled && activeSelectionID == requestedSelectionID {
                filmDetailsError = error.localizedDescription
            }
        }
    }

    private func resetFilmState() {
        filmDetails = nil
        languageOptions = []
        filmDetailsError = nil
        isLoadingFilmDetails = false
    }
}
