//
//  SearchBar.swift
//  GenUI
//
//  Created by Purav Manot on 28/04/24.
//

import SwiftUIX

struct SearchBar: View {
    @State private var query: String = ""
    @FocusState private var textFieldFocused: Bool
    var isActive: Bool = false
    var onSubmit: ((String) -> Void)?
    
    var body: some View {
        HStack(spacing: 2) {
            #if os(macOS)
            TextField("Search", text: $query, onCommit: {
                textFieldFocused = false
                let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanedQuery.isEmpty else { return }
                self.query = cleanedQuery
                
                onSubmit?(cleanedQuery)
            })
            .font(.body)
            .fontDesign(.monospaced)
            .padding(5)
            .tint(.primary)
            .autocorrectionDisabled()
            .focused($textFieldFocused)
            .interactiveDismissDisabled(false)
            .submitLabel(.search)

            #else
            CocoaTextField("Search", text: $query, onCommit: {
                textFieldFocused = false
                let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanedQuery.isEmpty else { return }
                self.query = cleanedQuery
                
                onSubmit?(cleanedQuery)
            })
            .font(.monospacedSystemFont(ofSize: AppKitOrUIKitFont.systemFontSize, weight: .regular))
            .autocapitalization(.none)
            .dismissKeyboardOnReturn(true)
            .padding(5)
            .keyboardDismissMode(.interactive)
            .tint(.primary)
            .autocorrectionDisabled()
            .focused($textFieldFocused)
            .interactiveDismissDisabled(false)
            .submitLabel(.search)
            #endif
            Button("", systemImage: "xmark") {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    textFieldFocused = false
                }
                
                query = ""
            }
            .buttonStyle(.plain)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .opacity(textFieldFocused ? 1 : 0)
            .disabled(!textFieldFocused)
        }
        .padding(10)
        .background(.quaternary, in: .containerRelative.inset(by: 0.5).stroke(lineWidth: 1))
        .background(Color.highContrastBackground.opacity(0.8), in: .containerRelative)
        .background(.ultraThinMaterial, in: .containerRelative)
        .containerShape(.rect(cornerRadius: 20))
        .padding(10)
        .zIndex(1)
        .animation(.spring, value: textFieldFocused)
    }
}
#Preview {
    SearchBar()
}
