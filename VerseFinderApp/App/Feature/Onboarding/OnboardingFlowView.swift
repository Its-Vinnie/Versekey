import SwiftUI
import AVKit

struct OnboardingFlowView: View {
    @State private var page: Int = 0
    @State private var isLast: Bool = false

    var settings: SettingsStore
    var onDone: () -> Void

    private let pages: [OnboardingPage] = [
        .init(title: "Welcome to VerseKey", subtitle: "Your premium keyboard for Bible verses.", videoName: "01-welcome"),
        .init(title: "Enable the Keyboard", subtitle: "Open Settings to add VerseKey.", videoName: "02-enable-keyboard", cta: .openSettings),
        .init(title: "Allow Full Access", subtitle: "Enable Full Access for best results.", videoName: "03-allow-full-access"),
        .init(title: "Search Mode", subtitle: "Find verses by reference or phrase.", videoName: "04-search-mode"),
        .init(title: "Browse Mode", subtitle: "Explore books, chapters, and verses.", videoName: "05-browse-mode"),
        .init(title: "Insert Verses", subtitle: "Tap to insert into your app.", videoName: "06-insert-verse")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                OnboardingVideoPanel(videoName: pages[page].videoName)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(UIColor.separator).opacity(0.2), lineWidth: 0.5)
                    )
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text(pages[page].title)
                        .font(.largeTitle.weight(.bold))
                    Text(pages[page].subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                Spacer()

                HStack {
                    if page > 0 {
                        Button("Back") { withAnimation { page -= 1 } }
                    }
                    Spacer()
                    if pages[page].cta == .openSettings {
                        Button("Open Settings") { DeepLinkHelper.openKeyboardSettings() }
                            .buttonStyle(.borderedProminent)
                    }
                    Button(page == pages.count - 1 ? "Done" : "Next") {
                        withAnimation {
                            if page < pages.count - 1 { page += 1 } else { onDone() }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let videoName: String
    let cta: CTA?
    enum CTA { case openSettings }

    init(title: String, subtitle: String, videoName: String, cta: CTA? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.videoName = videoName
        self.cta = cta
    }
}

private struct OnboardingVideoPanel: View {
    let videoName: String
    @State private var shouldLoadVideo = false

    var body: some View {
        Group {
            if shouldLoadVideo, let url = resolveVideoURL(named: videoName) {
                VideoPlayer(player: AVPlayer(url: url))
            } else {
                placeholder
            }
        }
        .task(id: videoName) {
            shouldLoadVideo = false
            await Task.yield()
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            shouldLoadVideo = true
        }
    }

    private func resolveVideoURL(named name: String) -> URL? {
        let bundle = Bundle.main
        let effectiveName: String
        if name == "03-allow-full-access" {
            effectiveName = "Allow-full-access-darkmode"
        } else {
            effectiveName = name
        }

        let candidates: [(String?, String)] = [
            ("TipsVideos/Onboarding", "mp4"),
            ("TipsVideos/Onboarding", "MP4"),
            ("Resources/Tips Videos", "mp4"),
            ("Resources/Tips Videos", "MP4"),
            ("Resources/Tips Videos", "mov"),
            ("Resources/Tips Videos", "MOV"),
            ("Tips Videos", "mp4"),
            ("Tips Videos", "MP4"),
            ("Tips Videos", "mov"),
            ("Tips Videos", "MOV"),
            (nil, "mp4"),
            (nil, "MP4"),
            (nil, "mov"),
            (nil, "MOV")
        ]

        for (subdirectory, ext) in candidates {
            if let url = bundle.url(forResource: effectiveName, withExtension: ext, subdirectory: subdirectory) {
                return url
            }
        }

        return nil
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemGroupedBackground))
            Image(systemName: "play.rectangle.fill").font(.system(size: 48)).foregroundStyle(.secondary)
        }
    }
}

struct OnboardingFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlowView(settings: SettingsStore()) { }
    }
}
