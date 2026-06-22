//
//  PremiumVerseCard.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/02.
//

import SwiftUI
import Foundation

public struct PremiumVerseCard: View {
    let text: String
    let reference: String
    let translationCode: String
    let showTranslationPicker: Bool
    let availableTranslations: [Translation]
    let selectedTranslation: Translation?
    let onSelectTranslation: ((Translation) -> Void)?
    let onTap: () -> Void

    public init(
        text: String,
        reference: String,
        translationCode: String,
        showTranslationPicker: Bool = false,
        availableTranslations: [Translation] = [],
        selectedTranslation: Translation? = nil,
        onSelectTranslation: ((Translation) -> Void)? = nil,
        onTap: @escaping () -> Void
    ) {
        self.text = text
        self.reference = reference
        self.translationCode = translationCode
        self.showTranslationPicker = showTranslationPicker
        self.availableTranslations = availableTranslations
        self.selectedTranslation = selectedTranslation
        self.onSelectTranslation = onSelectTranslation
        self.onTap = onTap
    }

    private var displayReference: String {
        reference.replacingOccurrences(of: " 📖", with: "")
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayReference)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text("Tap to insert")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                
                Text(text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .lineLimit(5)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            .scaleEffect(1.0)
            .animation(.spring(response: 0.3), value: false)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }
}

struct PremiumVerseCard_Previews: PreviewProvider {
    static var previews: some View {
        PremiumVerseCard(
            text: "In the beginning was the Word, and the Word was with God, and the Word was God.",
            reference: "John 1:1",
            translationCode: "KJV",
            onTap: {}
        )
        .padding()
    }
}

// Premium button style for interactive feedback
private struct PremiumCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
