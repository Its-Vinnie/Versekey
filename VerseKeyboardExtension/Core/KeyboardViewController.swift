//
//  KeyboardViewController.swift
//  VerseKeyboardExtension
//
//  Created by Maphari Vincent on 2026/03/02.
//

import UIKit
import SwiftUI

private enum KeyboardLayout {
    /// Fixed heights — never recalculated to prevent resize-on-focus loops.
    /// iPad portrait needs ~287pt, landscape ~326pt. Use 330pt to fit both.
    /// iPhone: 260pt — never changed.
    static var height: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad { return 330 }
        return 260
    }
}

private final class FixedHeightKeyboardInputView: UIInputView {
    let fixedHeight: CGFloat

    private var fixedHeightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?

    init(height: CGFloat) {
        self.fixedHeight = height
        let initialWidth = UIScreen.main.bounds.width
        super.init(frame: CGRect(x: 0, y: 0, width: initialWidth, height: height), inputViewStyle: .keyboard)
        allowsSelfSizing = false
        isOpaque = false
        clipsToBounds = true
        preservesSuperviewLayoutMargins = false
        insetsLayoutMarginsFromSafeArea = false
        layoutMargins = .zero
        installConstraints()
    }

    required init?(coder: NSCoder) {
        self.fixedHeight = KeyboardLayout.height
        super.init(coder: coder)
        allowsSelfSizing = false
        isOpaque = false
        clipsToBounds = true
        preservesSuperviewLayoutMargins = false
        insetsLayoutMarginsFromSafeArea = false
        layoutMargins = .zero
        installConstraints()
    }

    override var safeAreaInsets: UIEdgeInsets {
        .zero
    }

    override var layoutMargins: UIEdgeInsets {
        get { .zero }
        set { super.layoutMargins = .zero }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: fixedHeight)
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        CGSize(width: targetSize.width, height: fixedHeight)
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        CGSize(width: targetSize.width, height: fixedHeight)
    }

    override func updateConstraints() {
        fixedHeightConstraint?.constant = fixedHeight
        super.updateConstraints()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        installWidthIfNeeded()
    }

    private func installConstraints() {
        // Height constraint
        fixedHeightConstraint?.isActive = false
        let heightC = heightAnchor.constraint(equalToConstant: fixedHeight)
        heightC.priority = .required
        heightC.isActive = true
        fixedHeightConstraint = heightC

        installWidthIfNeeded()
    }

    private func installWidthIfNeeded() {
        guard widthConstraint == nil, let superview else { return }
        let widthC = widthAnchor.constraint(equalTo: superview.widthAnchor)
        widthC.priority = .required
        widthC.isActive = true
        widthConstraint = widthC
    }
}

final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardView>?
    private var controllerHeightConstraint: NSLayoutConstraint?
    private let appearanceStore = KeyboardAppearanceStore()
    private let compactKeyboardHeight: CGFloat = KeyboardLayout.height
    private var keyboardBackgroundColor: UIColor {
        KeyboardTheme.nativeKeyboardBackgroundUIColor(
            for: traitCollection,
            keyboardAppearance: currentKeyboardAppearance
        )
    }

    private var currentKeyboardAppearance: UIKeyboardAppearance {
        textDocumentProxy.keyboardAppearance ?? .default
    }

    override func loadView() {
        view = FixedHeightKeyboardInputView(height: compactKeyboardHeight)
        view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        FullAccessStatus.isFullAccessGranted = self.hasFullAccess

        applyPreferredKeyboardHeight()
        setupKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        FullAccessStatus.isFullAccessGranted = self.hasFullAccess
        applyPreferredKeyboardHeight()

        if hostingController == nil {
            setupKeyboard()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        FullAccessStatus.isFullAccessGranted = self.hasFullAccess
        refreshKeyboardAppearance()
        print("[Keyboard] viewDidAppear. Full Access: \(self.hasFullAccess)")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    private func setupKeyboard() {
        cleanupKeyboard()

        let inserter = KeyboardProxyInsertPipeline(
            insertHandler: { [weak self] text in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.textDocumentProxy.insertText(text)
                }
            },
            deleteHandler: { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.textDocumentProxy.deleteBackward()
                }
            },
            adjustCursorHandler: { [weak self] offset in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
                }
            },
            passiveModeHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.view.alpha = 1.0
                }
            }
        )

        let rootView = KeyboardView(
            inserter: inserter,
            suppressesSystemKeyboard: true,
            appearanceStore: appearanceStore,
            onGlobe: { [weak self] in
                self?.advanceToNextInputMode()
            },
            onDismissKeyboard: { [weak self] in
                self?.view.endEditing(true)
            }
        )
        let host = UIHostingController(rootView: rootView)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.view.preservesSuperviewLayoutMargins = false
        host.view.layoutMargins = .zero
        host.additionalSafeAreaInsets = .zero
        view.backgroundColor = .clear
        view.isOpaque = false
        view.clipsToBounds = true
        view.insetsLayoutMarginsFromSafeArea = false
        view.preservesSuperviewLayoutMargins = false
        view.layoutMargins = .zero

        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        self.hostingController = host
        refreshKeyboardAppearance()
        applyPreferredKeyboardHeight()
        view.setNeedsUpdateConstraints()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func applyPreferredKeyboardHeight() {
        preferredContentSize = CGSize(width: 0, height: compactKeyboardHeight)
        controllerHeightConstraint?.constant = compactKeyboardHeight
    }

    private func cleanupKeyboard() {
        if let host = hostingController {
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
            hostingController = nil
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshKeyboardAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshKeyboardAppearance()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshKeyboardAppearance()
        // When the host app's text changes, the host input has focus.
        // Notify the keyboard view so it can release search bar focus.
        appearanceStore.notifyHostInputFocused()
    }

    private func refreshKeyboardAppearance() {
        appearanceStore.keyboardAppearance = currentKeyboardAppearance
        view.backgroundColor = .clear
        inputView?.backgroundColor = .clear
        hostingController?.view.backgroundColor = .clear
    }

    override func updateViewConstraints() {
        if controllerHeightConstraint == nil {
            let constraint = view.heightAnchor.constraint(equalToConstant: compactKeyboardHeight)
            constraint.priority = UILayoutPriority(999)
            constraint.isActive = true
            controllerHeightConstraint = constraint
        }
        preferredContentSize = CGSize(width: 0, height: compactKeyboardHeight)
        super.updateViewConstraints()
    }

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        // The host app is about to change text, meaning it has focus.
        // Notify the keyboard view to release search bar focus.
        appearanceStore.notifyHostInputFocused()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil, completion: nil)
    }
}
