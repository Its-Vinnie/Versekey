import SwiftUI
import AVKit
import AVFoundation
import Combine

struct TipsView: View {
    var settings: SettingsStore
    @State private var focusedTipID: UUID?

    private let getStarted: [TipCard] = [
        // Portrait tip video (now 1:1 square to fill the card)
        .init(title: "Enable the Keyboard",
              subtitle: "Turn on VerseKey in Settings.",
              videoName: "enable-keyboard",
              isPortraitVideo: true,
              actionLabel: "Open Settings",
              settingsDestination: .keyboard),
        .init(title: "Allow Full Access",
              subtitle: "Enable for best reliability.",
              videoName: "03-allow-full-access",
              isPortraitVideo: false,
              actionLabel: "Open Settings",
              settingsDestination: .keyboard)
    ]

    private let useVerseKey: [TipCard] = [
        .init(title: "Search Mode",
              subtitle: "Type or say ‘John 3:16’.",
              videoName: "search-fast",
              isPortraitVideo: false),
        .init(title: "Browse Mode",
              subtitle: "Explore books, chapters, and verses.",
              videoName: "05-browse-mode",
              isPortraitVideo: false),
        .init(title: "Switch Translations",
              subtitle: "Tap a pill to switch.",
              videoName: "switch-translations",
              isPortraitVideo: false)
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: "Get Started")
                        TipCardList(tips: getStarted, focusedTipID: focusedTipID)

                        SectionHeader(title: "Use VerseKey")
                        TipCardList(tips: useVerseKey, focusedTipID: focusedTipID)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .coordinateSpace(name: "tips-scroll")
                .onPreferenceChange(TipFocusPreferenceKey.self) { frames in
                    let viewport = CGRect(origin: .zero, size: geometry.size)
                    focusedTipID = bestFocusedTip(in: frames, viewport: viewport, current: focusedTipID)
                }
            }
            .navigationTitle("Tips")
        }
    }

    private func visibleHeight(_ frame: CGRect, in viewport: CGRect) -> CGFloat {
        max(0, min(frame.maxY, viewport.maxY) - max(frame.minY, viewport.minY))
    }

    private func focusScore(for frame: CGRect, in viewport: CGRect) -> CGFloat {
        let visible = visibleHeight(frame, in: viewport)
        guard visible > 60 else { return 0 }

        let centerDistance = abs(frame.midY - viewport.midY)
        let centerBonus = max(0, (viewport.height / 2) - centerDistance) * 0.35
        return visible + centerBonus
    }

    private func bestFocusedTip(
        in frames: [UUID: CGRect],
        viewport: CGRect,
        current: UUID?
    ) -> UUID? {
        let scoredFrames = frames.map { id, frame in
            (id: id, score: focusScore(for: frame, in: viewport))
        }
        guard let best = scoredFrames.max(by: { $0.score < $1.score }), best.score > 0 else {
            return nil
        }

        if
            let current,
            let currentFrame = frames[current],
            focusScore(for: currentFrame, in: viewport) >= best.score - 24
        {
            return current
        }

        return best.id
    }
}

private struct TipFocusPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title2.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TipCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let videoName: String
    let isPortraitVideo: Bool
    let actionLabel: String?
    let settingsDestination: TipSettingsDestination?

    init(
        title: String,
        subtitle: String,
        videoName: String,
        isPortraitVideo: Bool,
        actionLabel: String? = nil,
        settingsDestination: TipSettingsDestination? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.videoName = videoName
        self.isPortraitVideo = isPortraitVideo
        self.actionLabel = actionLabel
        self.settingsDestination = settingsDestination
    }
}

enum TipSettingsDestination {
    case keyboard
}

private struct TipCardList: View {
    let tips: [TipCard]
    let focusedTipID: UUID?

    var body: some View {
        LazyVStack(spacing: 14) {
            ForEach(tips) { tip in
                TipCardView(tip: tip, isFocused: focusedTipID == tip.id)
            }
        }
    }
}

