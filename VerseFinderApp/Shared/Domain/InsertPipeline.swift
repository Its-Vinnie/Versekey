//
//  KeyboardInsertPipeline.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/02.
//

import Foundation
import UIKit

public protocol InsertPipeline {
    func insert(_ text: String)
    func deleteBackward()
    func moveCursor(by offset: Int)
    func setPassiveMode(_ passive: Bool)
}

// For in-app previews or fallback insertion via clipboard
public struct ClipboardInsertPipeline: InsertPipeline {
    public init() {}
    public func insert(_ text: String) { UIPasteboard.general.string = text }
    public func deleteBackward() { /* no-op for clipboard */ }
    public func moveCursor(by offset: Int) { /* no-op for clipboard */ }
    public func setPassiveMode(_ passive: Bool) { /* no-op for clipboard */ }
}

// For the keyboard extension: wraps textDocumentProxy operations via closures
public struct KeyboardProxyInsertPipeline: InsertPipeline {
    private final class PassiveStateBox {
        var isPassive: Bool = false
    }

    private let insertHandler: (String) -> Void
    private let deleteHandler: () -> Void
    private let adjustCursorHandler: (Int) -> Void
    private let passiveModeHandler: (Bool) -> Void
    private let passiveState = PassiveStateBox()

    public init(
        insertHandler: @escaping (String) -> Void,
        deleteHandler: @escaping () -> Void,
        adjustCursorHandler: @escaping (Int) -> Void,
        passiveModeHandler: @escaping (Bool) -> Void
    ) {
        self.insertHandler = insertHandler
        self.deleteHandler = deleteHandler
        self.adjustCursorHandler = adjustCursorHandler
        self.passiveModeHandler = passiveModeHandler
    }

    public func insert(_ text: String) {
        guard !text.isEmpty else { return }
        guard !passiveState.isPassive else { return }
        insertHandler(text)
    }

    public func deleteBackward() {
        guard !passiveState.isPassive else { return }
        deleteHandler()
    }

    public func moveCursor(by offset: Int) {
        guard offset != 0 else { return }
        guard !passiveState.isPassive else { return }
        adjustCursorHandler(offset)
    }
    
    public func setPassiveMode(_ passive: Bool) {
        passiveState.isPassive = passive
        passiveModeHandler(passive)
    }
}
