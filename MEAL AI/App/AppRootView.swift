import SwiftUI

struct AppRootView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Kamera", systemImage: "camera.viewfinder")
                }
            NavigationStack {
                FoodSearchView()
            }
            .tabItem {
                Label("Haku", systemImage: "magnifyingglass")
            }
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Asetukset", systemImage: "gearshape")
            }
        }
    }
}
