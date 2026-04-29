import Foundation

extension String {
    var displayCapitalized: String {
        lowercased().capitalized
    }

    var nilIfEmpty: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    var displayValue: String {
        isEmpty ? "" : self
    }

    var displayDateTimeValue: String {
        guard !isEmpty else {
            return ""
        }

        if let date = Self.postgresTimestampWithFractionalSeconds.date(from: self)
            ?? Self.postgresTimestamp.date(from: self)
        {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        return self
    }

    private static let postgresTimestampWithFractionalSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
        return formatter
    }()

    private static let postgresTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        return formatter
    }()
}
