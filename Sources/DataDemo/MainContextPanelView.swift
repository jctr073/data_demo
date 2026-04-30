import SwiftUI

struct MainContextPanelView: View {
    let selection: DataNode?
    let breadcrumb: [DataNode]
    let configuration: AppConfiguration
    let onNodeUpdated: (DataNodeDisplayUpdate) -> Void

    @StateObject private var model: MainContextPanelModel

    init(
        selection: DataNode?,
        breadcrumb: [DataNode],
        configuration: AppConfiguration,
        onNodeUpdated: @escaping (DataNodeDisplayUpdate) -> Void
    ) {
        self.selection = selection
        self.breadcrumb = breadcrumb
        self.configuration = configuration
        self.onNodeUpdated = onNodeUpdated
        _model = StateObject(
            wrappedValue: MainContextPanelModel(configuration: configuration.database)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DetailHeaderView(selection: selection, breadcrumb: breadcrumb)

                MainContextContentView(
                    selection: selection,
                    configuration: configuration,
                    filmDetails: model.filmDetails,
                    languageOptions: model.languageOptions,
                    isLoadingFilmDetails: model.isLoadingFilmDetails,
                    filmDetailsError: model.filmDetailsError,
                    onSaveFilmDetails: saveFilmDetails
                )
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 44)
            .frame(maxWidth: 900, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
        .task(id: selection?.displayID) {
            await model.loadDetails(for: selection)
        }
    }

    private func saveFilmDetails(_ draft: FilmDetailsDraft) async throws -> FilmDetails {
        let savedDetails = try await model.saveFilmDetails(draft, currentSelection: selection)

        if selection?.source == "film", selection?.id == draft.filmID {
            onNodeUpdated(savedDetails.nodeDisplayUpdate)
        }

        return savedDetails
    }
}

private struct DetailHeaderView: View {
    let selection: DataNode?
    let breadcrumb: [DataNode]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BreadcrumbView(nodes: breadcrumb)

            Text(selection?.title ?? "Select a film")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

private struct BreadcrumbView: View {
    let nodes: [DataNode]

    var body: some View {
        if nodes.isEmpty {
            Text("Films")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 6) {
                ForEach(Array(nodes.enumerated()), id: \.element.displayID) { index, node in
                    if index > 0 {
                        Text("›")
                            .foregroundStyle(.tertiary)
                    }

                    Text(label(for: node))
                        .lineLimit(1)
                }
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }

    private func label(for node: DataNode) -> String {
        switch node.source {
        case "film":
            "Film #\(node.id)"
        case "actor":
            "Actor #\(node.id)"
        default:
            node.title
        }
    }
}

private struct MainContextContentView: View {
    let selection: DataNode?
    let configuration: AppConfiguration
    let filmDetails: FilmDetails?
    let languageOptions: [LanguageOption]
    let isLoadingFilmDetails: Bool
    let filmDetailsError: String?
    let onSaveFilmDetails: (FilmDetailsDraft) async throws -> FilmDetails

    @State private var isEditingFilm = false
    @State private var isSavingFilm = false
    @State private var saveFilmError: String?

    var body: some View {
        if selection?.source == "film" {
            Group {
                if isEditingFilm, let filmDetails {
                    FilmEditFormView(
                        filmDetails: filmDetails,
                        languageOptions: languageOptions,
                        isSaving: isSavingFilm,
                        errorMessage: saveFilmError,
                        onSave: saveFilm,
                        onCancel: cancelEditing
                    )
                } else {
                    FilmDetailsView(
                        filmDetails: filmDetails,
                        isLoading: isLoadingFilmDetails,
                        errorMessage: filmDetailsError,
                        onEdit: startEditing
                    )
                }
            }
            .onChange(of: selection?.displayID) {
                cancelEditing()
            }
            .onChange(of: filmDetails?.filmID) {
                if !isSavingFilm {
                    cancelEditing()
                }
            }
        } else {
            SelectionSummaryView(selection: selection, configuration: configuration)
        }
    }

    private func startEditing() {
        guard filmDetails != nil else {
            return
        }

        saveFilmError = nil
        isEditingFilm = true
    }

    private func cancelEditing() {
        saveFilmError = nil
        isSavingFilm = false
        isEditingFilm = false
    }

    private func saveFilm(_ draft: FilmDetailsDraft) {
        isSavingFilm = true
        saveFilmError = nil

        Task {
            do {
                _ = try await onSaveFilmDetails(draft)
                if !Task.isCancelled {
                    cancelEditing()
                }
            } catch {
                if !Task.isCancelled {
                    saveFilmError = error.localizedDescription
                    isSavingFilm = false
                }
            }
        }
    }
}

private struct SelectionSummaryView: View {
    let selection: DataNode?
    let configuration: AppConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailRow(label: "Database", value: configuration.database.database)
            DetailRow(label: "Host", value: "\(configuration.database.host):\(configuration.database.port)")
            DetailRow(label: "Adapter", value: "PostgresNIO")
            DetailRow(label: "Selected node", value: selection?.displayID ?? "none")
        }
    }
}
