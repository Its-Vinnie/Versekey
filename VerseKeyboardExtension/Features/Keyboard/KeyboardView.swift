//  KeyboardView.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/02.
//

import SwiftUI
import Foundation
import Combine
import UIKit

struct KeyboardPalette {
    let keyboardBackground: Color
    let keyboardBackgroundUIColor: UIColor
    let controlBackground: Color
    let controlBorder: Color
    let keyBackground: Color
    let specialKeyBackground: Color
    let keyHighlight: Color
    let topCornerRadius: CGFloat
}

public final class KeyboardAppearanceStore: ObservableObject {
    @Published public var keyboardAppearance: UIKeyboardAppearance = .default
    @Published public var hostInputFocusRevision: Int = 0

    public init(keyboardAppearance: UIKeyboardAppearance = .default) {
        self.keyboardAppearance = keyboardAppearance
    }

    public func notifyHostInputFocused() {
        hostInputFocusRevision &+= 1
    }
}

struct HostKeyboardAppearanceKey: EnvironmentKey {
    static let defaultValue: UIKeyboardAppearance = .default
}

extension EnvironmentValues {
    var hostKeyboardAppearance: UIKeyboardAppearance {
        get { self[HostKeyboardAppearanceKey.self] }
        set { self[HostKeyboardAppearanceKey.self] = newValue }
    }
}

enum KeyboardTheme {
    static func palette(for colorScheme: ColorScheme, keyboardAppearance: UIKeyboardAppearance = .default) -> KeyboardPalette {
        switch colorScheme {
        case .dark:
            let style = darkStyle(for: keyboardAppearance)
            return KeyboardPalette(
                keyboardBackground: Color(uiColor: style.keyboardBackground),
                keyboardBackgroundUIColor: style.keyboardBackground,
                controlBackground: Color(uiColor: style.controlBackground),
                controlBorder: Color.black.opacity(style.borderOpacity),
                keyBackground: Color(uiColor: style.keyBackground),
                specialKeyBackground: Color(uiColor: style.specialKeyBackground),
                keyHighlight: Color.white.opacity(0.035),
                topCornerRadius: style.topCornerRadius
            )
        default:
            return KeyboardPalette(
                keyboardBackground: .clear,
                keyboardBackgroundUIColor: .clear,
                controlBackground: Color(uiColor: .systemBackground),
                controlBorder: Color.black.opacity(0.10),
                keyBackground: Color(uiColor: .systemBackground),
                specialKeyBackground: Color(uiColor: .systemBackground),
                keyHighlight: Color.black.opacity(0.03),
                topCornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 0
            )
        }
    }

    static func nativeKeyboardBackgroundUIColor(
        for traits: UITraitCollection,
        keyboardAppearance: UIKeyboardAppearance = .default
    ) -> UIColor {
        if traits.userInterfaceStyle == .dark {
            return UIColor.clear
        } else {
            return UIColor.clear
        }
    }

    private struct DarkKeyboardStyle {
        let keyboardBackground: UIColor
        let controlBackground: UIColor
        let keyBackground: UIColor
        let specialKeyBackground: UIColor
        let borderOpacity: CGFloat
        let topCornerRadius: CGFloat
    }

    private static func darkStyle(for keyboardAppearance: UIKeyboardAppearance) -> DarkKeyboardStyle {
        switch keyboardAppearance {
        case .dark:
            return DarkKeyboardStyle(
                keyboardBackground: UIColor.clear,
                controlBackground: UIColor.secondarySystemGroupedBackground,
                keyBackground: UIColor(red: 72/255.0, green: 72/255.0, blue: 74/255.0, alpha: 1.0),
                specialKeyBackground: UIColor(red: 72/255.0, green: 72/255.0, blue: 74/255.0, alpha: 1.0),
                borderOpacity: 0.12,
                topCornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 0
            )
        default:
            return DarkKeyboardStyle(
                keyboardBackground: UIColor.clear,
                controlBackground: UIColor.secondarySystemGroupedBackground,
                keyBackground: UIColor(red: 72/255.0, green: 72/255.0, blue: 74/255.0, alpha: 1.0),
                specialKeyBackground: UIColor(red: 72/255.0, green: 72/255.0, blue: 74/255.0, alpha: 1.0),
                borderOpacity: 0.12,
                topCornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 0
            )
        }
    }

    static func palette(for traits: UITraitCollection) -> KeyboardPalette {
        palette(for: traits.userInterfaceStyle == .dark ? .dark : .light)
    }
}

private struct TopRoundedKeyboardShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        guard radius > 0 else { return Path(rect) }
        let bezierPath = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(bezierPath.cgPath)
    }
}

// Enhanced glow effect modifier for premium AI-like animations
private struct GlowEffect: ViewModifier {
    let isActive: Bool
    let isAnimating: Bool
    let color: Color
    let radius: CGFloat
    
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Bool = false
    
    func body(content: Content) -> some View {
        let cornerShape = RoundedRectangle(cornerRadius: 12)
        let gradientStops = Gradient(stops: [
            .init(color: isActive ? color.opacity(0.95) : Color.clear, location: 0.0),
            .init(color: isActive ? color.opacity(0.8) : Color.clear, location: 0.3),
            .init(color: isActive ? color.opacity(0.5) : Color.clear, location: 0.6),
            .init(color: Color.clear, location: 1.0)
        ])
        let startPt = UnitPoint(x: animationOffset - 0.3, y: 0)
        let endPt = UnitPoint(x: animationOffset + 0.3, y: 1)
        let flowingGradient = LinearGradient(gradient: gradientStops, startPoint: startPt, endPoint: endPt)
        
        return content
            .overlay(
                cornerShape
                    .stroke(flowingGradient, lineWidth: isActive ? 4 : 0)
                    .blur(radius: isActive ? 1.0 : 0)
                    .scaleEffect((isAnimating && pulseAnimation) ? 1.03 : 1.0)
                    .onAppear { startAnimations() }
                    .onChange(of: isActive) { active in
                        if active { startAnimations() } else { stopAnimations() }
                    }
                    .onChange(of: isAnimating) { anim in
                        if anim {
                            startAnimations()
                        } else {
                            stopAnimations()
                        }
                    }
                    .allowsHitTesting(false) // purely visual; don't block taps
            )
            .overlay(
                cornerShape
                    .stroke(isActive ? color.opacity(0.4) : Color.clear, lineWidth: isActive ? 6 : 0)
                    .blur(radius: isActive ? 3.0 : 0)
                    .scaleEffect((isAnimating && pulseAnimation) ? 1.05 : 1.0)
                    .allowsHitTesting(false) // purely visual; don't block taps
            )
            .animation(.easeInOut(duration: 0.3), value: isActive)
    }
    
