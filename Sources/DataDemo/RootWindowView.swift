import SwiftUI

struct RootWindowView: View {
    let configuration: AppConfiguration
    @Binding var selectedNode: DataNode?
    @State private var nodes: [DataNode] = []
    @State private var isLoadingNodes = false
    @State private var loadingError: String?

    var body: some View {
        VStack(spacing: 0) {
            ToolPanelView(configuration: configuration)

            HSplitView {
                NavTreePanelView(
                    nodes: nodes,
                    isLoading: isLoadingNodes,
                    errorMessage: loadingError,
                    selection: $selectedNode
                )
                    .frame(minWidth: 220, idealWidth: 260, maxWidth: 360)

                MainContextPanelView(selection: selectedNode, configuration: configuration)
                    .frame(minWidth: 560)
            }
        }
        .task {
            await loadNodes()
        }
    }

    @MainActor
    private func loadNodes() async {
        isLoadingNodes = true
        loadingError = nil

        do {
            let loadedNodes = try await DataNodeRepository(configuration: configuration.database).loadNodes()
            nodes = loadedNodes
            if selectedNode == nil || !loadedNodes.contains(where: { $0.contains(selectedNode) }) {
                selectedNode = loadedNodes.first
            }
        } catch {
            nodes = []
            selectedNode = nil
            loadingError = error.localizedDescription
        }

        isLoadingNodes = false
    }
}

private struct ToolPanelView: View {
    let configuration: AppConfiguration

