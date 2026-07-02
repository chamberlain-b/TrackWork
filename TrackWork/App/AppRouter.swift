import SwiftData
import SwiftUI

struct AppRouter: View {
    var body: some View {
        ContentView()
    }
}

#Preview {
    AppRouter()
        .modelContainer(PreviewData.modelContainer())
}
