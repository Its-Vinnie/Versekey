import SwiftUI
import AVFoundation
import UIKit

private let DEBUG_POPUP_BINARY_TEST: Bool = false

private struct KeyPopupTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

public struct SystemLikeKeyboardView: View {
    public enum KeyboardLayer { case letters, numbers, symbols, emojis }
    
    public let onInsert: (String) -> Void
    public let onDelete: () -> Void
    public let onReturn: () -> Void
    public let onMoveCursor: (Int) -> Void
    public let onGlobe: () -> Void
    public let onMic: () -> Void
    public let onDismissKeyboard: () -> Void
    public let returnKeyTitle: String
    public let hapticsEnabled: Bool
    
    @State private var layer: KeyboardLayer = .letters
    @State private var isShiftOn: Bool = false
    @State private var deleteTimer: Timer? = nil
    @State private var isLongPressing: Bool = false
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance
    @Environment(\.colorScheme) private var colorScheme
    
    private let deleteRepeatInterval = 0.1
    private let longPressDelay = 0.5
    private let soundEnabled = true
    
    private static let hapticGenerator: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        return g
    }()
    private static let rigidHapticGenerator: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.prepare()
        return g
    }()
    
    // MARK: - Constants

    private let baseKeyboardHeight: CGFloat = 208
    private let baseKeyHeight: CGFloat = 46
    private let baseKeyGap: CGFloat = 6
    private let minimumBottomInset: CGFloat = 5
    private let baseHorizontalPadding: CGFloat = 3
    private let baseCornerRadius: CGFloat = 8
    private let baseRowSpacing: CGFloat = 7
    private let baseTopInset: CGFloat = 0.5
    private let baseShiftWidth: CGFloat = 50
    private let baseDeleteWidth: CGFloat = 50
    private let baseSwitcherWidth: CGFloat = 82
    private let baseReturnWidth: CGFloat = 92

    private struct KeyboardMetrics {
        let keyHeight: CGFloat
        let keyGap: CGFloat
        let rowSpacing: CGFloat
        let topPadding: CGFloat
        let bottomPadding: CGFloat
        let horizontalPadding: CGFloat
        let cornerRadius: CGFloat
        let letterFont: Font
        let specialFont: Font
        let letterWidth: CGFloat
        let shiftWidth: CGFloat
        let deleteWidth: CGFloat
        let switcherWidth: CGFloat
        let returnWidth: CGFloat
    }
    
    // MARK: - Key Model
    
    private struct KeyModel: Hashable {
        enum Kind: Hashable { case letter, shift, delete, switcher, space, `return`, emoji }
        let title: String
        let kind: Kind
        var secondaryTitle: String = ""
        var id: String { "\(kind)-\(title)" }
    }
    
    // MARK: - KeyCap View
    
    private struct KeyCap: View {
        let title: String
        let displayedTitle: String
        let secondaryTitle: String
        let width: CGFloat
        let height: CGFloat
        let isSpecial: Bool
        let cornerRadius: CGFloat
        let font: Font
        let secondaryFont: Font?
        let onPressDown: (() -> Void)?
        let onPressUp: (() -> Void)?
        let action: () -> Void
        @State private var isDown = false
        @State private var showPopup = false
        @State private var popupText: String = ""
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance
        
        var body: some View {
            ZStack {
                // Internal glyph padding per spec: secondary at top, primary centered below
                ZStack(alignment: .top) {
                    if !secondaryTitle.isEmpty && !isSpecial {
                        Text(secondaryTitle)
                            .font(.system(size: height * 0.18, weight: .regular))
                            .foregroundColor(Color(red: 140/255.0, green: 140/255.0, blue: 140/255.0))
                            .padding(.top, height * 0.08)
                    }
                    // Check if this is a special key that should show an SF Symbol icon
                    if isSpecial, let iconName = iconForSpecialKey(title: title) {
                        Image(systemName: iconName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(UIColor.label))
                            .frame(width: width, height: height, alignment: .center)
                    } else {
                        Text(displayedTitle)
                            .font(font)
                            .lineLimit(1)
                            .foregroundColor(Color(UIColor.label))
                            .frame(width: width, height: height, alignment: .center)
                    }
                }
                .frame(width: width, height: height)
                .background(background)
                .scaleEffect(isDown ? 0.96 : 1.0)
                .animation(.easeOut(duration: 0.08), value: isDown)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isDown {
                                isDown = true
                                action()
                                onPressDown?()
                                if !isSpecial {
                                    popupText = displayedTitle
                                    showPopup = true
                                }
                            }
                        }
                        .onEnded { _ in
                            isDown = false
                            onPressUp?()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                showPopup = false
                            }
                        }
                )
                
                if showPopup && !isSpecial {
                    let frozen = popupText.isEmpty ? displayedTitle : popupText
                    Text(frozen)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color(UIColor.label))
                        .frame(minWidth: width * 1.15, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(UIColor.tertiarySystemBackground))
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
                        .offset(y: -height * 0.85)
                        .zIndex(9999)
                        .allowsHitTesting(false)
                }
            }
            .zIndex(showPopup ? 1 : 0)
        }
        
        private func iconForSpecialKey(title: String) -> String? {
            switch title {
            case "shift", "shift_left": return "shift"
            case "shift.fill", "shift_right": return "shift.fill"
            case "delete", "⌫": return "delete.left"
            case "tab": return "arrow.right.to.line"
            case "return": return "arrow.turn.down.left"
            case "emoji": return "face.smiling"
            default: return nil
            }
        }

        private var background: some View {
            let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
            return Group {
                let fill = isSpecial ? palette.specialKeyBackground : palette.keyBackground
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(palette.controlBorder.opacity(0.6), lineWidth: 0.5)
                    )
            }
        }
    }
    
    // MARK: - Layout Helpers

    private func roundedToHalfPoint(_ value: CGFloat) -> CGFloat {
        (value * 2).rounded(.toNearestOrEven) / 2
    }
    
    private func metrics(for size: CGSize) -> KeyboardMetrics {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        if isPad {
            // iPad metrics from exact specification
            // Standard key = 1.0× (square), gap = 0.2× in both axes
            // Row 1: Tab(1.29) + Q-P(10×1.0) + Backspace(1.29) + 11 gaps(0.2) = 14.78
            // Row 2: Shift(1.66) + A-L(9×1.0) + Return(2.14) + 10 gaps(0.2) = 14.80
            // Row 3: LShift(2.20) + Z-M+,(9×1.0) + RShift(1.60) + 10 gaps(0.2) = 14.80
            // Row 4: Globe(1.08) + .?123(1.08) + Mic(1.08) + Space(7.30) + .?123(1.60) + Dismiss(1.60) + 5 gaps(0.2) = 14.14
            // Widest row = 14.80 × keyUnit
            let horizontalPadding: CGFloat = 4
            let topPadding: CGFloat = 0
            let bottomPadding: CGFloat = 4
            let rowContentWidth = max(size.width - (horizontalPadding * 2), 0)
            let keyUnit = roundedToHalfPoint(rowContentWidth / 14.80)
            let keyGap = roundedToHalfPoint(min(keyUnit * 0.24, 14))
            // Cap key height so landscape keyboards don't get enormous
            let keyHeight = min(keyUnit, 58)
            let rowSpacing = keyGap
            let cornerRadius = roundedToHalfPoint(keyHeight * 0.18)
            let letterFontSize = roundedToHalfPoint(keyHeight * 0.46)
            let specialFontSize = roundedToHalfPoint(keyHeight * 0.30)
            let letterWidth = keyUnit
            let tabWidth = roundedToHalfPoint(keyUnit * 1.29)
            let backspaceWidth = roundedToHalfPoint(keyUnit * 1.29)
            let shiftRow2Width = roundedToHalfPoint(keyUnit * 1.66)
            let returnWidth = roundedToHalfPoint(keyUnit * 2.14)
            let shiftRow3LeftWidth = roundedToHalfPoint(keyUnit * 2.20)
            let shiftRow3RightWidth = roundedToHalfPoint(keyUnit * 1.60)
            let utilityKeyWidth = roundedToHalfPoint(keyUnit * 1.08)
            let rightSwitcherWidth = roundedToHalfPoint(keyUnit * 1.60)
            let dismissWidth = roundedToHalfPoint(keyUnit * 1.60)

            return KeyboardMetrics(
                keyHeight: keyHeight,
                keyGap: keyGap,
                rowSpacing: rowSpacing,
                topPadding: topPadding,
                bottomPadding: bottomPadding,
                horizontalPadding: horizontalPadding,
                cornerRadius: cornerRadius,
                letterFont: .system(size: letterFontSize, weight: .regular),
                specialFont: .system(size: specialFontSize, weight: .medium),
                letterWidth: letterWidth,
                shiftWidth: shiftRow2Width,
                deleteWidth: backspaceWidth,
                switcherWidth: utilityKeyWidth,
                returnWidth: returnWidth
            )
        }

        // iPhone: original scaling behavior, adjusted for compactness
        let desiredTopPadding: CGFloat = 0
        let bottomPadding: CGFloat = 4
        let rowSpacing: CGFloat = 8
        let keyGap: CGFloat = 6
        let horizontalPadding: CGFloat = 4
        
        let heightScale = min(max(size.height / baseKeyboardHeight, 0.94), 1.38)
        let widthScale = max(size.width / 390.0, 0.96)
        let rowContentWidth = max(size.width - (horizontalPadding * 2), 0)
        let availableKeyHeight = max(
            size.height - desiredTopPadding - bottomPadding - (rowSpacing * 3),
            0
        )
        let keyHeight = min(baseKeyHeight * heightScale, availableKeyHeight / 4)
        let contentHeight = (keyHeight * 4) + (rowSpacing * 3)
        let topPadding = max(size.height - contentHeight - bottomPadding, desiredTopPadding)
        let cornerRadius: CGFloat = 8
        let letterFontSize = min(max(keyHeight * 0.48, 22), 28)
        let specialFontSize = min(max(keyHeight * 0.32, 15), 19)
        let letterWidth = roundedToHalfPoint((rowContentWidth - (keyGap * 9)) / 10)
        let targetThirdRowInset = min(max(rowContentWidth * 0.008, 2.5), 4)
        let shiftWidth = roundedToHalfPoint(max(
            (rowContentWidth - (letterWidth * 7) - (keyGap * 8) - (targetThirdRowInset * 2)) / 2,
            keyHeight * 1.12
        ))
        let deleteWidth = shiftWidth
        let smallKeyWidth = roundedToHalfPoint(max(letterWidth * 1.55, 50))
        let switcherWidth = smallKeyWidth
        let returnWidth = roundedToHalfPoint(max(letterWidth * 1.95, baseReturnWidth * widthScale * 0.75))

        return KeyboardMetrics(
            keyHeight: keyHeight,
            keyGap: keyGap,
            rowSpacing: rowSpacing,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
            horizontalPadding: horizontalPadding,
            cornerRadius: cornerRadius,
            letterFont: .system(size: letterFontSize, weight: .regular),
            specialFont: .system(size: specialFontSize, weight: .medium),
            letterWidth: letterWidth,
            shiftWidth: shiftWidth,
            deleteWidth: deleteWidth,
            switcherWidth: switcherWidth,
            returnWidth: returnWidth
        )
    }

    private func widthForKey(key: KeyModel, letterWidth: CGFloat, metrics: KeyboardMetrics) -> CGFloat {
        switch key.kind {
        case .shift:
            return metrics.shiftWidth // 1.66× for row 2, overridden for row 3
        case .delete:
            return metrics.deleteWidth // 1.29×
        case .switcher:
            return metrics.switcherWidth // 1.08× for utility keys
        case .return:
            return metrics.returnWidth // 2.14×
        case .space:
            return letterWidth
        default:
            return letterWidth // 1.0×
        }
    }
    
    private func displayTitle(for char: String, kind: KeyModel.Kind) -> String {
        if kind == .letter {
            if isShiftOn {
                return char.uppercased()
            } else {
                return char.lowercased()
            }
        }
        return char
    }

    private func onKeyPressDown(kind: KeyModel.Kind) {
        switch kind {
        case .shift:
            triggerHaptic(style: .light)
        case .delete:
            triggerHaptic(style: .rigid)
            onDelete()
            playKeyClickSound(keyCode: 1155)
            startDeleteHoldTimer()
        case .switcher, .space, .return, .letter, .emoji:
            triggerHaptic(style: .light)
        }
    }
    
    private func onKeyPressUp(kind: KeyModel.Kind) {
        switch kind {
        case .delete:
            stopDeleteTimer()
        default:
            break
        }
    }
    
    private func handleKeyTap(_ key: KeyModel) {
        switch key.kind {
        case .letter:
            keyPressed(char: key.title)
        case .shift:
            isShiftOn.toggle()
            playKeyClickSound(keyCode: 1104)
        case .delete:
            // Delete is handled by press down/up to support continuous delete. Do nothing here.
            break
        case .emoji:
            layer = .emojis
            playKeyClickSound(keyCode: 1104)
        case .switcher:
            switch key.title {
            case "123", ".?123":
                layer = .numbers
                isShiftOn = false
            case "ABC":
                layer = .letters
            case "#+=":
                layer = (layer == .numbers) ? .symbols : .numbers
            case "tab":
                // Tab key — insert tab or multiple spaces
                onInsert("\t")
            default:
                // Fallback: toggle letters/numbers
                layer = (layer == .letters) ? .numbers : .letters
                isShiftOn = false
            }
            playKeyClickSound(keyCode: 1104)
        case .space:
            onInsert(" ")
            playKeyClickSound(keyCode: 1104)
        case .return:
            onReturn()
            playKeyClickSound(keyCode: 1104)
        }
    }
    
    // MARK: - Rows Layout
    
    private func sharedLetterWidth(for totalWidth: CGFloat, metrics: KeyboardMetrics) -> CGFloat {
        min(metrics.letterWidth, totalWidth)
    }

    private func centeredInset(totalWidth: CGFloat, contentWidth: CGFloat) -> CGFloat {
        max((totalWidth - contentWidth) / 2, 0)
    }

    private func layoutLetterRow(keys: [KeyModel], metrics: KeyboardMetrics) -> some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let letterWidth = min(sharedLetterWidth(for: totalWidth, metrics: metrics), totalWidth)
            let contentWidth = (
                (letterWidth * CGFloat(keys.count))
                + (CGFloat(max(keys.count - 1, 0)) * metrics.keyGap)
            )
            let inset = centeredInset(totalWidth: totalWidth, contentWidth: contentWidth)

            let items: [(id: String, title: String, kind: KeyModel.Kind, secondaryTitle: String, width: CGFloat, centerX: CGFloat)] = {
                var x = inset
                var arr: [(String, String, KeyModel.Kind, String, CGFloat, CGFloat)] = []
                for key in keys {
                    let w = widthForKey(key: key, letterWidth: letterWidth, metrics: metrics)
                    let cx = x + w / 2
                    arr.append((key.id, key.title, key.kind, key.secondaryTitle, w, cx))
                    x += w + metrics.keyGap
                }
                return arr
            }()
            
            ZStack(alignment: .leading) {
                ForEach(items, id: \.id) { item in
                    KeyCap(
                        title: item.title,
                        displayedTitle: displayTitle(for: item.title, kind: item.kind),
                        secondaryTitle: item.secondaryTitle,
                        width: item.width,
                        height: metrics.keyHeight,
                        isSpecial: item.kind != .letter,
                        cornerRadius: metrics.cornerRadius,
                        font: item.kind != .letter ? metrics.specialFont : metrics.letterFont,
                        secondaryFont: .system(size: 9, weight: .light),
                        onPressDown: { onKeyPressDown(kind: item.kind) },
                        onPressUp: { onKeyPressUp(kind: item.kind) },
                        action: { handleKeyTap(KeyModel(title: item.title, kind: item.kind)) }
                    )
                    .frame(width: item.width, height: metrics.keyHeight)
                    .position(x: item.centerX, y: metrics.keyHeight / 2)
                }
            }
        }
        .frame(height: metrics.keyHeight)
    }

    private func layoutRow(keys: [KeyModel], inset: CGFloat, metrics: KeyboardMetrics) -> some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let availableWidth = screenWidth - (inset * 2)
            let gaps = CGFloat(max(keys.count - 1, 0)) * metrics.keyGap
            let letterWidth = (availableWidth - gaps) / CGFloat(max(keys.count, 1))

            let items: [(id: String, title: String, kind: KeyModel.Kind, secondaryTitle: String, width: CGFloat, centerX: CGFloat)] = {
                var x = inset
                var arr: [(String, String, KeyModel.Kind, String, CGFloat, CGFloat)] = []
                for key in keys {
                    let w = widthForKey(key: key, letterWidth: letterWidth, metrics: metrics)
                    let cx = x + w / 2
                    arr.append((key.id, key.title, key.kind, key.secondaryTitle, w, cx))
                    x += w + metrics.keyGap
                }
                return arr
            }()

            ZStack(alignment: .leading) {
                ForEach(items, id: \.id) { item in
                    KeyCap(
                        title: item.title,
                        displayedTitle: displayTitle(for: item.title, kind: item.kind),
                        secondaryTitle: item.secondaryTitle,
                        width: item.width,
                        height: metrics.keyHeight,
                        isSpecial: item.kind != .letter,
                        cornerRadius: metrics.cornerRadius,
                        font: item.kind != .letter ? metrics.specialFont : metrics.letterFont,
                        secondaryFont: .system(size: 9, weight: .light),
                        onPressDown: { onKeyPressDown(kind: item.kind) },
                        onPressUp: { onKeyPressUp(kind: item.kind) },
                        action: { handleKeyTap(KeyModel(title: item.title, kind: item.kind)) }
                    )
                    .frame(width: item.width, height: metrics.keyHeight)
                    .position(x: item.centerX, y: metrics.keyHeight / 2)
                }
            }
        }
        .frame(height: metrics.keyHeight)
    }

    private func layoutMixedWidthRow(
        keys: [KeyModel],
        inset: CGFloat,
        metrics: KeyboardMetrics,
        keyGapOverride: CGFloat? = nil,
        widthOverride: ((KeyModel, KeyboardMetrics) -> CGFloat?)? = nil
    ) -> some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let availableWidth = screenWidth - (inset * 2)
            let keyGap = keyGapOverride ?? metrics.keyGap
            let gaps = CGFloat(max(keys.count - 1, 0)) * keyGap
            let flexibleKeyCount = keys.filter { $0.kind == .letter || $0.kind == .space }.count
            let fixedWidth = keys.reduce(CGFloat.zero) { partialResult, key in
                guard key.kind != .letter && key.kind != .space else { return partialResult }
                let overriddenWidth = widthOverride?(key, metrics)
                return partialResult + (overriddenWidth ?? widthForKey(key: key, letterWidth: 0, metrics: metrics))
            }
            let flexibleWidth = max(availableWidth - gaps - fixedWidth, 0)
            let letterWidth = flexibleWidth / CGFloat(max(flexibleKeyCount, 1))

            let items: [(id: String, title: String, kind: KeyModel.Kind, secondaryTitle: String, width: CGFloat, centerX: CGFloat)] = {
                var x = inset
                var arr: [(String, String, KeyModel.Kind, String, CGFloat, CGFloat)] = []
                for key in keys {
                    let overriddenWidth = widthOverride?(key, metrics)
                    let w = overriddenWidth ?? widthForKey(key: key, letterWidth: letterWidth, metrics: metrics)
                    let cx = x + w / 2
                    arr.append((key.id, key.title, key.kind, key.secondaryTitle, w, cx))
                    x += w + keyGap
                }
                return arr
            }()

            ZStack(alignment: .leading) {
                ForEach(items, id: \.id) { item in
                    KeyCap(
                        title: item.title,
                        displayedTitle: displayTitle(for: item.title, kind: item.kind),
                        secondaryTitle: item.secondaryTitle,
                        width: item.width,
                        height: metrics.keyHeight,
                        isSpecial: item.kind != .letter,
                        cornerRadius: metrics.cornerRadius,
                        font: item.kind != .letter ? metrics.specialFont : metrics.letterFont,
                        secondaryFont: .system(size: 9, weight: .light),
                        onPressDown: {
                            if item.kind == .delete {
                                triggerHaptic(style: .rigid)
                                onDelete()
                                playKeyClickSound(keyCode: 1155)
                                startDeleteHoldTimer()
                            } else {
                                onKeyPressDown(kind: item.kind)
                            }
                        },
                        onPressUp: {
                            if item.kind == .delete {
                                stopDeleteTimer()
                            } else {
                                onKeyPressUp(kind: item.kind)
                            }
                        },
                        action: {
                            if item.kind == .delete {
                                return
                            }
                            handleKeyTap(KeyModel(title: item.title, kind: item.kind))
                        }
                    )
                    .frame(width: item.width, height: metrics.keyHeight)
                    .position(x: item.centerX, y: metrics.keyHeight / 2)
                }
            }
        }
        .frame(height: metrics.keyHeight)
    }
    
    private func row1(metrics: KeyboardMetrics) -> some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        var keys: [KeyModel]
        if isPad {
            // iPad row 1: Tab(1.29×) + Q-P(10×1.0×) + Backspace(1.29×)
            keys = [KeyModel(title: "tab", kind: .switcher)]
            let hints = ["1","2","3","4","5","6","7","8","9","0"]
            keys += zip(Array("QWERTYUIOP"), hints).map { letter, hint in
                KeyModel(title: String(letter), kind: .letter, secondaryTitle: hint)
            }
            keys.append(KeyModel(title: "delete", kind: .delete))
            return AnyView(layoutMixedWidthRow(
                keys: keys,
                inset: 0,
                metrics: metrics,
                widthOverride: { key, m in
                    if key.title == "tab" { return m.deleteWidth } // 1.29× (same as backspace)
                    return nil
                }
            ))
        } else {
            let hints = ["1","2","3","4","5","6","7","8","9","0"]
            keys = zip(Array("QWERTYUIOP"), hints).map { letter, hint in
                KeyModel(title: String(letter), kind: .letter, secondaryTitle: hint)
            }
        }
        return AnyView(layoutLetterRow(keys: keys, metrics: metrics))
    }

    private func row2(metrics: KeyboardMetrics) -> some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        if isPad {
            // iPad row 2: Shift(1.66×) + A-L(9×1.0×) + Return(2.14×)
            let hints = ["@","#","$","&","*","(",")","'","\""]
            let lettersWithHints = zip(Array("ASDFGHJKL"), hints).map { letter, hint in
                KeyModel(title: String(letter), kind: .letter, secondaryTitle: hint)
            }
            let keys = [KeyModel(title: "shift", kind: .shift)]
                + lettersWithHints
                + [KeyModel(title: "return", kind: .return)]
            return AnyView(layoutMixedWidthRow(
                keys: keys,
                inset: 0,
                metrics: metrics,
                widthOverride: { key, m in
                    if key.kind == .shift { return m.shiftWidth } // 1.66×
                    if key.kind == .return { return m.returnWidth } // 2.14×
                    return nil
                }
            ))
        } else {
            let hints = ["@","#","$","&","*","(",")","'","\""]
            let lettersWithHints = zip(Array("ASDFGHJKL"), hints).map { letter, hint in
                KeyModel(title: String(letter), kind: .letter, secondaryTitle: hint)
            }
            return AnyView(layoutLetterRow(keys: lettersWithHints, metrics: metrics))
        }
    }
    
    private func row3(metrics: KeyboardMetrics) -> some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        if isPad {
            // iPad row 3: Left Shift(2.20×) + Z-M + punct(9×1.0×) + Right Shift(1.60×)
            let hints = ["%","-","+","=","/",";",":"]
            let lettersWithHints = zip(Array("ZXCVBNM"), hints).map { letter, hint in
                KeyModel(title: String(letter), kind: .letter, secondaryTitle: hint)
            }
            let leftShiftW = roundedToHalfPoint(metrics.letterWidth * 2.20)
            let rightShiftW = roundedToHalfPoint(metrics.letterWidth * 1.60)
            let keys = [KeyModel(title: "shift_left", kind: .shift)]
                + lettersWithHints
                + [
                    KeyModel(title: ",", kind: .letter, secondaryTitle: "!"),
                    KeyModel(title: ".", kind: .letter, secondaryTitle: "?")
                ]
                + [KeyModel(title: "shift_right", kind: .shift)]
            return AnyView(layoutMixedWidthRow(
                keys: keys,
                inset: 0,
                metrics: metrics,
                widthOverride: { key, m in
                    if key.title == "shift_left" { return leftShiftW } // 2.20×
                    if key.title == "shift_right" { return rightShiftW } // 1.60×
                    return nil
                }
            ))
        }
        // iPhone: shift + ZXCVBNM + delete
        return AnyView(iPhoneRow3(metrics: metrics))
    }

    private func iPhoneRow3(metrics: KeyboardMetrics) -> some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let hints = ["%","-","+","=","/",";",":"]
            let letters = zip(Array("ZXCVBNM"), hints).map { letter, hint in
                KeyModel(title: String(letter), kind: .letter, secondaryTitle: hint)
            }
            let rowGap = metrics.keyGap
            
            let shiftW = metrics.shiftWidth
            let delW = metrics.deleteWidth
            let letterWidth = min(metrics.letterWidth, screenWidth)
            let contentWidth = (
                shiftW
                + delW
                + (letterWidth * CGFloat(letters.count))
                + (CGFloat(letters.count + 1) * rowGap)
            )
            let inset = centeredInset(totalWidth: screenWidth, contentWidth: contentWidth)
            
            let items: [(id: String, title: String, kind: KeyModel.Kind, secondaryTitle: String, width: CGFloat, centerX: CGFloat)] = {
                var x = inset
                var arr: [(String, String, KeyModel.Kind, String, CGFloat, CGFloat)] = []
                
                let shiftTitle = isShiftOn ? "shift.fill" : "shift"
                let shift = KeyModel(title: shiftTitle, kind: .shift)
                arr.append((shift.id, shift.title, shift.kind, "", shiftW, x + shiftW / 2))
                x += shiftW + rowGap
                
                for ch in letters {
                    arr.append((ch.id, ch.title, ch.kind, ch.secondaryTitle, letterWidth, x + letterWidth / 2))
                    x += letterWidth + rowGap
                }
                
                let del = KeyModel(title: "delete", kind: .delete)
                arr.append((del.id, del.title, del.kind, "", delW, x + delW / 2))
                return arr
            }()
            
            ZStack(alignment: .leading) {
                ForEach(items, id: \.id) { item in
                    KeyCap(
                        title: item.title,
                        displayedTitle: displayTitle(for: item.title, kind: item.kind),
                        secondaryTitle: item.secondaryTitle,
                        width: item.width,
                        height: metrics.keyHeight,
                        isSpecial: item.kind != .letter,
                        cornerRadius: metrics.cornerRadius,
                        font: item.kind != .letter ? metrics.specialFont : metrics.letterFont,
                        secondaryFont: nil,
                        onPressDown: {
                            if item.kind == .delete {
                                triggerHaptic(style: .rigid)
                                onDelete()
                                playKeyClickSound(keyCode: 1155)
                                startDeleteHoldTimer()
                            } else {
                                triggerHaptic(style: .light)
                            }
                        },
                        onPressUp: {
                            if item.kind == .delete {
                                stopDeleteTimer()
                            }
                        },
                        action: {
                            switch item.kind {
                            case .letter:
                                keyPressed(char: item.title)
                            case .shift:
                                isShiftOn.toggle()
                                playKeyClickSound(keyCode: 1104)
                            case .delete:
                                // handled by press up
                                break
                            default:
                                break
                            }
                        }
                    )
                    .frame(width: item.width, height: metrics.keyHeight)
                    .position(x: item.centerX, y: metrics.keyHeight / 2)
                }
            }
        }
        .frame(height: metrics.keyHeight)
    }

    // MARK: - Globe Key (iPad)

    private struct GlobeKeyButton: View {
        let width: CGFloat
        let height: CGFloat
        let cornerRadius: CGFloat
        let font: Font
        let action: () -> Void
        @State private var isPressed = false
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

        var body: some View {
            let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
            Button(action: action) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(width: width, height: height)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(palette.specialKeyBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(palette.controlBorder, lineWidth: 0.6)
                            )
                    )
                    .scaleEffect(isPressed ? 0.98 : 1.0)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
        }
    }

    // MARK: - Microphone Key (iPad)

    private struct MicKeyButton: View {
        let width: CGFloat
        let height: CGFloat
        let cornerRadius: CGFloat
        let font: Font
        let action: () -> Void
        @State private var isPressed = false
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

        var body: some View {
            let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
            Button(action: action) {
                Image(systemName: "mic")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(width: width, height: height)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(palette.specialKeyBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(palette.controlBorder, lineWidth: 0.6)
                            )
                    )
                    .scaleEffect(isPressed ? 0.98 : 1.0)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
        }
    }

    // MARK: - Keyboard Dismiss Key (iPad)

    private struct KeyboardDismissButton: View {
        let width: CGFloat
        let height: CGFloat
        let cornerRadius: CGFloat
        let font: Font
        let action: () -> Void
        @State private var isPressed = false
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

        var body: some View {
            let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
            Button(action: action) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: width, height: height)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(palette.specialKeyBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(palette.controlBorder, lineWidth: 0.6)
                            )
                    )
                    .scaleEffect(isPressed ? 0.98 : 1.0)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
        }
    }

    // MARK: - Space (trackpad) key

    private struct SpaceTrackpadKey: View {
        let title: String
        let width: CGFloat
        let height: CGFloat
        let cornerRadius: CGFloat
        let font: Font
        let onInsertSpace: () -> Void
        let onMoveCursor: (Int) -> Void
        let hapticsEnabled: Bool

        @State private var isPressed = false
        @State private var inTrackpadMode = false
        @State private var accumX: CGFloat = 0
        @State private var previousDragTranslation: CGSize = .zero
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance

        // iOS spacebar trackpad movement is intentionally damped. A larger
        // step keeps short drags precise and prevents search-field cursor jumps.
        private let stepX: CGFloat = 18.0

        var body: some View {
            let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(palette.specialKeyBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(palette.controlBorder, lineWidth: 0.6)
                    )

                let isPad = UIDevice.current.userInterfaceIdiom == .pad
                if isPad {
                    // iPad: show "EN" on right side of space bar like native
                    Text("EN")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 8)
                } else {
                    ZStack {
                        Text(title)
                            .font(font)
                            .foregroundStyle(Color(UIColor.label))
                        
                        Text("A")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.trailing, 8)
                            .padding(.bottom, 4)
                    }
                }
            }
            .frame(width: width, height: height)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            // Tap inserts space only if not in trackpad mode
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if !inTrackpadMode {
                            onInsertSpace()
                            AudioServicesPlaySystemSound(1104)
                            if hapticsEnabled {
                                let g = UIImpactFeedbackGenerator(style: .light)
                                g.prepare()
                                g.impactOccurred()
                            }
                        }
                    }
            )
            // Long press enters trackpad mode
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.25)
                    .onEnded { _ in
                        inTrackpadMode = true
                        isPressed = true
                        accumX = 0
                        previousDragTranslation = .zero
                        if hapticsEnabled {
                            let g = UIImpactFeedbackGenerator(style: .soft)
                            g.prepare()
                            g.impactOccurred()
                        }
                    }
            )
            // Drag while in trackpad mode moves the cursor; releasing exits mode
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if inTrackpadMode {
                            let deltaX = value.translation.width - previousDragTranslation.width
                            previousDragTranslation = value.translation
                            accumX += deltaX

                            let moveX = Int(accumX / stepX)
                            if moveX != 0 {
                                onMoveCursor(moveX)
                                accumX -= CGFloat(moveX) * stepX
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        inTrackpadMode = false
                        accumX = 0
                        previousDragTranslation = .zero
                    }
            )
        }
    }
    
    private func bottomRow(metrics: KeyboardMetrics) -> some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let inset: CGFloat = 0
            let availableWidth = screenWidth - (inset * 2)
            let rowGap = metrics.keyGap
            let displayReturnTitle = returnKeyTitle.isEmpty ? "return" : returnKeyTitle

            if isPad {
                // iPad Row 4: Globe(1.08×) + .?123(1.08×) + Mic(1.08×) + Space(7.30×) + .?123(1.60×) + Dismiss(1.60×)
                let isLetters = layer == .letters
                let utilityW = roundedToHalfPoint(metrics.letterWidth * 1.08)
                let rightSwitcherW = roundedToHalfPoint(metrics.letterWidth * 1.60)
                let dismissW = roundedToHalfPoint(metrics.letterWidth * 1.60)
                let fixedWidthSum = utilityW + utilityW + utilityW + rightSwitcherW + dismissW
                let gapCount: CGFloat = 5
                let spaceW = max(availableWidth - fixedWidthSum - gapCount * rowGap, metrics.letterWidth * 5.0)

                let items: [(id: String, title: String, kind: KeyModel.Kind, width: CGFloat, centerX: CGFloat)] = {
                    var x = inset
                    var arr: [(String, String, KeyModel.Kind, CGFloat, CGFloat)] = []

                    // Globe: 1.08×
                    arr.append(("switcher-globe_icon", "globe_icon", .switcher, utilityW, x + utilityW / 2))
                    x += utilityW + rowGap

                    // Left .?123: 1.08×
                    let leftSwitchTitle = isLetters ? ".?123" : "ABC"
                    arr.append(("switcher-\(leftSwitchTitle)", leftSwitchTitle, .switcher, utilityW, x + utilityW / 2))
                    x += utilityW + rowGap

                    // Mic: 1.08×
                    arr.append(("switcher-mic_icon", "mic_icon", .switcher, utilityW, x + utilityW / 2))
                    x += utilityW + rowGap

                    // Space: 7.30×
                    arr.append(("space", "space", .space, spaceW, x + spaceW / 2))
                    x += spaceW + rowGap

                    // Right .?123: 1.60×
                    arr.append(("switcher-.?123", ".?123", .switcher, rightSwitcherW, x + rightSwitcherW / 2))
                    x += rightSwitcherW + rowGap

                    // Dismiss: 1.60×
                    arr.append(("switcher-dismiss_icon", "dismiss_icon", .switcher, dismissW, x + dismissW / 2))
                    return arr
                }()

                ZStack(alignment: .leading) {
                    ForEach(items, id: \.id) { item in
                        if item.kind == .space {
                            SpaceTrackpadKey(
                                title: item.title,
                                width: item.width,
                                height: metrics.keyHeight,
                                cornerRadius: metrics.cornerRadius,
                                font: metrics.specialFont,
                                onInsertSpace: {
                                    playKeyClickSound(keyCode: 1104)
                                    onInsert(" ")
                                },
                                onMoveCursor: onMoveCursor,
                                hapticsEnabled: hapticsEnabled
                            )
                            .frame(width: item.width, height: metrics.keyHeight)
                            .position(x: item.centerX, y: metrics.keyHeight / 2)
                        } else if item.title == "globe_icon" {
                            GlobeKeyButton(
                                width: item.width,
                                height: metrics.keyHeight,
                                cornerRadius: metrics.cornerRadius,
                                font: metrics.specialFont,
                                action: { onGlobe() }
                            )
                            .position(x: item.centerX, y: metrics.keyHeight / 2)
                        } else if item.title == "mic_icon" {
                            MicKeyButton(
                                width: item.width,
                                height: metrics.keyHeight,
                                cornerRadius: metrics.cornerRadius,
                                font: metrics.specialFont,
                                action: { onMic() }
                            )
                            .position(x: item.centerX, y: metrics.keyHeight / 2)
                        } else if item.title == "dismiss_icon" {
                            KeyboardDismissButton(
                                width: item.width,
                                height: metrics.keyHeight,
                                cornerRadius: metrics.cornerRadius,
                                font: metrics.specialFont,
                                action: { onDismissKeyboard() }
                            )
                            .position(x: item.centerX, y: metrics.keyHeight / 2)
                        } else {
                            KeyCap(
                                title: item.title,
                                displayedTitle: item.title,
                                secondaryTitle: "",
                                width: item.width,
                                height: metrics.keyHeight,
                                isSpecial: true,
                                cornerRadius: metrics.cornerRadius,
                                font: metrics.specialFont,
                                secondaryFont: nil,
                                onPressDown: { triggerHaptic(style: .light) },
                                onPressUp: {},
                                action: {
                                    switch item.kind {
                                    case .switcher:
                                        let key = KeyModel(title: item.title, kind: .switcher)
                                        handleKeyTap(key)
                                    case .return:
                                        playKeyClickSound(keyCode: 1104)
                                        onReturn()
                                    default:
                                        break
                                    }
                                }
                            )
                            .frame(width: item.width, height: metrics.keyHeight)
                            .position(x: item.centerX, y: metrics.keyHeight / 2)
                        }
                    }
                }
            } else {
                // iPhone layout: [123] [emoji] [space] [return]
                let switchW = metrics.switcherWidth
                let emojiW = metrics.switcherWidth
                let returnW = metrics.returnWidth
                let fixedWidth = switchW + emojiW + returnW
                let gapCount: CGFloat = 3
                let spaceW = availableWidth - fixedWidth - gapCount * rowGap
                let switchTitle = (layer == .letters) ? "123" : "ABC"

                let items: [(id: String, title: String, kind: KeyModel.Kind, width: CGFloat, centerX: CGFloat)] = {
                    var x = inset
                    var arr: [(String, String, KeyModel.Kind, CGFloat, CGFloat)] = []
                    arr.append(("switcher-\(switchTitle)", switchTitle, .switcher, switchW, x + switchW / 2))
                    x += switchW + rowGap
                    arr.append(("emoji", "emoji", .emoji, emojiW, x + emojiW / 2))
                    x += emojiW + rowGap
                    arr.append(("space", "space", .space, spaceW, x + spaceW / 2))
                    x += spaceW + rowGap
                    arr.append(("return-\(displayReturnTitle)", displayReturnTitle, .return, returnW, x + returnW / 2))
                    return arr
                }()

                ZStack(alignment: .leading) {
                    ForEach(items, id: \.id) { item in
                        if item.kind == .space {
                            SpaceTrackpadKey(
                                title: item.title,
                                width: item.width,
                                height: metrics.keyHeight,
                                cornerRadius: metrics.cornerRadius,
                                font: metrics.specialFont,
                                onInsertSpace: {
                                    playKeyClickSound(keyCode: 1104)
                                    onInsert(" ")
                                },
                                onMoveCursor: onMoveCursor,
                                hapticsEnabled: hapticsEnabled
                            )
                            .frame(width: item.width, height: metrics.keyHeight)
                            .position(x: item.centerX, y: metrics.keyHeight / 2)
                        } else {
                            KeyCap(
                                title: item.title,
                                displayedTitle: item.title,
                                secondaryTitle: "",
                                width: item.width,
                                height: metrics.keyHeight,
                                isSpecial: true,
                                cornerRadius: metrics.cornerRadius,
                                font: metrics.specialFont,
                                secondaryFont: nil,
                                onPressDown: { triggerHaptic(style: .light) },
                                onPressUp: {},
                                action: {
                                    switch item.kind {
                                    case .switcher:
                                        let key = KeyModel(title: item.title, kind: .switcher)
                                        handleKeyTap(key)
                                    case .emoji:
                                        let key = KeyModel(title: item.title, kind: .emoji)
                                        handleKeyTap(key)
                                    case .return:
                                        playKeyClickSound(keyCode: 1104)
                                        onReturn()
                                    default:
                                        break
                                    }
                                }
                            )
                            .frame(width: item.width, height: metrics.keyHeight)
                            .position(x: item.centerX, y: metrics.keyHeight / 2)
                        }
                    }
                }
            }
        }
        .frame(height: metrics.keyHeight)
    }
    
    // MARK: - Keyboard Container
    
    private func keyboardContainer(metrics: KeyboardMetrics) -> some View {
        return ZStack {
            VStack(spacing: metrics.rowSpacing) {
                switch layer {
                case .letters:
                    row1(metrics: metrics)
                    row2(metrics: metrics)
                    row3(metrics: metrics)
                    bottomRow(metrics: metrics)
                case .numbers:
                    numbersLayer(metrics: metrics)
                    bottomRow(metrics: metrics)
                case .symbols:
                    symbolsLayer(metrics: metrics)
                    bottomRow(metrics: metrics)
                case .emojis:
                    emojiLayer(metrics: metrics)
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
        }
    }
    
    // MARK: - Numbers and Symbols Layers
    
    private func numbersLayer(metrics: KeyboardMetrics) -> some View {
        VStack(spacing: metrics.rowSpacing) {
            layoutRow(
                keys: Array("1234567890").map { KeyModel(title: String($0), kind: .letter) },
                inset: 0,
                metrics: metrics
            )
            layoutRow(
                keys: Array("-/:;()$&@\"").map { KeyModel(title: String($0), kind: .letter) },
                inset: 0,
                metrics: metrics
            )
            layoutMixedWidthRow(
                keys: [
                    KeyModel(title: "#+=", kind: .switcher)
                ] + Array("+=_,.?!").map { KeyModel(title: String($0), kind: .letter) } + [
                    KeyModel(title: "⌫", kind: .delete)
                ],
                inset: 0,
                metrics: metrics,
                keyGapOverride: 7,
                widthOverride: { key, metrics in
                    switch key.kind {
                    case .switcher, .delete:
                        return metrics.shiftWidth
                    default:
                        return nil
                    }
                }
            )
        }
    }
    
    private func symbolsLayer(metrics: KeyboardMetrics) -> some View {
        VStack(spacing: metrics.rowSpacing) {
            layoutRow(
                keys: Array("[]{}#%^*+=").map { KeyModel(title: String($0), kind: .letter) },
                inset: 0,
                metrics: metrics
            )
            layoutRow(
                keys: Array("_\\|~<>'").map { KeyModel(title: String($0), kind: .letter) },
                inset: 0,
                metrics: metrics
            )
            layoutMixedWidthRow(
                keys: Array(",.?!'").map { KeyModel(title: String($0), kind: .letter) } + [
                    KeyModel(title: "123", kind: .switcher),
                    KeyModel(title: "⌫", kind: .delete)
                ],
                inset: 0,
                metrics: metrics,
                keyGapOverride: 7,
                widthOverride: { key, metrics in
                    switch key.kind {
                    case .switcher, .delete:
                        return metrics.shiftWidth
                    default:
                        return nil
                    }
                }
            )
        }
    }

    private func emojiLayer(metrics: KeyboardMetrics) -> some View {
        let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
        let cols = 10
        let rows = 4
        let emojiPages: [[String]] = [
            [
                "😀","😃","😄","😁","😆","🥹","😅","🤣","😂","🙂",
                "😊","😇","🥰","😍","🤩","😘","😗","😚","😙","🥲",
                "😋","😛","😜","🤪","😝","🤑","🤗","🤭","🫢","🫣",
                "🤔","🫡","🤐","🤨","😐","😑","😶","🫥","😏","😒"
            ],
            [
                "🙄","😬","🤥","😌","😔","😪","🤤","😴","😷","🤒",
                "🤕","🤢","🤮","🥵","🥶","🥴","😵","🤯","🤠","🥳",
                "🥸","😎","🤓","🧐","😕","🫤","😟","🙁","😮","😯",
                "😲","😳","🥺","🥹","😦","😧","😨","😰","😥","😢"
            ],
            [
                "😭","😱","😖","😣","😞","😓","😩","😫","🥱","😤",
                "😡","😠","🤬","😈","👿","💀","☠️","💩","🤡","👹",
                "👺","👻","👽","👾","🤖","🎃","😺","😸","😹","😻",
                "😼","😽","🙀","😿","😾","🙈","🙉","🙊","💋","💌"
            ],
            [
                "💘","💝","💖","💗","💓","💞","💕","💟","❣️","💔",
                "❤️","🧡","💛","💚","💙","💜","🖤","🤍","🤎","💔",
                "❤️‍🔥","❤️‍🩹","❣️","💯","💢","💥","💫","💦","💨","🕳️",
                "💣","💬","👁️‍🗨️","🗨️","🗯️","💭","💤","👋","🤚","🖐️"
            ]
        ]
        let totalPages = emojiPages.count

        return GeometryReader { geo in
            let bottomBarHeight: CGFloat = 38
            let gridArea = geo.size.height - bottomBarHeight
            let emojiCellW = geo.size.width / CGFloat(cols)
            let emojiCellH = gridArea / CGFloat(rows)
            let emojiFont = min(emojiCellW, emojiCellH) * 0.75

            VStack(spacing: 0) {
                TabView {
                    ForEach(0..<totalPages, id: \.self) { pageIndex in
                        let pageEmojis = emojiPages[pageIndex]
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: cols),
                            spacing: 0
                        ) {
                            ForEach(Array(pageEmojis.enumerated()), id: \.offset) { _, emoji in
                                Button(action: {
                                    onInsert(emoji)
                                    playKeyClickSound(keyCode: 1104)
                                }) {
                                    Text(emoji)
                                        .font(.system(size: emojiFont))
                                        .frame(width: emojiCellW, height: emojiCellH)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(width: geo.size.width)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack {
                    Button(action: {
                        layer = .letters
                        playKeyClickSound(keyCode: 1104)
                    }) {
                        Text("ABC")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(UIColor.label))
                            .frame(width: 44, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(palette.specialKeyBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(palette.controlBorder, lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        onDelete()
                        triggerHaptic(style: .rigid)
                        playKeyClickSound(keyCode: 1155)
                    }) {
                        Image(systemName: "delete.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(UIColor.label))
                            .frame(width: 44, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(palette.specialKeyBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(palette.controlBorder, lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: bottomBarHeight)
                .padding(.horizontal, 10)
            }
        }
    }

    // MARK: - Main Body

    public init(onInsert: @escaping (String) -> Void,
                onDelete: @escaping () -> Void,
                onReturn: @escaping () -> Void = {},
                onMoveCursor: @escaping (Int) -> Void,
                onGlobe: @escaping () -> Void = {},
                onMic: @escaping () -> Void = {},
                onDismissKeyboard: @escaping () -> Void = {},
                returnKeyTitle: String = "",
                hapticsEnabled: Bool = true) {
        self.onInsert = onInsert
        self.onDelete = onDelete
        self.onReturn = onReturn
        self.onMoveCursor = onMoveCursor
        self.onGlobe = onGlobe
        self.onMic = onMic
        self.onDismissKeyboard = onDismissKeyboard
        self.returnKeyTitle = returnKeyTitle
        self.hapticsEnabled = hapticsEnabled
    }
    
    public var body: some View {
        GeometryReader { geo in
            let metrics = metrics(for: geo.size)

            keyboardContainer(metrics: metrics)
                .padding(.top, UIDevice.current.userInterfaceIdiom == .pad ? 8 : 0)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onDisappear {
            stopDeleteTimer()
        }
        // Global safety net: end any continuous delete when the finger lifts anywhere
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    stopDeleteTimer()
                }
        )

    }
    
    // MARK: - Key Logic
    
    private func keyPressed(char: String) {
        triggerHaptic(style: .light)
        playKeyClickSound(keyCode: 1104)
        
        let toInsert: String
        if layer == .letters && isShiftOn {
            toInsert = char.uppercased()
        } else if layer == .letters {
            toInsert = char.lowercased()
        } else {
            toInsert = char
        }
        onInsert(toInsert)
        
        if layer == .letters && isShiftOn {
            isShiftOn = false
        }
    }
    
    // MARK: - Delete Timers (press down/up driven)
    
    private func startDeleteHoldTimer() {
        // Cancel any existing timers
        deleteTimer?.invalidate()
        isLongPressing = false
        // After delay, begin continuous deletion
        deleteTimer = Timer.scheduledTimer(withTimeInterval: longPressDelay, repeats: false) { _ in
            self.isLongPressing = true
            self.startContinuousDelete()
        }
    }

    private func startContinuousDelete() {
        deleteTimer?.invalidate()
        deleteTimer = Timer.scheduledTimer(withTimeInterval: deleteRepeatInterval, repeats: true) { _ in
            if !self.isLongPressing {
                self.stopDeleteTimer()
                return
            }
            self.onDelete()
            self.triggerHaptic(style: .rigid)
            self.playKeyClickSound(keyCode: 1155)
        }
    }
    
    private func stopDeleteTimer() {
        deleteTimer?.invalidate()
        deleteTimer = nil
        isLongPressing = false
    }
    
    // MARK: - Haptics & Sound
    
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }
        switch style {
        case .rigid:
            Self.rigidHapticGenerator.impactOccurred()
        default:
            Self.hapticGenerator.impactOccurred()
        }
    }
    
    private func playKeyClickSound(keyCode: SystemSoundID) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(keyCode)
    }
}

private extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
