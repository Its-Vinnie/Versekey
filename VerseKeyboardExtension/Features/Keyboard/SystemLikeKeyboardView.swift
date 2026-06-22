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
    public enum KeyboardLayer { case letters, numbers, symbols }
    
    public let onInsert: (String) -> Void
    public let onDelete: () -> Void
    public let onReturn: () -> Void
    public let onMoveCursor: (Int) -> Void
    public let hapticsEnabled: Bool
    
    @State private var layer: KeyboardLayer = .letters
    @State private var isShiftOn: Bool = false
    @State private var deleteTimer: Timer? = nil
    @State private var isLongPressing: Bool = false
    @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance
    
    private let deleteRepeatInterval = 0.1 // repeat interval during continuous delete
    private let longPressDelay = 0.5 // delay before starting continuous deletion
    private let soundEnabled = true
    
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
    
    private struct KeyModel: Identifiable, Hashable {
        enum Kind { case letter, shift, delete, switcher, space, `return` }
        let id = UUID()
        let title: String
        let kind: Kind
    }
    
    // MARK: - KeyCap View
    
    private struct KeyCap: View {
        let title: String
        let displayedTitle: String
        let width: CGFloat
        let height: CGFloat
        let isSpecial: Bool
        let cornerRadius: CGFloat
        let font: Font
        let onPressDown: (() -> Void)?
        let onPressUp: (() -> Void)?
        let action: () -> Void
        @State private var isDown = false
        @State private var showPopup = false
        @State private var popupText: String = ""
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.hostKeyboardAppearance) private var hostKeyboardAppearance
        
        private struct KeyPreviewBubbleShape: Shape {
            let cornerRadius: CGFloat = 10
            let stemWidth: CGFloat = 18
            let stemHeight: CGFloat = 10
            func path(in rect: CGRect) -> Path {
                var p = Path()
                // Define bubble rect excluding stem area at bottom
                let bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - stemHeight)
                let r = min(cornerRadius, min(bubbleRect.width, bubbleRect.height) / 2)
                // Rounded rect path
                p.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: r, height: r))
                // Stem (triangle) centered at bottom
                let stemCenterX = rect.midX
                let stemTopY = bubbleRect.maxY
                p.move(to: CGPoint(x: stemCenterX - stemWidth/2, y: stemTopY))
                p.addLine(to: CGPoint(x: stemCenterX, y: stemTopY + stemHeight))
                p.addLine(to: CGPoint(x: stemCenterX + stemWidth/2, y: stemTopY))
                p.closeSubpath()
                return p
            }
        }
        
        private struct KeyPreviewBubble: View {
            let text: String
            let minWidth: CGFloat
            let minHeight: CGFloat
            let fontSize: CGFloat
            let debug: Bool
            var body: some View {
                KeyPreviewBubbleShape()
                    .fill(.ultraThickMaterial)
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
                Text(text)
                    .font(.system(size: fontSize, weight: .semibold))
                    .baselineOffset(0)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minWidth: minWidth, minHeight: minHeight, alignment: .center)
                    .foregroundColor(Color(UIColor.label))
                    .background(debug ? Color.red.opacity(0.25) : Color.clear)
            }
        }
        
        var body: some View {
            ZStack {
                Button(action: {
                    action()
                }) {
                    Text(displayedTitle)
                        .font(font)
                        .lineLimit(1)
                        .foregroundColor(Color(UIColor.label)) // Adaptive text color
                        .frame(width: width, height: height)
                        .background(background)
                        .scaleEffect(isDown ? 0.98 : 1.0)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isDown {
                                isDown = true
                                onPressDown?()
                                if !isSpecial {
                                    popupText = displayedTitle
                                    showPopup = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        showPopup = false
                                    }
                                }
                            }
                        }
                        .onEnded { _ in
                            isDown = false
                            onPressUp?()
                            showPopup = false
                        }
                )
                
                if showPopup && !isSpecial {
                    let frozen = popupText.isEmpty ? displayedTitle : popupText
                    KeyPreviewBubble(
                        text: frozen,
                        minWidth: max(width * 1.2, 48),
                        minHeight: 56,
                        fontSize: 32,
                        debug: false
                    )
                    .offset(y: -height * 0.85)
                    .zIndex(9999)
                    .allowsHitTesting(false)
                }
            }
            .zIndex(showPopup ? 1 : 0)
        }
        
        private var background: some View {
            let palette = KeyboardTheme.palette(for: colorScheme, keyboardAppearance: hostKeyboardAppearance)
            return Group {
                if isSpecial {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(palette.specialKeyBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(palette.controlBorder, lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 1, x: 0, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(palette.keyBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(palette.keyHighlight)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 1, x: 0, y: 1)
                }
            }
        }
    }
    
    // MARK: - Layout Helpers

    private func roundedToHalfPoint(_ value: CGFloat) -> CGFloat {
        (value * 2).rounded(.toNearestOrEven) / 2
    }
    
    private func metrics(for size: CGSize) -> KeyboardMetrics {
        let heightScale = min(max(size.height / baseKeyboardHeight, 0.94), 1.38)
        let widthScale = min(max(size.width / 390.0, 0.96), 1.08)

        let desiredTopPadding = min(max(baseTopInset * heightScale, 0), 2)
        let bottomPadding = min(max(minimumBottomInset * heightScale, 4), 7)
        let rowSpacing = min(max(baseRowSpacing * heightScale, 6.5), 8)
        let keyGap = min(max(baseKeyGap * widthScale, 5.5), 6.5)
        let horizontalPadding = min(max(baseHorizontalPadding * widthScale, 3), 5)
        let rowContentWidth = max(size.width - (horizontalPadding * 2), 0)
        let availableKeyHeight = max(
            size.height - desiredTopPadding - bottomPadding - (rowSpacing * 3),
            0
        )
        let keyHeight = min(baseKeyHeight * heightScale, availableKeyHeight / 4)
        let contentHeight = (keyHeight * 4) + (rowSpacing * 3)
        let topPadding = max(size.height - contentHeight - bottomPadding, desiredTopPadding)
        let cornerRadius = min(max(baseCornerRadius * heightScale, 8), 10)
        let letterFontSize = min(max(keyHeight * 0.54, 24), 30)
        let specialFontSize = min(max(keyHeight * 0.36, 17), 21)
        let letterWidth = roundedToHalfPoint((rowContentWidth - (keyGap * 9)) / 10)
        let targetThirdRowInset = min(max(rowContentWidth * 0.008, 2.5), 4)
        let shiftWidth = roundedToHalfPoint(max(
            (rowContentWidth - (letterWidth * 7) - (keyGap * 8) - (targetThirdRowInset * 2)) / 2,
            keyHeight * 1.12
        ))
        let deleteWidth = shiftWidth
        let switcherWidth = roundedToHalfPoint(max(letterWidth * 2.28, baseSwitcherWidth * widthScale * 0.92))
        let returnWidth = roundedToHalfPoint(max(letterWidth * 2.62, baseReturnWidth * widthScale * 0.92))

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
        case .shift, .delete:
            return key.kind == .shift ? metrics.shiftWidth : metrics.deleteWidth
        case .switcher:
            return metrics.switcherWidth
        case .return:
            return metrics.returnWidth
        case .space:
            return letterWidth
        default:
            return letterWidth
        }
    }
    
    private func displayTitle(for char: String, kind: KeyModel.Kind) -> String {
        if kind == .letter {
            return isShiftOn ? char.uppercased() : char.lowercased()
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
        case .switcher, .space, .return, .letter:
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
        case .switcher:
            switch key.title {
            case "123":
                layer = .numbers
                isShiftOn = false
            case "ABC":
                layer = .letters
            case "#+=":
                layer = (layer == .numbers) ? .symbols : .numbers
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

            let items: [(id: UUID, title: String, kind: KeyModel.Kind, width: CGFloat, centerX: CGFloat)] = {
                var x = inset
                var arr: [(UUID, String, KeyModel.Kind, CGFloat, CGFloat)] = []
                for key in keys {
                    let w = widthForKey(key: key, letterWidth: letterWidth, metrics: metrics)
                    let cx = x + w / 2
                    arr.append((key.id, key.title, key.kind, w, cx))
                    x += w + metrics.keyGap
                }
                return arr
            }()
            
            ZStack(alignment: .leading) {
                ForEach(items, id: \.id) { item in
                    KeyCap(
                        title: item.title,
                        displayedTitle: displayTitle(for: item.title, kind: item.kind),
                        width: item.width,
                        height: metrics.keyHeight,
                        isSpecial: item.kind != .letter,
                        cornerRadius: metrics.cornerRadius,
                        font: item.kind != .letter ? metrics.specialFont : metrics.letterFont,
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

            let items: [(id: UUID, title: String, kind: KeyModel.Kind, width: CGFloat, centerX: CGFloat)] = {
                var x = inset
                var arr: [(UUID, String, KeyModel.Kind, CGFloat, CGFloat)] = []
                for key in keys {
                    let w = widthForKey(key: key, letterWidth: letterWidth, metrics: metrics)
                    let cx = x + w / 2
                    arr.append((key.id, key.title, key.kind, w, cx))
                    x += w + metrics.keyGap
                }
                return arr
            }()

            ZStack(alignment: .leading) {
                ForEach(items, id: \.id) { item in
                    KeyCap(
                        title: item.title,
                        displayedTitle: displayTitle(for: item.title, kind: item.kind),
                        width: item.width,
                        height: metrics.keyHeight,
                        isSpecial: item.kind != .letter,
                        cornerRadius: metrics.cornerRadius,
                        font: item.kind != .letter ? metrics.specialFont : metrics.letterFont,
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

            let items: [(id: UUID, title: String, kind: KeyModel.Kind, width: CGFloat, centerX: CGFloat)] = {
                var x = inset
                var arr: [(UUID, String, KeyModel.Kind, CGFloat, CGFloat)] = []
                for key in keys {
                    let overriddenWidth = widthOverride?(key, metrics)
                    let w = overriddenWidth ?? widthForKey(key: key, letterWidth: letterWidth, metrics: metrics)
                    let cx = x + w / 2
                    arr.append((key.id, key.title, key.kind, w, cx))
                    x += w + keyGap
                }
                return arr
            }()

            ZStack(alignment: .leading) {
                ForEach(items, id: \.id) { item in
                    KeyCap(
                        title: item.title,
                        displayedTitle: displayTitle(for: item.title, kind: item.kind),
                        width: item.width,
                        height: metrics.keyHeight,
                        isSpecial: item.kind != .letter,
                        cornerRadius: metrics.cornerRadius,
                        font: item.kind != .letter ? metrics.specialFont : metrics.letterFont,
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
        layoutLetterRow(
            keys: Array("QWERTYUIOP").map { KeyModel(title: String($0), kind: .letter) },
            metrics: metrics
        )
    }
    
    private func row2(metrics: KeyboardMetrics) -> some View {
        layoutLetterRow(
            keys: Array("ASDFGHJKL").map { KeyModel(title: String($0), kind: .letter) },
            metrics: metrics
        )
    }
    
    private func row3(metrics: KeyboardMetrics) -> some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let letters = Array("ZXCVBNM").map { KeyModel(title: String($0), kind: .letter) }
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
            
            let items: [(id: UUID, title: String, kind: KeyModel.Kind, width: CGFloat, centerX: CGFloat)] = {
                var x = inset
                var arr: [(UUID, String, KeyModel.Kind, CGFloat, CGFloat)] = []
                
                let shiftTitle = isShiftOn ? "⇧" : "⇧"
                let shift = KeyModel(title: shiftTitle, kind: .shift)
                arr.append((shift.id, shift.title, shift.kind, shiftW, x + shiftW / 2))
                x += shiftW + rowGap
                
                for ch in letters {
                    arr.append((ch.id, ch.title, ch.kind, letterWidth, x + letterWidth / 2))
                    x += letterWidth + rowGap
                }
                
                let del = KeyModel(title: "⌫", kind: .delete)
                arr.append((del.id, del.title, del.kind, delW, x + delW / 2))
                return arr
            }()
            
            ZStack(alignment: .leading) {
                ForEach(items, id: \.id) { item in
                    KeyCap(
                        title: item.title,
                        displayedTitle: displayTitle(for: item.title, kind: item.kind),
                        width: item.width,
                        height: metrics.keyHeight,
                        isSpecial: item.kind != .letter,
                        cornerRadius: metrics.cornerRadius,
                        font: item.kind != .letter ? metrics.specialFont : metrics.letterFont,
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
                            .stroke(palette.controlBorder, lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 1, x: 0, y: 1)

                Text(title)
                    .font(font)
                    .foregroundStyle(Color(UIColor.label))
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
            let inset: CGFloat = 0
            let availableWidth = screenWidth - (inset * 2)
            
            let switchW = metrics.switcherWidth
            let returnW = metrics.returnWidth
            let rowGap = metrics.keyGap
            let spaceW = availableWidth - (switchW + returnW + 2 * rowGap)
            
            let items: [(id: UUID, title: String, kind: KeyModel.Kind, width: CGFloat, centerX: CGFloat)] = {
                var x = inset
                var arr: [(UUID, String, KeyModel.Kind, CGFloat, CGFloat)] = []
                let switchTitle = (layer == .letters) ? "123" : "ABC"
                let sw = KeyModel(title: switchTitle, kind: .switcher)
                arr.append((sw.id, sw.title, sw.kind, switchW, x + switchW / 2))
                x += switchW + rowGap
                let space = KeyModel(title: "space", kind: .space)
                arr.append((space.id, space.title, space.kind, spaceW, x + spaceW / 2))
                x += spaceW + rowGap
                let ret = KeyModel(title: "Search", kind: .return)
                arr.append((ret.id, ret.title, ret.kind, returnW, x + returnW / 2))
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
                            width: item.width,
                            height: metrics.keyHeight,
                            isSpecial: true,
                            cornerRadius: metrics.cornerRadius,
                            font: metrics.specialFont,
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
        }
        .frame(height: metrics.keyHeight)
    }
    
    // MARK: - Keyboard Container
    
    private func keyboardContainer(metrics: KeyboardMetrics) -> some View {
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
            }
        }
        .padding(.horizontal, metrics.horizontalPadding)
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
    
    // MARK: - Main Body
    
    public init(onInsert: @escaping (String) -> Void,
                onDelete: @escaping () -> Void,
                onReturn: @escaping () -> Void = {},
                onMoveCursor: @escaping (Int) -> Void,
                hapticsEnabled: Bool = true) {
        self.onInsert = onInsert
        self.onDelete = onDelete
        self.onReturn = onReturn
        self.onMoveCursor = onMoveCursor
        self.hapticsEnabled = hapticsEnabled
    }
    
    public var body: some View {
        GeometryReader { geo in
            let metrics = metrics(for: geo.size)

            VStack(spacing: 0) {
                Spacer(minLength: metrics.topPadding)
                keyboardContainer(metrics: metrics)
                Spacer(minLength: metrics.bottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
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
