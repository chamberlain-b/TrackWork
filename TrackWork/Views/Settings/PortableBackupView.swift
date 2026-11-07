import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PortableBackupView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingSensitiveBackupConfirmation = false
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var backupDocument = PortableBackupDocument()
    @State private var backupFilename = "Work-Track-Backup"
    @State private var pendingImport: PendingPortableBackup?
    @State private var backupResult: BackupOperationResult?

    private let backupService = PortableBackupService()

    var body: some View {
        List {
            PortableBackupExplanationSection()

            Section {
                Button {
                    exportBackup(scope: .standard)
                } label: {
                    Label("Export Standard", systemImage: "externaldrive.badge.plus")
                }
                .accessibilityIdentifier("privacyData.exportStandardBackup")

                Button {
                    isShowingSensitiveBackupConfirmation = true
                } label: {
                    Label("Export Full", systemImage: "lock.doc")
                }
                .accessibilityIdentifier("privacyData.exportFullBackup")

                Button {
                    isImportingBackup = true
                } label: {
                    Label("Restore Backup", systemImage: "arrow.counterclockwise.icloud")
                }
                .accessibilityIdentifier("privacyData.restoreBackup")

                if let backupResult {
                    Label(backupResult.message, systemImage: backupResult.systemImage)
                        .font(AppTypography.caption)
                        .foregroundStyle(backupResult.color)
                        .accessibilityIdentifier("privacyData.backupStatus")
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("JSON backups are not encrypted.")
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExportingBackup,
            document: backupDocument,
            contentType: .json,
            defaultFilename: backupFilename,
            onCompletion: handleExportCompletion
        )
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: prepareImport
        )
        .confirmationDialog(
            "Include sensitive location data?",
            isPresented: $isShowingSensitiveBackupConfirmation,
            titleVisibility: .visible
        ) {
            Button("Export Full Backup") {
                exportBackup(scope: .fullPrivate)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Includes saved addresses, coordinates and raw location events. The file is not encrypted."
            )
        }
        .confirmationDialog(
            "Restore Work Track backup?",
            isPresented: pendingImportPresentation,
            titleVisibility: .visible,
            presenting: pendingImport
        ) { pending in
            Button("Merge with On-Device Data") {
                restore(pending, policy: .mergePreferBackup)
            }
            Button("Replace Backed-Up Data", role: .destructive) {
                restore(pending, policy: .replace)
            }
            Button("Cancel", role: .cancel) {
                pendingImport = nil
            }
        } message: { pending in
            Text(pending.confirmationMessage)
        }
    }

    private var pendingImportPresentation: Binding<Bool> {
        Binding(
            get: { pendingImport != nil },
            set: { if !$0 { pendingImport = nil } }
        )
    }

    private func handleExportCompletion(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            backupResult = .success("Backup exported.")
        case .failure:
            backupResult = .failure("The backup could not be exported. Try again.")
        }
    }

    private func exportBackup(scope: PortableBackupPrivacyScope) {
        do {
            let data = try backupService.makeBackupData(from: modelContext, privacyScope: scope)
            backupDocument = PortableBackupDocument(data: data)
            let scopeSuffix = scope == .standard ? "Standard" : "Full-Private"
            let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            backupFilename = "Work-Track-\(scopeSuffix)-Backup-\(date)"
            backupResult = nil
            isExportingBackup = true
        } catch {
            backupResult = .failure(error.localizedDescription)
        }
    }

    private func prepareImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let hasSecurityAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let inspection = try backupService.inspect(data)
            pendingImport = PendingPortableBackup(data: data, inspection: inspection)
            backupResult = nil
        } catch {
            backupResult = .failure(error.localizedDescription)
        }
    }

    private func restore(
        _ pending: PendingPortableBackup,
        policy: PortableBackupRestorePolicy
    ) {
        do {
            if modelContext.hasChanges {
                try modelContext.save()
            }
            let result = try backupService.restore(pending.data, policy: policy, into: modelContext)
            pendingImport = nil
            backupResult = .success("Restored \(result.recordCounts.total) records from the backup.")
        } catch {
            pendingImport = nil
            backupResult = .failure(error.localizedDescription)
        }
    }
}

private struct PortableBackupExplanationSection: View {
    var body: some View {
        Section {
            Label {
                Text(
                    "Standard: attendance, leave, rules, plans and edited holidays. No saved locations or raw events."
                )
            } icon: {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(Color.ds.success)
            }

            Label {
                Text(
                    "Full: adds saved locations and raw boundary events."
                )
            } icon: {
                Image(systemName: "lock.doc.fill")
                    .foregroundStyle(Color.ds.warning)
            }
        } header: {
            Text("Contents")
        }
    }
}

private struct PortableBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct PendingPortableBackup: Identifiable {
    let id = UUID()
    let data: Data
    let inspection: PortableBackupInspection

    var confirmationMessage: String {
        let scopeDescription = inspection.privacyScope == .standard
            ? "Standard backup: no saved locations or raw events."
            : "Full backup: includes sensitive location data."
        return "\(scopeDescription) \(inspection.recordCounts.total) records. "
            + "Merge keeps local-only records; replace uses the backup."
    }
}

private enum BackupOperationResult {
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .success(let message), .failure(let message): message
        }
    }

    var systemImage: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: Color.ds.success
        case .failure: Color.ds.critical
        }
    }
}

#Preview {
    NavigationStack {
        PortableBackupView()
    }
    .modelContainer(PreviewData.modelContainer())
}
