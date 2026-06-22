import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    @StateObject private var settings = SettingsStore()

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        Group {
            if settings.didCompleteOnboarding {
                TabView(selection: $selectedTab) {
                    TipsView(settings: settings)
                        .tabItem { Label("Tips", systemImage: "lightbulb.fill") }
                        .tag(0)

                    HistoryView(history: HistoryStore())
                        .tabItem { Label("History", systemImage: "clock.fill") }
                        .tag(1)

                    SettingsView(settings: settings)
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                        .tag(2)

                    PreviewView()
                        .tabItem { Label("Preview", systemImage: "keyboard") }
                        .tag(3)
                }
                .tint(Color.accentBlue)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            } else {
                OnboardingFlowView(settings: settings) {
                    settings.didCompleteOnboarding = true
                }
            }
        }
    }
}

private extension Color {
    static let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
}

private func configureTabBarAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    appearance.backgroundColor = UIColor.black.withAlphaComponent(0.28)
    appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)

    let selected = UIColor(Color.accentBlue)
    let normal = UIColor.white.withAlphaComponent(0.58)

    appearance.stackedLayoutAppearance.selected.iconColor = selected
    appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selected]
    appearance.stackedLayoutAppearance.normal.iconColor = normal
    appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normal]

    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
