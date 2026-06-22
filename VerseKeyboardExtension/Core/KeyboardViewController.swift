//
//  KeyboardViewController.swift
//  VerseKeyboardExtension
//
//  Created by Maphari Vincent on 2026/03/02.
//

import UIKit
import SwiftUI

private enum KeyboardLayout {
    static let height: CGFloat = 260
}

private final class FixedHeightKeyboardInputView: UIInputView {
    let fixedHeight: CGFloat

    private var fixedHeightConstraint: NSLayoutConstraint?

    init(height: CGFloat) {
        self.fixedHeight = height
        let initialWidth = UIScreen.main.bounds.width
        super.init(frame: CGRect(x: 0, y: 0, width: initialWidth, height: height), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        isOpaque = false
        clipsToBounds = true
        preservesSuperviewLayoutMargins = false
        insetsLayoutMarginsFromSafeArea = false
        layoutMargins = .zero
        installHeightConstraint()
    }

    required init?(coder: NSCoder) {
        self.fixedHeight = KeyboardLayout.height
        super.init(coder: coder)
        allowsSelfSizing = true
        isOpaque = false
        clipsToBounds = true
        preservesSuperviewLayoutMargins = false
        insetsLayoutMarginsFromSafeArea = false
        layoutMargins = .zero
        installHeightConstraint()
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

    private func installHeightConstraint() {
        fixedHeightConstraint?.isActive = false
        let constraint = heightAnchor.constraint(equalToConstant: fixedHeight)
        constraint.priority = .required
        constraint.isActive = true
        fixedHeightConstraint = constraint
    }
}

final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardView>?
    private var controllerHeightConstraint: NSLayoutConstraint?
    private let appearanceStore = KeyboardAppearanceStore()
    private let compactKeyboardHeight = KeyboardLayout.height
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
        view.backgroundColor = keyboardBackgroundColor
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
            appearanceStore: appearanceStore
        )
        let host = UIHostingController(rootView: rootView)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = keyboardBackgroundColor
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.view.preservesSuperviewLayoutMargins = false
        host.view.layoutMargins = .zero
        host.additionalSafeAreaInsets = .zero
        view.backgroundColor = keyboardBackgroundColor
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
        preferredContentSize = CGSize(width: 0, height: compactKeyboardHeight)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshKeyboardAppearance()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshKeyboardAppearance()
    }

    private func refreshKeyboardAppearance() {
        appearanceStore.keyboardAppearance = currentKeyboardAppearance
        let color = keyboardBackgroundColor
        view.backgroundColor = color
        inputView?.backgroundColor = color
        hostingController?.view.backgroundColor = color
    }

    override func updateViewConstraints() {
        if controllerHeightConstraint == nil {
            let constraint = view.heightAnchor.constraint(equalToConstant: compactKeyboardHeight)
            constraint.priority = UILayoutPriority(999)
            constraint.isActive = true
            controllerHeightConstraint = constraint
        }
        controllerHeightConstraint?.constant = compactKeyboardHeight
        preferredContentSize = CGSize(width: 0, height: compactKeyboardHeight)
        super.updateViewConstraints()
    }

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            self.applyPreferredKeyboardHeight()
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}
