import Foundation

enum GeneratedExportStoreError: Error, Equatable {
    case invalidFileName
    case unmanagedFile
}

struct GeneratedExportStore {
    static let directoryName = "WorkTrackGeneratedExports"

    let directoryURL: URL
    private let fileManager: FileManager

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL
            ?? fileManager.temporaryDirectory.appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    func fileURL(named fileName: String) throws -> URL {
        guard !fileName.isEmpty,
              (fileName as NSString).lastPathComponent == fileName else {
            throw GeneratedExportStoreError.invalidFileName
        }

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        return directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    func removeFile(at fileURL: URL) throws {
        let managedDirectory = directoryURL.standardizedFileURL
        let standardizedFileURL = fileURL.standardizedFileURL

        guard standardizedFileURL.deletingLastPathComponent() == managedDirectory else {
            throw GeneratedExportStoreError.unmanagedFile
        }

        guard fileManager.fileExists(atPath: standardizedFileURL.path) else {
            return
        }

        try fileManager.removeItem(at: standardizedFileURL)
    }

    func removeAllFiles() throws {
        let managedDirectory = directoryURL.standardizedFileURL
        guard fileManager.fileExists(atPath: managedDirectory.path) else {
            return
        }

        try fileManager.removeItem(at: managedDirectory)
    }
}
