import Foundation

enum NoteError: LocalizedError {
    case fileReadFailed(URL, Error)
    case fileWriteFailed(URL, Error)
    case fileDeleteFailed(URL, Error)
    case invalidURL
    case invalidContent
    case tooManyDuplicates
    case directoryNotAccessible(URL)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .fileReadFailed(let url, let error):
            return "Failed to read note from \(url.lastPathComponent): \(error.localizedDescription)"
        case .fileWriteFailed(let url, let error):
            return "Failed to save note to \(url.lastPathComponent): \(error.localizedDescription)"
        case .fileDeleteFailed(let url, let error):
            return "Failed to delete note \(url.lastPathComponent): \(error.localizedDescription)"
        case .invalidURL:
            return "The file path is invalid"
        case .invalidContent:
            return "The note content is invalid"
        case .tooManyDuplicates:
            return "Too many files with the same name. Please rename some notes."
        case .directoryNotAccessible(let url):
            return "Cannot access directory: \(url.path)"
        case .encodingFailed:
            return "Failed to encode note content to UTF-8"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileReadFailed, .fileWriteFailed:
            return "Check that the file is not locked by another application and you have permission to access it."
        case .fileDeleteFailed:
            return "Check that the file exists and you have permission to delete it."
        case .directoryNotAccessible:
            return "Choose a different notes folder or check folder permissions."
        case .tooManyDuplicates:
            return "Rename some of your notes to have unique titles."
        default:
            return nil
        }
    }
}