    private func startAnimations() {
        guard isActive else { return }
        guard isAnimating else {
            stopAnimations()
            return
        }
        // Flowing animation
        animationOffset = -0.3
        withAnimation(
            .linear(duration: 2.0)
            .repeatForever(autoreverses: false)
        ) {
            animationOffset = 1.3
        }
        // Pulse animation
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            pulseAnimation = true
        }
    }
    
    private func stopAnimations() {
        animationOffset = 0
        pulseAnimation = false
    }
}

private extension View {
    func glow(isActive: Bool, isAnimating: Bool = true, color: Color = .accentColor, radius: CGFloat = 12) -> some View {
        modifier(GlowEffect(isActive: isActive, isAnimating: isAnimating, color: color, radius: radius))
    }
}

// Premium error display component
private struct PremiumErrorView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Error")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.8),
                            Color.red.opacity(0.9)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
}

private struct FocusGradientOverlay: View {
    let isActive: Bool
    var body: some View {
        let colors: [Color] = [Color.clear, Color.accentColor.opacity(0.18), Color.clear]
        let gradient = LinearGradient(gradient: Gradient(colors: colors), startPoint: .leading, endPoint: .trailing)
        return gradient
            .opacity(isActive ? 1 : 0)
            .animation(.easeInOut(duration: 0.35), value: isActive)
            .allowsHitTesting(false) // purely visual; don't block taps
    }
}

private struct ShimmerView: View {
    @State private var phase: CGFloat = -200

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.4),
                        Color.gray.opacity(0.2)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask(
                Rectangle()
                    .fill(Color.white)
                    .opacity(0.8)
                    .offset(x: phase)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 200
                }
            }
    }
}

private struct TranslationPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

    var body: some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.vertical, 8)
                .padding(.horizontal, 13)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : palette.controlBackground)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : palette.controlBorder, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

private struct KeyboardSearchBarView: View {
    @Binding var query: String
    @Binding var selectedRange: NSRange
    @Binding var textFieldRef: UITextField?
    var isFocused: FocusState<Bool>.Binding
    @Binding var isUserTyping: Bool

    let suppressesSystemKeyboard: Bool
    let isListening: Bool
    let onActivate: () -> Void
    let onDeactivate: () -> Void
    let onShowFormat: () -> Void
    let onTapMic: () -> Void
    let onTapSearch: () -> Void

    @State private var typingWorkItem: DispatchWorkItem? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

    var body: some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
        let focusedBinding = Binding<Bool>(
            get: { isFocused.wrappedValue },
            set: { isFocused.wrappedValue = $0 }
        )
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))

                if suppressesSystemKeyboard {
                    KeyboardQueryTextField(
                        text: $query,
                        selectedRange: $selectedRange,
                        isFocused: focusedBinding,
                        textFieldRef: $textFieldRef,
                        placeholder: "John 3:16 or Jn 3:16",
                        fontSize: 14,
                        suppressesSystemKeyboard: true,
                        onReturn: onTapSearch,
                        onFocusChanged: { focused in
                            if focused { onActivate() } else { onDeactivate() }
                        }
                    )
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField("John 3:16 or Jn 3:16", text: $query)
                        .transaction { $0.disablesAnimations = true }
                        .font(.system(size: 14, weight: .medium))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused(isFocused)
                        .onChange(of: isFocused.wrappedValue) { _, focused in
                            if focused { onActivate() } else { onDeactivate() }
                        }
                }
            }
            .onChange(of: query) { _ in
                isUserTyping = true
                typingWorkItem?.cancel()
                let work = DispatchWorkItem { isUserTyping = false }
                typingWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(palette.controlBackground)
            )
            .animation(nil, value: query)
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(isFocused.wrappedValue ? Color.accentColor.opacity(0.4) : palette.controlBorder, lineWidth: 0.8)
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .id("vk_search_row_stable")
    }
}

private struct KeyboardQueryTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var isFocused: Bool
    @Binding var textFieldRef: UITextField?

    let placeholder: String
    let fontSize: CGFloat
    let suppressesSystemKeyboard: Bool
    let onReturn: () -> Void
    let onFocusChanged: (Bool) -> Void

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize {
        let width = proposal.width ?? uiView.bounds.width
        return CGSize(width: width, height: 38)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.clearButtonMode = .never
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.returnKeyType = .search
        textField.enablesReturnKeyAutomatically = false
        textField.font = .systemFont(ofSize: fontSize, weight: .medium)
        textField.textColor = .label
        textField.tintColor = .systemBlue
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.secondaryLabel]
        )
        textField.text = text
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if suppressesSystemKeyboard {
            textField.inputView = UIView(frame: .zero)
            textField.inputAccessoryView = UIView(frame: .zero)
        }
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        textFieldRef = textField
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self

        if !context.coordinator.isEditing && uiView.text != text {
            uiView.text = text
        }

        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: KeyboardQueryTextField
        var isEditing = false

        init(parent: KeyboardQueryTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ sender: UITextField) {
            isEditing = true
            parent.text = sender.text ?? ""
            parent.selectedRange = sender.currentSelectedRange
            DispatchQueue.main.async { self.isEditing = false }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused {
                parent.isFocused = true
            }
            parent.selectedRange = textField.currentSelectedRange
            parent.onFocusChanged(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused {
                parent.isFocused = false
            }
            parent.selectedRange = textField.currentSelectedRange
            parent.onFocusChanged(false)
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.selectedRange = textField.currentSelectedRange
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onReturn()
            return false
        }
    }
}

