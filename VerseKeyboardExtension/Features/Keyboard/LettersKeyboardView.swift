//
//  LettersKeyboardView.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/02.
//


import SwiftUI

public struct LettersKeyboardView: View {
    let onInsert: (String) -> Void
    let onDelete: () -> Void

    public init(onInsert: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.onInsert = onInsert
        self.onDelete = onDelete
    }

    private let rows: [[String]] = [
        ["q","w","e","r","t","y","u","i","o","p"],
        ["a","s","d","f","g","h","j","k","l"],
        ["z","x","c","v","b","n","m"],
    ]

    public var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        Button(action: { onInsert(key) }) {
                            Text(key.uppercased())
                                .font(.body)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                Button(action: { onDelete() }) {
                    Image(systemName: "delete.left")
                        .font(.body)
                        .frame(width: 60)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button(action: { onInsert(" ") }) {
                    Text("space")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct LettersKeyboardView_Previews: PreviewProvider {
    static var previews: some View {
        LettersKeyboardView(onInsert: { _ in }, onDelete: {})
            .padding()
    }
}
