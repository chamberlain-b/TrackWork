import SwiftUI

struct ExportView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Export",
                systemImage: "square.and.arrow.up",
                description: Text("PDF, Excel, and CSV reports will be generated here.")
            )
            .navigationTitle("Export")
        }
    }
}

#Preview {
    ExportView()
}
