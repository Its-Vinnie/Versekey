// SearchFieldView.swift
// A UIKit-backed search field that hides the system caret and renders a custom controllable caret
// to avoid competing with the host app's cursor while the keyboard's internal search is focused.

import SwiftUI
import UIKit

public final class CaretControllableTextField: UITextField {
    // Controls whether the system caret should be drawn by UIKit
    var showsSystemCaret: Bool = false { didSet { setNeedsLayout() } }
    // Controls whether selection handles/menus are allowed
    var allowsSelection: Bool = false
    // When true, we render a custom blinking caret view at the insertion point
    var usesCustomCaret: Bool = true { didSet { updateCustomCaretVisibility() } }

    // Appearance
    var customCaretWidth: CGFloat = 2.0
    var customCaretColor: UIColor = .label
    var customCaretCornerRadius: CGFloat = 1.0
    var customCaretBlinkDuration: TimeInterval = 0.6

    // Internal caret view + timer
    private let customCaretView = UIView()
    private var blinkTimer: Timer?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        borderStyle = .none
        backgroundColor = .clear
        tintColor = .clear // Hide the system tint to avoid accidental system caret coloring
        customCaretView.backgroundColor = customCaretColor
        customCaretView.layer.cornerRadius = customCaretCornerRadius
        customCaretView.isUserInteractionEnabled = false
        addSubview(customCaretView)
        updateCustomCaretVisibility()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        positionCustomCaret()
    }

    public override func caretRect(for position: UITextPosition) -> CGRect {
        // Return zero rect to hide the system caret when requested
        if !showsSystemCaret { return .zero }
        return super.caretRect(for: position)
    }

    public override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        // Disable selection handles/rects when not allowed
        if !allowsSelection { return [] }
        return super.selectionRects(for: range)
    }

    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Disable copy/paste menu if selection is not allowed
        if !allowsSelection { return false }
        return super.canPerformAction(action, withSender: sender)
    }

    func updateCustomCaretVisibility() {
        customCaretView.isHidden = !(usesCustomCaret && isFirstResponder)
        if customCaretView.isHidden {
            stopBlinking()
        } else {
            startBlinking()
        }
    }

    func positionCustomCaret() {
        guard usesCustomCaret, isFirstResponder else { return }
        // Try to get the caret rect from super while we keep system caret hidden for drawing
        if let range = selectedTextRange {
            let rect = super.caretRect(for: range.start)
            // Convert to our coordinate space if needed (already in our view)
            var caretFrame = rect
            caretFrame.size.width = customCaretWidth
            customCaretView.frame = caretFrame
            customCaretView.backgroundColor = customCaretColor
            customCaretView.layer.cornerRadius = customCaretCornerRadius
            bringSubviewToFront(customCaretView)
        }
    }

    private func startBlinking() {
        stopBlinking()
        customCaretView.alpha = 1.0
        blinkTimer = Timer.scheduledTimer(withTimeInterval: customCaretBlinkDuration, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            UIView.animate(withDuration: self.customCaretBlinkDuration / 2.0) {
                self.customCaretView.alpha = self.customCaretView.alpha == 1.0 ? 0.0 : 1.0
            }
        }
    }

    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        customCaretView.alpha = 1.0
    }

    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        updateCustomCaretVisibility()
        setNeedsLayout()
        return result
    }

    public override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        updateCustomCaretVisibility()
        setNeedsLayout()
        return result
    }
}

public struct SearchFieldView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    // Configuration
    var placeholder: String
    var font: UIFont = .systemFont(ofSize: 17)
    var textColor: UIColor = .label
    var placeholderColor: UIColor = .secondaryLabel
    var returnKeyType: UIReturnKeyType = .search

    // Behavior
    var onReturn: (() -> Void)? = nil
    var onFocusChanged: ((Bool) -> Void)? = nil

    // Caret controls
    var hideSystemCaretWhenFocused: Bool = true
    var useCustomCaretWhenFocused: Bool = true

    public init(text: Binding<String>,
                isFocused: Binding<Bool>,
                placeholder: String,
                onReturn: (() -> Void)? = nil,
                onFocusChanged: ((Bool) -> Void)? = nil) {
        self._text = text
        self._isFocused = isFocused
        self.placeholder = placeholder
        self.onReturn = onReturn
        self.onFocusChanged = onFocusChanged
    }

    public func makeUIView(context: Context) -> CaretControllableTextField {
        let tf = CaretControllableTextField()
        tf.delegate = context.coordinator
        tf.font = font
        tf.textColor = textColor
        tf.returnKeyType = returnKeyType
        tf.clearButtonMode = .whileEditing
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.text = text
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)

        // Placeholder styling
        tf.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: placeholderColor
        ])

        // Disable selection when using custom caret
        tf.allowsSelection = false

        // Initial caret configuration
        tf.showsSystemCaret = !(hideSystemCaretWhenFocused && isFocused)
        tf.usesCustomCaret = (useCustomCaretWhenFocused && isFocused)

        return tf
    }

    public func updateUIView(_ uiView: CaretControllableTextField, context: Context) {
        // Sync text if needed
        if uiView.text != text { uiView.text = text }

        // Focus handling
        if isFocused && !uiView.isFirstResponder {
            _ = uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            _ = uiView.resignFirstResponder()
        }

        // Caret configuration depending on focus
        uiView.showsSystemCaret = !(hideSystemCaretWhenFocused && isFocused)
        uiView.usesCustomCaret = (useCustomCaretWhenFocused && isFocused)
        uiView.setNeedsLayout()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SearchFieldView

        init(_ parent: SearchFieldView) {
            self.parent = parent
        }

        @objc func textDidChange(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            // Focus gained
            if !parent.isFocused { parent.isFocused = true }
            parent.onFocusChanged?(true)
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
            // Focus lost
            if parent.isFocused { parent.isFocused = false }
            parent.onFocusChanged?(false)
        }

        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onReturn?()
            textField.resignFirstResponder()
            return true
        }

        public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Allow all changes; binding is updated via editingChanged target
            return true
        }

        public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            // Always allow focus
            return true
        }
    }
}

// MARK: - SwiftUI convenience wrapper view with glow/caret control

public struct VerseKeySearchField: View {
    @Binding var text: String
    @Binding var isFocused: Bool

    var placeholder: String
    var onReturn: (() -> Void)?

    public init(text: Binding<String>,
                isFocused: Binding<Bool>,
                placeholder: String = "Search",
                onReturn: (() -> Void)? = nil) {
        self._text = text
        self._isFocused = isFocused
        self.placeholder = placeholder
        self.onReturn = onReturn
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            SearchFieldView(text: $text, isFocused: $isFocused, placeholder: placeholder, onReturn: onReturn) { focused in
                // No-op: external binding already updated
            }
            .frame(height: 36)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isFocused ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
