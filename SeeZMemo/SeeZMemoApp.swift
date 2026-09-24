import SwiftData
import SwiftUI

@main
struct SeeZMemoApp: App {
    var body: some Scene {
        WindowGroup { HomeView() }
            .modelContainer(for: [PlaceRecord.self, PlacePhoto.self])
    }
}