private struct TipCardView: View {
    let tip: TipCard
    let isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let cardCorner: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            // Stage that fills the card area with the video
            VideoStage(tip: tip, isFocused: isFocused)

            // CONTENT (padded)
            VStack(alignment: .leading, spacing: 10) {
                Text(tip.title).font(.headline)
                Text(tip.subtitle).font(.subheadline).foregroundStyle(.secondary)

                if let actionLabel = tip.actionLabel, let settingsDestination = tip.settingsDestination {
                    HStack {
                        Spacer()
                        Button(actionLabel) {
                            switch settingsDestination {
                            case .keyboard:
                                DeepLinkHelper.openKeyboardSettings()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(14)
        }
        // Native iOS background that adapts to Light/Dark (less pure dark)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .stroke(
                    colorScheme == .dark
                    ? Color.white.opacity(0.08)        // subtle in Dark Mode
                    : Color.black.opacity(0.12),       // subtle in Light Mode
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TipFocusPreferenceKey.self,
                    value: [tip.id: proxy.frame(in: .named("tips-scroll"))]
                )
            }
        )
    }
}

// MARK: - Video Stage (square fills card for 1:1, landscape keeps fixed height)

private struct VideoStage: View {
    let tip: TipCard
    let isFocused: Bool
    @Environment(\.colorScheme) private var scheme

    private let corner: CGFloat = 16

    var body: some View {
        Group {
            if tip.isPortraitVideo {
                // 1:1 video fills the stage; stage keeps a square ratio equal to card width
                ZStack {
                    TipsVideoPlayerView(
                        videoName: tip.videoName,
                        isPortrait: tip.isPortraitVideo,
                        gravity: .resizeAspectFill, // fill square cleanly
                        isFocused: isFocused
                    )
                    // Slight zoom for a tighter, more immersive look
                    .scaleEffect(1.08)
                    .clipped()
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            } else {
                // Non-square (landscape) videos keep a tuned height and fill width
                ZStack {
                    TipsVideoPlayerView(
                        videoName: tip.videoName,
                        isPortrait: tip.isPortraitVideo,
                        gravity: .resizeAspect, // avoid cropping UI
                        isFocused: isFocused
                    )
                    // Subtle zoom for consistency while preserving UI edges
                    .scaleEffect(1.03)
                    .clipped()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            }
        }
        // Stage background matches the card; will show only if any letterboxing exists
        .background(Color(.systemBackground))
    }
}

// MARK: - Tips video player

private struct TipsVideoPlayerView: View {
    let videoName: String
    let isPortrait: Bool
    let gravity: AVLayerVideoGravity
    let isFocused: Bool
    @Environment(\.colorScheme) private var scheme
    @State private var shouldLoadVideo = false

    var body: some View {
        let effectiveName = remapNameForColorScheme(baseName: videoName, scheme: scheme)

        Group {
            if shouldLoadVideo, let url = resolveVideoURL(named: effectiveName) {
                PlayerLayerView(url: url, gravity: gravity, isPlaying: isFocused)
                    .onTapGesture {
                        // tap to resume if paused - handled inside PlayerContainer too
                    }
            } else {
                videoPlaceholder
            }
        }
        .task(id: effectiveName) {
            shouldLoadVideo = false
            await Task.yield()
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            shouldLoadVideo = true
        }
    }

    private var videoPlaceholder: some View {
        ZStack {
            Color(.systemBackground)
        }
    }

    // Map base tip name to dark/light variants when appropriate
    private func remapNameForColorScheme(baseName: String, scheme: ColorScheme) -> String {
        if baseName == "enable-keyboard" {
            switch scheme {
            case .dark:
                return "enable-keyboard-darkmode"
            default:
                return "enable-keyboard-lightmode"
            }
        }
        if baseName == "search-fast" {
            switch scheme {
            case .dark:
                return "search-mode-darkmode"
            default:
                return "search-mode-lightmode"
            }
        }
        if baseName == "05-browse-mode" {
            return "browse-mode-darkmode"
        }
        if baseName == "03-allow-full-access" {
            switch scheme {
            case .dark:
                return "allow-full-access-darkmode"
            default:
                return "allow-full-access-lightmode"
            }
        }
        if baseName == "switch-translations" {
            return "translation-switch-darkmode"
        }
        return baseName
    }

    // Try multiple folders and extensions; prefer mp4 in "Resources/Tips Videos"
    private func resolveVideoURL(named name: String) -> URL? {
        let bundle = Bundle.main
        let candidates: [(String?, String)] = [
            ("Resources/Tips Videos", "mp4"),
            ("Resources/Tips Videos", "MP4"),
            ("Resources/Tips Videos", "mov"),
            ("Resources/Tips Videos", "MOV"),
            ("Tips Videos", "mp4"),
            ("Tips Videos", "MP4"),
            ("Tips Videos", "mov"),
            ("Tips Videos", "MOV"),
            ("TipsVideos/Tips", "mp4"),
            ("TipsVideos/Tips", "MP4"),
            ("TipsVideos/Tips", "mov"),
            ("TipsVideos/Tips", "MOV"),
            (nil, "mp4"),
            (nil, "MP4"),
            (nil, "mov"),
            (nil, "MOV")
        ]
        for (subdir, ext) in candidates {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: subdir) {
                return url
            }
        }
        return nil
    }
}

// MARK: AVPlayerLayer-based SwiftUI wrapper (with configurable gravity)

private struct PlayerLayerView: UIViewRepresentable {
    let url: URL
    let gravity: AVLayerVideoGravity
    let isPlaying: Bool

