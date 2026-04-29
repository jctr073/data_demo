import SwiftUI

struct FilmDetailsView: View {
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

struct FilmEditFormView: View {
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
                Text("None").tag(Int?.none)
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
            FilmDetailRow(label: "last_update", value: lastUpdate.displayDateTimeValue),
            FilmDetailRow(label: "special_features", value: specialFeatures.displayValue),
            FilmDetailRow(label: "fulltext", value: fulltext)
        ]
    }
}

struct DetailRow: View {
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