    var body: some View {
        HStack(spacing: 12) {
            Label("Data Demo", systemImage: "tablecells")
                .font(.headline)

            Divider()
                .frame(height: 22)

            Label("Postgres configured", systemImage: "externaldrive.connected.to.line.below")
                .foregroundStyle(.secondary)

            Spacer()

            Text(configuration.environment.displayText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct NavTreePanelView: View {
    let nodes: [DataNode]
    let isLoading: Bool
    let errorMessage: String?
    @Binding var selection: DataNode?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("navTreePanel")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            List(selection: $selection) {
                if isLoading {
                    Label("Loading data", systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                } else if nodes.isEmpty {
                    Label("No data", systemImage: "tray")
                        .foregroundStyle(.secondary)
                } else {
                    OutlineGroup(nodes, children: \.children) { node in
                        Label(node.title, systemImage: node.systemImage)
                            .tag(node)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private extension DataNode {
    func contains(_ target: DataNode?) -> Bool {
        guard let target else {
            return false
        }

        if self == target {
            return true
        }

        return children?.contains { $0.contains(target) } ?? false
    }
}

private struct MainContextPanelView: View {
    let selection: DataNode?
    let configuration: AppConfiguration
    @State private var filmDetails: FilmDetails?
    @State private var languageOptions: [LanguageOption] = []
    @State private var isLoadingFilmDetails = false
    @State private var filmDetailsError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("mainContextPanel")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(selection?.title ?? "No selection")
                        .font(.system(size: 34, weight: .semibold))
                }

                MainContextContentView(
                    selection: selection,
                    configuration: configuration,
                    filmDetails: filmDetails,
                    languageOptions: languageOptions,
                    isLoadingFilmDetails: isLoadingFilmDetails,
                    filmDetailsError: filmDetailsError,
                    onSaveFilmDetails: saveFilmDetails
                )
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
        .task(id: selection?.displayID) {
            await loadSelectedNodeDetails()
        }
    }

    @MainActor
    private func loadSelectedNodeDetails() async {
        let requestedSelection = selection
        let requestedSelectionID = requestedSelection?.displayID

        filmDetails = nil
        languageOptions = []
        filmDetailsError = nil
        isLoadingFilmDetails = false

        guard let requestedSelection else {
            return
        }

        switch requestedSelection.source {
        case "film":
            isLoadingFilmDetails = true
            defer {
                if selection?.displayID == requestedSelectionID {
                    isLoadingFilmDetails = false
                }
            }

            do {
                let repository = DataNodeRepository(configuration: configuration.database)
                async let details = repository.loadFilmDetails(filmID: requestedSelection.id)
                async let languages = repository.loadLanguageOptions()
                let loadedDetails = try await details
                let loadedLanguages = try await languages
                if !Task.isCancelled && selection?.displayID == requestedSelectionID {
                    filmDetails = loadedDetails
                    languageOptions = loadedLanguages
                }
            } catch {
                if !Task.isCancelled && selection?.displayID == requestedSelectionID {
                    filmDetailsError = error.localizedDescription
                }
            }
        default:
            break
        }
    }

    @MainActor
    private func saveFilmDetails(_ draft: FilmDetailsDraft) async throws -> FilmDetails {
        let savedDetails = try await DataNodeRepository(configuration: configuration.database)
            .saveFilmDetails(draft)
        if selection?.source == "film", selection?.id == draft.filmID {
            filmDetails = savedDetails
        }
        return savedDetails
    }
}

private extension DataNode {
    var displayID: String {
        "\(source):\(id)"
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

private struct FilmDetailsView: View {
    let filmDetails: FilmDetails?
    let isLoading: Bool
    let errorMessage: String?
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                Label("Loading film details", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            } else if let filmDetails {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.borderedProminent)

                ForEach(filmDetails.displayRows) { row in
                    DetailRow(label: row.label, value: row.value)
                }
            }
        }
    }
}

private struct FilmEditFormView: View {
    let languageOptions: [LanguageOption]
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (FilmDetailsDraft) -> Void
    let onCancel: () -> Void
    private let filmID: Int
    @State private var title: String
    @State private var description: String
    @State private var releaseYear: String
    @State private var languageID: Int
    @State private var originalLanguageID: Int?
    @State private var rentalDuration: String
    @State private var rentalRate: String
    @State private var length: String
    @State private var replacementCost: String
    @State private var rating: String
    @State private var specialFeatures: String

    init(
        filmDetails: FilmDetails,
        languageOptions: [LanguageOption],
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (FilmDetailsDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.languageOptions = languageOptions
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave
        self.onCancel = onCancel
        filmID = filmDetails.filmID
        _title = State(initialValue: filmDetails.title)
        _description = State(initialValue: filmDetails.description)
        _releaseYear = State(initialValue: filmDetails.releaseYear)
        _languageID = State(initialValue: filmDetails.languageID)
        _originalLanguageID = State(initialValue: filmDetails.originalLanguageID)
        _rentalDuration = State(initialValue: filmDetails.rentalDuration)
        _rentalRate = State(initialValue: filmDetails.rentalRate)
        _length = State(initialValue: filmDetails.length)
        _replacementCost = State(initialValue: filmDetails.replacementCost)
        _rating = State(initialValue: filmDetails.rating)
        _specialFeatures = State(initialValue: filmDetails.specialFeatures)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DetailRow(label: "film_id", value: String(filmID))

            FilmTextFieldRow(label: "title", text: $title, width: 420)
            FilmTextEditorRow(label: "description", text: $description)
            FilmTextFieldRow(label: "release_year", text: $releaseYear, width: 140)
            FilmLanguagePickerRow(
                label: "language",
                selection: $languageID,
                languageOptions: languageOptions
            )
            FilmOptionalLanguagePickerRow(
                label: "original_language",
                selection: $originalLanguageID,
                languageOptions: languageOptions
            )
            FilmTextFieldRow(label: "rental_duration", text: $rentalDuration, width: 140)
            FilmTextFieldRow(label: "rental_rate", text: $rentalRate, width: 140)
            FilmTextFieldRow(label: "length", text: $length, width: 140)
            FilmTextFieldRow(label: "replacement_cost", text: $replacementCost, width: 140)
            FilmTextFieldRow(label: "rating", text: $rating, width: 140)
            FilmTextFieldRow(label: "special_features", text: $specialFeatures, width: 420)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .disabled(isSaving)

                Button(action: { onSave(makeDraft()) }) {
                    if isSaving {
                        Label("Saving", systemImage: "hourglass")
                    } else {
                        Label("Save", systemImage: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving || !canSave)
            }
            .padding(.top, 4)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !rentalDuration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !rentalRate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !replacementCost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !rating.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && languageOptions.contains(where: { $0.id == languageID })
    }

    private func makeDraft() -> FilmDetailsDraft {
        FilmDetailsDraft(
            filmID: filmID,
            title: title,
            description: description,
            releaseYear: releaseYear,
            languageID: languageID,
            originalLanguageID: originalLanguageID,
            rentalDuration: rentalDuration,
            rentalRate: rentalRate,
            length: length,
            replacementCost: replacementCost,
            rating: rating,
            specialFeatures: specialFeatures
        )
    }
}

private struct FilmTextFieldRow: View {
    let label: String
    @Binding var text: String
    let width: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            FilmFieldLabel(label)

            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
        }
    }
}

private struct FilmTextEditorRow: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            FilmFieldLabel(label)
                .padding(.top, 6)

            TextEditor(text: $text)
                .font(.callout)
                .frame(width: 520, height: 96)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor))
                }
        }
    }
}