    func makeUIView(context: Context) -> PlayerContainer {
        let view = PlayerContainer()
        view.backgroundColor = .systemBackground // match the card/stage exactly
        view.configure(with: url, gravity: gravity, isPlaying: isPlaying)
        return view
    }

    func updateUIView(_ uiView: PlayerContainer, context: Context) {
        uiView.configure(with: url, gravity: gravity, isPlaying: isPlaying)
    }

    static func dismantleUIView(_ uiView: PlayerContainer, coordinator: ()) {
        uiView.teardown()
    }
}

private final class PlayerContainer: UIView {
    private let player = AVPlayer()
    private var endObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var currentURL: URL?
    private var isPlaying = false

    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    func configure(with url: URL, gravity: AVLayerVideoGravity, isPlaying: Bool) {
        self.isPlaying = isPlaying

        guard currentURL != url else {
            // Keep gravity and playback state up to date.
            playerLayer.videoGravity = gravity
            if isPlaying {
                player.play()
            } else {
                player.pause()
            }
            return
        }
        currentURL = url

        teardownObservers()

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.isMuted = true
        player.allowsExternalPlayback = false
        player.actionAtItemEnd = .pause

        backgroundColor = .systemBackground
        playerLayer.player = player
        playerLayer.videoGravity = gravity
        playerLayer.backgroundColor = UIColor.systemBackground.cgColor

        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            switch item.status {
            case .readyToPlay:
                self?.player.seek(to: .zero)
                if self?.isPlaying == true {
                    self?.player.play()
                } else {
                    self?.player.pause()
                }
            case .failed:
                print("TipsVideoPlayerView: player item failed: \(item.error?.localizedDescription ?? "unknown error")")
            case .unknown:
                break
            @unknown default:
                break
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.player.seek(to: .zero)
            if self.isPlaying {
                self.player.play()
            } else {
                self.player.pause()
            }
        }

        // Nudge playback in Simulator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.isPlaying else { return }
            self.player.play()
        }
    }

    func teardown() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        teardownObservers()
        playerLayer.player = nil
        currentURL = nil
    }

    private func teardownObservers() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        statusObserver = nil
    }
}

struct TipsView_Previews: PreviewProvider {
    static var previews: some View {
        TipsView(settings: SettingsStore())
    }
}