extension UITextField {
    var currentSelectedRange: NSRange {
        guard let selectedTextRange else {
            return NSRange(location: (text ?? "").utf16.count, length: 0)
        }

        let location = offset(from: beginningOfDocument, to: selectedTextRange.start)
        let length = offset(from: selectedTextRange.start, to: selectedTextRange.end)
        return NSRange(location: location, length: length)
    }

    func setSelectedRange(_ range: NSRange) {
        let textLength = (text ?? "").utf16.count
        let location = min(max(range.location, 0), textLength)
        let length = min(max(range.length, 0), textLength - location)

        guard
            let start = position(from: beginningOfDocument, offset: location),
            let end = position(from: start, offset: length)
        else { return }

        selectedTextRange = textRange(from: start, to: end)
    }
}

private struct SearchResultsContainerView: View {
    private let horizontalInset: CGFloat = 14

    let isLoading: Bool
    let resultText: String?
    let resultReference: String?
    let translationCode: String
    let onInsert: () -> Void

    var body: some View {
        Group {
            if isLoading {
                GeometryReader { geo in
                    let cardHeight = min(max(geo.size.height - 22, 110), 148)

                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.accentColor)
                            Text("Loading verse")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, horizontalInset)

                        PremiumKeyboardLoadingCard(height: cardHeight)
                            .padding(.horizontal, horizontalInset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            } else if let text = resultText, let reference = resultReference {
                ScrollView {
                    PremiumVerseCard(
                        text: text,
                        reference: reference,
                        translationCode: translationCode,
                        onTap: { onInsert() }
                    )
                    .frame(maxWidth: .infinity)
                    .glow(isActive: true, color: .accentColor)
                    .padding(.horizontal, horizontalInset)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 320)
            } else {
                EmptyView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

private struct ToolbarIconButton: View {
    let systemName: String
    let width: CGFloat
    let isHighlighted: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

    var body: some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                .frame(width: width, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isHighlighted ? Color.accentColor : palette.controlBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isHighlighted ? Color.accentColor.opacity(0.4) : palette.controlBorder, lineWidth: 0.6)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct TranslationDropdownButton: View {
    let title: String
    let width: CGFloat
    let isExpanded: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

    var body: some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.primary)
            .frame(width: width, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.controlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(palette.controlBorder, lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TranslationSelectorRow: View {
    let translations: [Translation]
    let selectedTranslation: Translation
    let onSelectTranslation: (Translation) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

    var body: some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(translations, id: \.self) { translation in
                    TranslationPill(
                        title: translation.displayCode,
                        isSelected: selectedTranslation == translation,
                        action: { onSelectTranslation(translation) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.controlBorder.opacity(0.8), lineWidth: 0.6)
        )
    }
}

private struct CompactLoadingCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance
    var body: some View {
        GeometryReader { geo in
            let availableHeight = max(geo.size.height, 0)
            let cardHeight = min(max(availableHeight - 12, 84), 136)
            let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)

            if availableHeight < 92 {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                        .frame(height: 12)
                        .overlay(
                            ShimmerView()
                                .mask(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .frame(height: 12)
                                )
                        )
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.controlBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(palette.controlBorder.opacity(0.8), lineWidth: 0.6)
                )
                .padding(.horizontal, 12)
            } else {
                PremiumKeyboardLoadingCard(height: cardHeight)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

private struct PremiumKeyboardLoadingCard: View {
    let height: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance
    @State private var beamOffset: CGFloat = -220
    @State private var haloPulse = false

    var body: some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
        let cardBackground = colorScheme == .dark
            ? palette.controlBackground.opacity(0.96)
            : Color.white.opacity(0.98)
        let skeletonBase = colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.08)
        let haloBlue = colorScheme == .dark
            ? Color.accentColor.opacity(0.22)
            : Color.accentColor.opacity(0.14)

        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardBackground)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            haloBlue.opacity(0.15),
                            Color.clear,
                            Color.blue.opacity(colorScheme == .dark ? 0.16 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(haloBlue)
                .frame(width: height * 0.92, height: height * 0.92)
                .blur(radius: 34)
                .offset(x: -height * 0.22, y: -height * 0.08)

            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.18 : 0.12))
                .frame(width: height * 0.72, height: height * 0.72)
                .blur(radius: 28)
                .offset(x: height * 0.28, y: height * 0.16)

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(colorScheme == .dark ? 0.14 : 0.22),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .offset(x: beamOffset)
            )
            .blur(radius: 18)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    loadingLine(width: min(max(height * 1.05, 118), 146), height: 14, fill: skeletonBase)

                    Spacer(minLength: 6)

                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.accentColor.opacity(0.88))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.10))
                        )
                }

                loadingLine(width: nil, height: 12, fill: skeletonBase)
                loadingLine(width: min(max(height * 1.3, 166), 228), height: 12, fill: skeletonBase)
                loadingLine(width: min(max(height * 0.96, 128), 172), height: 12, fill: skeletonBase)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.22),
                            palette.controlBorder.opacity(0.8),
                            Color.blue.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: haloPulse ? 1.2 : 0.8
                )
        )
        .shadow(color: Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.08), radius: haloPulse ? 18 : 12, x: 0, y: 8)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .onAppear {
            beamOffset = -220
            haloPulse = false
            withAnimation(.linear(duration: 1.65).repeatForever(autoreverses: false)) {
                beamOffset = 220
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                haloPulse = true
            }
        }
    }

    @ViewBuilder
    private func loadingLine(width: CGFloat?, height: CGFloat, fill: Color) -> some View {
        let line = RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
            .frame(width: width, height: height)
            .overlay(
                ShimmerView()
                    .mask(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .frame(width: width, height: height)
                    )
            )

        if let width {
            line
        } else {
            line.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct InlineVerseInsertCard: View {
    let reference: String
    let preview: String
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

    private var cleanedReference: String {
        reference.replacingOccurrences(of: " 📖", with: "")
    }

    var body: some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "book.closed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(cleanedReference)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("Tap to insert")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(preview)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.controlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.controlBorder.opacity(0.75), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TranslationOverlayPanel: View {
    let translations: [Translation]
    let selectedTranslation: Translation
    let onSelectTranslation: (Translation) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(translations, id: \.self) { translation in
                    Button(action: { onSelectTranslation(translation) }) {
                        Text(translation.displayCode)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedTranslation == translation ? .white : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selectedTranslation == translation ? Color.accentColor : palette.controlBackground.opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .frame(width: 220, height: 128)
        .background {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.keyboardBackground)
                    .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThickMaterial)
                    .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? palette.controlBorder.opacity(0.9) : Color.black.opacity(0.08), lineWidth: 0.6)
        )
    }
}