private struct FilmLanguagePickerRow: View {
    let label: String
    @Binding var selection: Int
    let languageOptions: [LanguageOption]

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            FilmFieldLabel(label)

            Picker(label, selection: $selection) {
                ForEach(languageOptions) { option in
                    Text(option.name).tag(option.id)
                }
            }
            .labelsHidden()
            .frame(width: 220)
            .disabled(languageOptions.isEmpty)
        }
    }
}

private struct FilmOptionalLanguagePickerRow: View {
    let label: String
    @Binding var selection: Int?
    let languageOptions: [LanguageOption]

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            FilmFieldLabel(label)

            Picker(label, selection: $selection) {
                Text("NULL").tag(Int?.none)
                ForEach(languageOptions) { option in
                    Text(option.name).tag(Int?.some(option.id))
                }
            }
            .labelsHidden()
            .frame(width: 220)
            .disabled(languageOptions.isEmpty)
        }
    }
}

private struct FilmFieldLabel: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(.callout.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: 180, alignment: .leading)
    }
}

private struct FilmDetailRow: Identifiable {
    let label: String
    let value: String

    var id: String {
        label
    }
}

private extension FilmDetails {
    var displayRows: [FilmDetailRow] {
        [
            FilmDetailRow(label: "film_id", value: String(filmID)),
            FilmDetailRow(label: "title", value: title),
            FilmDetailRow(label: "description", value: description),
            FilmDetailRow(label: "release_year", value: releaseYear),
            FilmDetailRow(label: "language", value: language),
            FilmDetailRow(label: "original_language", value: originalLanguage.displayValue),
            FilmDetailRow(label: "rental_duration", value: rentalDuration),
            FilmDetailRow(label: "rental_rate", value: rentalRate),
            FilmDetailRow(label: "length", value: length.displayValue),
            FilmDetailRow(label: "replacement_cost", value: replacementCost),
            FilmDetailRow(label: "rating", value: rating),
            FilmDetailRow(label: "last_update", value: lastUpdate),
            FilmDetailRow(label: "special_features", value: specialFeatures.displayValue),
            FilmDetailRow(label: "fulltext", value: fulltext)
        ]
    }

    var editDraft: FilmDetailsDraft {
        FilmDetailsDraft(
            filmID: filmID,
            title: title,
            description: description,
            releaseYear: releaseYear,
            languageID: languageID,
            originalLanguageID: originalLanguageID,
            rentalDuration: rentalDuration,
            rentalRate: rentalRate,
            length: length,
            replacementCost: replacementCost,
            rating: rating,
            specialFeatures: specialFeatures
        )
    }
}

private extension String {
    var displayValue: String {
        isEmpty ? "NULL" : self
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .leading)

            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
