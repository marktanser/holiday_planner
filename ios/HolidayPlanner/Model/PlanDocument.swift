import SwiftUI
import UniformTypeIdentifiers

/// A holiday plan saved as a .json file, the same format the web app uses.
/// The system document browser lets you keep these anywhere in Files, including iCloud Drive.
struct PlanDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var plan: Plan

    init(plan: Plan = .starter) {
        self.plan = plan
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        plan = try Plan.decodeFile(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try plan.encodeFile())
    }
}