private struct CompactBibleToolbarView: View {
    @Binding var query: String
    @Binding var selectedRange: NSRange
    @Binding var isSearchFocused: Bool
    @Binding var textFieldRef: UITextField?
    let selectedTranslationCode: String
    let isTranslationSelectorVisible: Bool
    let isSearchActive: Bool
    let onTapSearch: () -> Void
    let onClearSearch: () -> Void
    let onSubmitSearch: () -> Void
    let onTapBrowse: () -> Void
    let onTapTranslation: () -> Void

    private let iconButtonWidth: CGFloat = 44
    private let versionButtonWidth: CGFloat = 74
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

    var body: some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)

                if isSearchActive {
                    KeyboardQueryTextField(
                        text: $query,
                        selectedRange: $selectedRange,
                        isFocused: $isSearchFocused,
                        textFieldRef: $textFieldRef,
                        placeholder: "John 3:16 or keyword",
                        fontSize: 16,
                        suppressesSystemKeyboard: true,
                        onReturn: onSubmitSearch,
                        onFocusChanged: { focused in
                            if focused {
                                onTapSearch()
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                } else {
                    Text(query.isEmpty ? "John 3:16 or keyword" : query)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(query.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                if isSearchActive && !query.isEmpty {
                    Button(action: onClearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(palette.controlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSearchActive ? Color.accentColor.opacity(0.42) : palette.controlBorder, lineWidth: 0.6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .onTapGesture(perform: onTapSearch)

            ToolbarIconButton(systemName: "books.vertical.fill", width: iconButtonWidth, isHighlighted: false, action: onTapBrowse)

            TranslationDropdownButton(
                title: selectedTranslationCode,
                width: versionButtonWidth,
                isExpanded: isTranslationSelectorVisible,
                action: onTapTranslation
            )
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
    }
}

private struct ExpandedBibleHeaderView: View {
    private let horizontalInset: CGFloat = 12

    let leadingSystemName: String
    let title: String
    let utilitySystemName: String
    let selectedTranslationCode: String
    let isTranslationSelectorVisible: Bool
    let onLeadingTap: () -> Void
    let onUtilityTap: () -> Void
    let onTapTranslation: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ToolbarIconButton(systemName: leadingSystemName, width: 40, isHighlighted: false, action: onLeadingTap)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            ToolbarIconButton(systemName: utilitySystemName, width: 40, isHighlighted: false, action: onUtilityTap)

            TranslationDropdownButton(
                title: selectedTranslationCode,
                width: 64,
                isExpanded: isTranslationSelectorVisible,
                action: onTapTranslation
            )
        }
        .padding(.horizontal, horizontalInset)
    }
}

private struct ContentSearchResultsView: View {
    let results: [KeyboardViewModel.VerseResult]
    let onTapResult: (Int) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

    var body: some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 6) {
                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                    Button(action: { onTapResult(index) }) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .frame(width: 26, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.12))
                                )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.referenceLabel.replacingOccurrences(of: " 📖", with: ""))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("Tap to insert")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(result.previewText)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(palette.controlBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(palette.controlBorder.opacity(0.75), lineWidth: 0.6)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

public struct KeyboardView: View {
    private enum ShellMode: Equatable {
        case compact
        case expandedSearch
        case expandedBrowse
        case expandedResult
    }

    @StateObject private var vm: KeyboardViewModel
    @FocusState private var isSearchFieldFocused: Bool
//    @AppStorage("lastTranslation") private var lastTranslationRaw: String = Translation.niv.rawValue

    @State private var showFormatSheet: Bool = false
    @State private var shellMode: ShellMode = .compact
    @State private var showsTranslationSelector: Bool = false
    @State private var isUserTyping: Bool = false
    @State private var isCompactSearchFocused: Bool = true
    @State private var activeSearchTextField: UITextField?
    @ObservedObject private var appearanceStore: KeyboardAppearanceStore
    @Environment(\.colorScheme) private var colorScheme

    private let inserter: InsertPipeline
    private let suppressesSystemKeyboard: Bool
    private let onGlobe: () -> Void
    private let onDismissKeyboard: () -> Void

    private let keyboardHeight: CGFloat
    private let compactKeyboardSurfaceHeight: CGFloat
    private let keyboardSurfaceHeight: CGFloat
    private let overlayContentHeight: CGFloat

    private static func computeHeights() -> (total: CGFloat, compactSurface: CGFloat, surface: CGFloat, overlay: CGFloat) {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let total: CGFloat = isPad ? 330 : 260
        let toolbarHeight: CGFloat = 44
        let compactSurface = total - toolbarHeight
        let surface = compactSurface + 8
        let overlay = surface - 2
        return (total, compactSurface, surface, overlay)
    }

    public init(
        inserter: InsertPipeline,
        suppressesSystemKeyboard: Bool = false,
        appearanceStore: KeyboardAppearanceStore = KeyboardAppearanceStore(),
        onGlobe: @escaping () -> Void = {},
        onDismissKeyboard: @escaping () -> Void = {}
    ) {
        let h = Self.computeHeights()
        self._vm = StateObject(wrappedValue: KeyboardViewModel(inserter: inserter, settings: SettingsStore()))
        self.appearanceStore = appearanceStore
        self.inserter = inserter
        self.suppressesSystemKeyboard = suppressesSystemKeyboard
        self.onGlobe = onGlobe
        self.onDismissKeyboard = onDismissKeyboard
        self.keyboardHeight = h.total
        self.compactKeyboardSurfaceHeight = h.compactSurface
        self.keyboardSurfaceHeight = h.surface
        self.overlayContentHeight = h.overlay
    }

    public var body: some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: appearanceStore.keyboardAppearance)
        ZStack {
            let isListening = (vm.uiState == .listening)
            let isLoading = isExpandedLoading

            Group {
                VStack(alignment: .leading, spacing: 6) {
                    switch shellMode {
                    case .compact:
                        compactModeView
                    case .expandedSearch:
                        expandedSearchMode
                    case .expandedBrowse:
                        expandedBrowseMode
                    case .expandedResult:
                        expandedResultMode(isLoading: isLoading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(nil, value: vm.uiState)
            .animation(nil, value: vm.mode)
            .animation(nil, value: vm.presentation)
            .animation(nil, value: vm.selectedTranslation)
            .blur(radius: isListening ? 8 : 0)
            .opacity(isListening ? 0.92 : 1.0)
            .allowsHitTesting(!isListening)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if vm.inputFocus == .search {
                            if shellMode == .compact {
                                deactivateCompactSearchField()
                            } else {
                                deactivateSearchField()
                            }
                        }
                    }
                    .allowsHitTesting(vm.inputFocus == .search && !isListening && shellMode != .compact)
            )
            .glow(isActive: isListening, isAnimating: true, color: .accentColor)

            if isListening {
                ListeningOverlayView(
                    transcript: vm.partialTranscript ?? "",
                    cornerRadius: 0,
                    onCancel: {
                        if vm.hapticsEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        vm.onCancelVoice()
                    },
                    onSend: {
                        if vm.hapticsEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        vm.onSendVoice()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .zIndex(999)
                .allowsHitTesting(true)
            }
            
            if let error = vm.errorMessage {
                VStack {
                    Spacer()
                    PremiumErrorView(message: error) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            vm.errorMessage = nil
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .zIndex(1000)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.errorMessage != nil)
            }
        }
        .frame(maxWidth: .infinity, minHeight: keyboardHeight, maxHeight: keyboardHeight, alignment: .top)
        .background(
            TopRoundedKeyboardShape(radius: palette.topCornerRadius)
                .fill(palette.keyboardBackground)
        )
        .overlay(
            TopRoundedKeyboardShape(radius: palette.topCornerRadius)
                .stroke(palette.controlBorder.opacity(0.8), lineWidth: 0.6)
        )
        .environment(\.hostKeyboardAppearance, appearanceStore.keyboardAppearance)
        .ignoresSafeArea(.all)
        .transaction { tx in tx.disablesAnimations = true }
        .onAppear {
            syncShellMode()
        }
        .onChange(of: shellMode) { _, newMode in
            if newMode != .compact {
                isCompactSearchFocused = false
            }
            if newMode == .compact {
                showsTranslationSelector = false
                deactivateSearchField()
                if !isCompactSearchFocused {
                    vm.releaseToHost()
                }
            }
        }
        .onChange(of: vm.uiState) { _, _ in
            syncShellMode()
        }
        .onChange(of: vm.mode) { _, _ in
            syncShellMode()
        }
        .onChange(of: vm.searchResult?.referenceLabel) { _, _ in
            syncShellMode()
        }
        .onChange(of: appearanceStore.hostInputFocusRevision) { _, _ in
            releaseKeyboardFocusToHost()
        }
        .onChange(of: vm.browseResult?.referenceLabel) { _, _ in
            syncShellMode()
        }
        .onChange(of: vm.isShowingContentResults) { _, _ in
            syncShellMode()
        }
        .sheet(isPresented: $showFormatSheet) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Insert Format")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Choose how to insert Bible verses")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // Format Options
                        VStack(spacing: 16) {
                            ForEach(InsertFormat.allCases, id: \.self) { formatOption in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        vm.setInsertFormat(formatOption)
                                    }
                                }) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(label(for: formatOption))
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                                .multilineTextAlignment(.leading)
                                            
                                            Text(description(for: formatOption))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(2)
                                        }
                                        
                                        Spacer()
                                        
                                        if vm.insertFormat == formatOption {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                                .font(.body.weight(.semibold))
                                                .scaleEffect(1.1)
                                        }
                                    }
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(vm.insertFormat == formatOption ?
                                                Color.accentColor.opacity(0.1) :
                                                Color(UIColor.secondarySystemGroupedBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(vm.insertFormat == formatOption ?
                                                        Color.accentColor.opacity(0.3) :
                                                        Color.clear, lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .scaleEffect(vm.insertFormat == formatOption ? 1.02 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: vm.insertFormat == formatOption)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Bottom spacer
                        Color.clear
                            .frame(height: 20)
                    }
                }
                .navigationTitle("Format")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showFormatSheet = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.height(350), .medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(16)
        }
        .overlay(alignment: .topTrailing) {
            if showsTranslationSelector {
                TranslationOverlayPanel(
                    translations: vm.availableTranslations,
                    selectedTranslation: vm.selectedTranslation,
                    onSelectTranslation: { translation in
                        showsTranslationSelector = false
                        vm.onSelectTranslation(translation)
                    }
                )
                .padding(.top, translationOverlayTopPadding)
                .padding(.trailing, 12)
                .zIndex(2000)
            }
        }
    }

    // MARK: - Enhanced Cursor Management Functions

    private var isExpandedLoading: Bool {
        vm.uiState == .loadingSearch || vm.uiState == .loadingTranslationSwitch || vm.uiState == .processingVoice
    }

    private var keyboardOwnsQueryInput: Bool {
        shellMode == .compact ? isCompactSearchFocused : vm.inputFocus == .search
    }

    private var isCompactSearchActive: Bool {
        shellMode == .compact && keyboardOwnsQueryInput
    }

    private var isCompactSearchLoadingOrResult: Bool {
        shellMode == .compact && vm.mode == .search && (isExpandedLoading || vm.searchResult != nil || vm.isShowingContentResults)
    }

    private var compactModeView: some View {
        VStack(spacing: 0) {
            CompactBibleToolbarView(
                query: $vm.query,
                selectedRange: $vm.querySelectedRange,
                isSearchFocused: $isCompactSearchFocused,
                textFieldRef: $activeSearchTextField,
                selectedTranslationCode: vm.selectedTranslation.displayCode,
                isTranslationSelectorVisible: showsTranslationSelector,
                isSearchActive: isCompactSearchActive,
                onTapSearch: { activateCompactSearchField() },
                onClearSearch: { clearQueryInput() },
                onSubmitSearch: { submitCompactSearch() },
                onTapBrowse: { enterExpandedBrowse() },
                onTapTranslation: { toggleTranslationSelector() }
            )
            .padding(.top, 4)
            .padding(.bottom, 8)

            if isCompactSearchLoadingOrResult {
                compactSearchSurface
            } else if isCompactSearchActive {
                compactSearchKeyboardSurface
            } else {
                hostKeyboardSurface
            }
        }
        .padding(.top, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var expandedSearchMode: some View {
        VStack(spacing: 6) {
            ExpandedBibleHeaderView(
                leadingSystemName: "keyboard.chevron.compact.down",
                title: vm.searchResult == nil ? (vm.isShowingContentResults ? "Search Results" : "Search Bible") : (cleanedReference(vm.searchResult?.referenceLabel) ?? "Verse Result"),
                utilitySystemName: "books.vertical",
                selectedTranslationCode: vm.selectedTranslation.displayCode,
                isTranslationSelectorVisible: showsTranslationSelector,
                onLeadingTap: { handleSearchLeadingAction() },
                onUtilityTap: { enterExpandedBrowse() },
                onTapTranslation: { toggleTranslationSelector() }
            )
            .frame(height: 40)

            if vm.searchResult != nil {
                InlineVerseInsertCard(
                    reference: vm.searchResult?.referenceLabel ?? "",
                    preview: vm.searchResult?.previewText ?? "",
                    onTap: { handleResultInsertion() }
                )
                .frame(height: 56)
            } else if isExpandedLoading {
                CompactLoadingCard()
                    .frame(height: 56)
            } else {
                KeyboardSearchBarView(
                    query: $vm.query,
                    selectedRange: $vm.querySelectedRange,
                    textFieldRef: $activeSearchTextField,
                    isFocused: $isSearchFieldFocused,
                    isUserTyping: $isUserTyping,
                    suppressesSystemKeyboard: suppressesSystemKeyboard,
                    isListening: vm.uiState == .listening,
                    onActivate: { activateSearchField() },
                    onDeactivate: { deactivateSearchField() },
                    onShowFormat: { showFormatSheet = true },
                    onTapMic: { vm.onTapMic() },
                    onTapSearch: { submitExpandedSearch() }
                )
                .frame(height: 38)
            }

            if vm.isShowingContentResults && !vm.contentSearchResults.isEmpty {
                ContentSearchResultsView(
                    results: vm.contentSearchResults,
                    onTapResult: { index in vm.onTapContentSearchResult(at: index) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                searchKeyboardSurface
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var expandedBrowseMode: some View {
        VStack(spacing: 6) {
            ExpandedBibleHeaderView(
                leadingSystemName: browseLeadingSystemName,
                title: browseNavigationTitle,
                utilitySystemName: "magnifyingglass",
                selectedTranslationCode: vm.selectedTranslation.displayCode,
                isTranslationSelectorVisible: showsTranslationSelector,
                onLeadingTap: { handleBrowseLeadingAction() },
                onUtilityTap: { enterExpandedSearch() },
                onTapTranslation: { toggleTranslationSelector() }
            )
            .frame(height: 40)

            Group {
                if isExpandedLoading {
                    CompactLoadingCard()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 12)
                } else {
                    BrowseView(
                        selectedBook: vm.selectedBook,
                        selectedChapter: vm.selectedChapter,
                        verseCount: vm.currentChapterVerseCount,
                        translation: vm.selectedTranslation,
                        onSelectBook: { book in vm.onBrowseSelectBook(book.name) },
                        onSelectChapter: { ch in vm.onBrowseSelectChapter(ch) },
                        onSelectVerse: { v in vm.onBrowseSelectVerse(v) },
                        onBackToBooks: { vm.onBrowseSelectBook("") },
                        onBackToChapters: { vm.onBrowseSelectChapter(0) },
                        isMultiSelectEnabled: vm.isMultiSelectEnabled,
                        selectedVerses: vm.selectedVersesSet,
                        onToggleMultiSelect: { vm.onToggleMultiSelect() },
                        onFetchSelected: { vm.onFetchSelectedVerses() },
                        onFetchWholeChapter: { vm.onFetchWholeChapter() },
                        isWholeChapterMode: vm.isWholeChapterMode,
                        onToggleWholeChapterMode: { vm.onToggleWholeChapterMode() },
                        showsSelectionHeader: false
                    )
                }
            }
            .frame(height: overlayContentHeight, alignment: .top)
        }
    }

    private func expandedResultMode(isLoading: Bool) -> some View {
        VStack(spacing: 6) {
            ExpandedBibleHeaderView(
                leadingSystemName: "chevron.left",
                title: resultNavigationTitle(isLoading: isLoading),
                utilitySystemName: "magnifyingglass",
                selectedTranslationCode: vm.selectedTranslation.displayCode,
                isTranslationSelectorVisible: showsTranslationSelector,
                onLeadingTap: { returnFromExpandedResult() },
                onUtilityTap: { enterExpandedSearch() },
                onTapTranslation: { toggleTranslationSelector() }
            )
            .frame(height: 40)

            Group {
                if isLoading {
                    CompactLoadingCard()
                        .padding(.top, 12)
                } else {
                    SearchResultsContainerView(
                        isLoading: false,
                        resultText: vm.browseResult?.previewText,
                        resultReference: vm.browseResult?.referenceLabel,
                        translationCode: vm.selectedTranslation.displayCode,
                        onInsert: { handleResultInsertion() }
                    )
                }
            }
            .frame(height: overlayContentHeight, alignment: .top)
        }
    }

    private var currentReturnKeyTitle: String {
        if isCompactSearchFocused || isSearchFieldFocused {
            return "Search"
        }
        return ""
    }

    private var hostKeyboardSurface: some View {
        SystemLikeKeyboardView(
            onInsert: { str in
                inserter.insert(str)
            },
            onDelete: {
                inserter.deleteBackward()
            },
            onReturn: {
                inserter.insert("\n")
            },
            onMoveCursor: { offset in
                inserter.moveCursor(by: offset)
            },
            onGlobe: onGlobe,
            onMic: {},
            onDismissKeyboard: onDismissKeyboard,
            returnKeyTitle: currentReturnKeyTitle,
            hapticsEnabled: vm.hapticsEnabled
        )
        .frame(maxWidth: .infinity)
        .layoutPriority(2)
    }

    private var compactSearchKeyboardSurface: some View {
        SystemLikeKeyboardView(
            onInsert: { str in
                replaceQuerySelection(with: str)
            },
            onDelete: {
                deleteBackwardInQuery()
            },
            onReturn: {
                submitCompactSearch()
            },
            onMoveCursor: { offset in
                moveQueryCursor(by: offset)
            },
            onGlobe: onGlobe,
            onMic: {},
            onDismissKeyboard: onDismissKeyboard,
            returnKeyTitle: currentReturnKeyTitle,
            hapticsEnabled: vm.hapticsEnabled
        )
        .animation(nil, value: vm.query)
        .animation(nil, value: vm.selectedTranslation)
        .frame(maxWidth: .infinity)
        .layoutPriority(2)
    }

    private var compactSearchSurface: some View {
        Group {
            if vm.isShowingContentResults && !vm.contentSearchResults.isEmpty {
                ContentSearchResultsView(
                    results: vm.contentSearchResults,
                    onTapResult: { index in vm.onTapContentSearchResult(at: index) }
                )
                .frame(maxWidth: .infinity)
            } else if isExpandedLoading {
                SearchResultsContainerView(
                    isLoading: true,
                    resultText: nil,
                    resultReference: nil,
                    translationCode: vm.selectedTranslation.displayCode,
                    onInsert: {}
                )
            } else {
                SearchResultsContainerView(
                    isLoading: false,
                    resultText: vm.searchResult?.previewText,
                    resultReference: vm.searchResult?.referenceLabel,
                    translationCode: vm.selectedTranslation.displayCode,
                    onInsert: { handleResultInsertion() }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: compactKeyboardSurfaceHeight)
        .padding(.horizontal, 2)
    }

    private var searchKeyboardSurface: some View {
        SystemLikeKeyboardView(
            onInsert: { str in
                replaceQuerySelection(with: str)
            },
            onDelete: {
                deleteBackwardInQuery()
            },
            onReturn: {
                submitExpandedSearch()
            },
            onMoveCursor: { offset in
                moveQueryCursor(by: offset)
            },
            onGlobe: onGlobe,
            onMic: {},
            onDismissKeyboard: onDismissKeyboard,
            returnKeyTitle: currentReturnKeyTitle,
            hapticsEnabled: vm.hapticsEnabled
        )
        .animation(nil, value: vm.query)
        .animation(nil, value: vm.selectedTranslation)
        .frame(maxWidth: .infinity)
        .frame(height: keyboardSurfaceHeight)
        .padding(.horizontal, 2)
        .layoutPriority(2)
        .id("keyboardSearchInput")
    }

    private var browseLeadingSystemName: String {
        if vm.selectedBook == nil && vm.selectedChapter == nil {
            return "keyboard.chevron.compact.down"
        }
        return "chevron.left"
    }

    private var browseNavigationTitle: String {
        if let chapter = vm.selectedChapter, let book = vm.selectedBook {
            return "\(book) \(chapter)"
        }
        if let book = vm.selectedBook {
            return book
        }
        return "Browse Bible"
    }

    private func resultNavigationTitle(isLoading: Bool) -> String {
        if isLoading {
            return "Loading selection"
        }
        return cleanedReference(vm.browseResult?.referenceLabel) ?? browseNavigationTitle
    }

    private func cleanedReference(_ reference: String?) -> String? {
        guard let reference else { return nil }
        return reference.replacingOccurrences(of: " 📖", with: "")
    }

    private func toggleTranslationSelector() {
        showsTranslationSelector.toggle()
    }

    private var translationOverlayTopPadding: CGFloat {
        switch shellMode {
        case .compact:
            return 50
        case .expandedSearch, .expandedBrowse, .expandedResult:
            return 48
        }
    }

    private func enterExpandedSearch() {
        showsTranslationSelector = false
        shellMode = .compact
        activateCompactSearchField()
    }

    private func enterExpandedBrowse() {
        showsTranslationSelector = false
        deactivateCompactSearchField()
        if vm.mode != .browse {
            vm.onSwitchMode(.browse)
        }
        deactivateSearchField()
        if vm.browseResult != nil {
            shellMode = .expandedResult
        } else {
            shellMode = .expandedBrowse
        }
    }

    private func submitExpandedSearch() {
        showsTranslationSelector = false
        deactivateSearchField()
        vm.contentSearchResults = []
        vm.isShowingContentResults = false
        vm.onTapSearch()
    }

    private func activateCompactSearchField() {
        showsTranslationSelector = false
        if vm.mode != .search {
            vm.onSwitchMode(.search)
        }
        vm.searchResult = nil
        vm.contentSearchResults = []
        vm.isShowingContentResults = false
        if case .error(_) = vm.uiState {
            vm.uiState = .idle
        }
        clampQuerySelection()
        isCompactSearchFocused = true
        vm.enterSearchFocus()
        vm.maintainTypingGlow(true)
        inserter.setPassiveMode(true)
    }

    private func deactivateCompactSearchField() {
        isCompactSearchFocused = false
        vm.maintainTypingGlow(false)
        vm.releaseToHost()
        inserter.setPassiveMode(false)
    }

    private func submitCompactSearch() {
        if let tf = activeSearchTextField {
            vm.query = tf.text ?? ""
        }
        let trimmed = vm.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        showsTranslationSelector = false
        deactivateCompactSearchField()
        vm.contentSearchResults = []
        vm.isShowingContentResults = false
        vm.onTapSearch()
    }

    private func handleSearchLeadingAction() {
        if vm.isShowingContentResults && !vm.contentSearchResults.isEmpty {
            vm.contentSearchResults = []
            vm.isShowingContentResults = false
            vm.searchResult = nil
            vm.uiState = .idle
            activateSearchField()
            return
        }
        if vm.searchResult != nil {
            vm.searchResult = nil
            vm.uiState = .idle
            activateSearchField()
            return
        }
        collapseToCompact()
    }

    private func handleBrowseLeadingAction() {
        if vm.selectedChapter != nil {
            vm.onBrowseSelectChapter(0)
            return
        }

        if vm.selectedBook != nil {
            vm.onBrowseSelectBook("")
            return
        }

        collapseToCompact()
    }

    private func returnFromExpandedResult() {
        showsTranslationSelector = false

        if isExpandedLoading {
            vm.fetchTask?.cancel()
            vm.uiState = .idle
        }

        vm.browseResult = nil
        shellMode = .expandedBrowse
        deactivateSearchField()
    }

    private func handleResultInsertion() {
        vm.onTapResultCardToInsert()
        vm.searchResult = nil
        vm.browseResult = nil
        vm.contentSearchResults = []
        vm.isShowingContentResults = false
        vm.uiState = .idle
        vm.presentation = .typing
        collapseToCompact()
    }

    private func collapseToCompact() {
        showsTranslationSelector = false
        isCompactSearchFocused = false
        shellMode = .compact
    }

    private func releaseKeyboardFocusToHost() {
        guard vm.inputFocus == .search || isCompactSearchFocused || isSearchFieldFocused else { return }
        isCompactSearchFocused = false
        isSearchFieldFocused = false
        vm.maintainTypingGlow(false)
        vm.releaseToHost()
        inserter.setPassiveMode(false)
    }

    private func syncShellMode() {
        if vm.mode == .search {
            if vm.isShowingContentResults && !vm.contentSearchResults.isEmpty {
                shellMode = .expandedSearch
            } else if shellMode != .compact {
                shellMode = .compact
            }
            return
        }

        guard shellMode != .compact else { return }

        if vm.browseResult != nil {
            shellMode = .expandedResult
        } else {
            shellMode = .expandedBrowse
        }
    }

    private func activateSearchField() {
        clampQuerySelection()
        isSearchFieldFocused = true
        vm.enterSearchFocus()
        vm.maintainTypingGlow(true)
        inserter.setPassiveMode(true)
    }
    
    private func deactivateSearchField() {
        isSearchFieldFocused = false
        vm.maintainTypingGlow(false)
        vm.releaseToHost()
        inserter.setPassiveMode(false)
    }

    private func clearQueryInput() {
        if let tf = activeSearchTextField {
            tf.text = ""
            tf.setSelectedRange(NSRange(location: 0, length: 0))
        }
        vm.query = ""
        vm.contentSearchResults = []
        vm.isShowingContentResults = false
        vm.querySelectedRange = NSRange(location: 0, length: 0)
    }

    private func replaceQuerySelection(with replacement: String) {
        if let tf = activeSearchTextField {
            let current = (tf.text ?? "") as NSString
            let range = tf.currentSelectedRange
            let newString = current.replacingCharacters(in: range, with: replacement)
            let newRange = NSRange(location: range.location + (replacement as NSString).length, length: 0)
            tf.text = newString
            tf.setSelectedRange(newRange)
            vm.query = newString
            vm.querySelectedRange = newRange
        } else {
            let current = vm.query as NSString
            let range = clampedQueryRange(vm.querySelectedRange)
            vm.query = current.replacingCharacters(in: range, with: replacement)
            vm.querySelectedRange = NSRange(location: range.location + (replacement as NSString).length, length: 0)
        }
    }

    private func deleteBackwardInQuery() {
        if let tf = activeSearchTextField {
            let current = (tf.text ?? "") as NSString
            var range = tf.currentSelectedRange

            if range.length == 0 {
                guard range.location > 0 else { return }
                range = NSRange(location: range.location - 1, length: 1)
            }

            let newString = current.replacingCharacters(in: range, with: "")
            let newRange = NSRange(location: range.location, length: 0)
            tf.text = newString
            tf.setSelectedRange(newRange)
            vm.query = newString
            vm.querySelectedRange = newRange
        } else {
            let current = vm.query as NSString
            var range = clampedQueryRange(vm.querySelectedRange)

            if range.length == 0 {
                guard range.location > 0 else { return }
                range = NSRange(location: range.location - 1, length: 1)
            }

            vm.query = current.replacingCharacters(in: range, with: "")
            vm.querySelectedRange = NSRange(location: range.location, length: 0)
        }
    }

    private func moveQueryCursor(by offset: Int) {
        if let tf = activeSearchTextField, let start = tf.selectedTextRange?.start {
            if let newPos = tf.position(from: start, offset: offset) {
                tf.selectedTextRange = tf.textRange(from: newPos, to: newPos)
            }
            vm.query = tf.text ?? ""
            vm.querySelectedRange = tf.currentSelectedRange
        } else {
            let currentLength = vm.query.utf16.count
            let currentLocation = clampedQueryRange(vm.querySelectedRange).location
            let newLocation = min(max(currentLocation + offset, 0), currentLength)
            vm.querySelectedRange = NSRange(location: newLocation, length: 0)
        }
    }

    private func clampQuerySelection() {
        vm.querySelectedRange = clampedQueryRange(vm.querySelectedRange)
    }

    private func clampedQueryRange(_ range: NSRange) -> NSRange {
        let currentLength = vm.query.utf16.count
        let location = min(max(range.location, 0), currentLength)
        let length = min(max(range.length, 0), currentLength - location)
        return NSRange(location: location, length: length)
    }

    private func label(for format: InsertFormat) -> String {
        switch format {
        case .textOnly: return "Text only"
        case .textAndReference: return "Text + Reference"
        case .referenceOnly: return "Reference only"
        }
    }
    
    private func description(for format: InsertFormat) -> String {
        switch format {
        case .textOnly: return "Insert only the verse text"
        case .textAndReference: return "Insert verse text with reference"
        case .referenceOnly: return "Insert only the reference"
        }
    }
}

