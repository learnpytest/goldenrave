import GoldenRetrieverCore
import SwiftUI

@main
struct GoldenRetrieverApp: App {
    var body: some Scene {
        MenuBarExtra("Golden Retriever", systemImage: "pawprint.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Golden Retriever")
                    .font(.headline)
                Text("Ready to keep you company")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
