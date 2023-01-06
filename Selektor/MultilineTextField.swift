//
//  MultilineTextField.swift
//  Selektor
//
//  Created by Casey Marshall on 12/1/22.
//

import SwiftUI

struct MultilineTextField: View {
    var placeholder: String
    var onCommit: (() -> Void)?
    @State private var viewHeight: CGFloat = 40
    @State private var shouldShowPlaceholder = false
    @Binding var text: String

    private var internalText: Binding<String> {
        Binding<String>(get: { self.text }) {
            self.text = $0
            self.shouldShowPlaceholder = $0.isEmpty
        }
    }
    
    var body: some View {
#if os(macOS)
        NSTextViewWrapper(text: self.internalText, calculatedHeight: $viewHeight, onDone: onCommit)
            .frame(minHeight: viewHeight, maxHeight: viewHeight)
#else
        UITextViewWrapper(text: self.internalText, calculatedHeight: $viewHeight, onDone: onCommit)
            .frame(minHeight: viewHeight, maxHeight: viewHeight)
            .background(placeholderView, alignment: .topLeading)
#endif
    }
    
    init(placeholder: String, text: Binding<String>, onCommit: (() -> Void)? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.onCommit = onCommit
        self._shouldShowPlaceholder = State<Bool>(initialValue: self.text.isEmpty)
    }
    
    var placeholderView: some View {
        Group {
            if shouldShowPlaceholder {
                Text(placeholder).foregroundColor(.gray)
                    .padding(.leading, 4)
                    .padding(.top, 8)
            }
        }
    }
}

struct MultilineTextField_Previews: PreviewProvider {
    static var text: String = ""
    static var previews: some View {
        MultilineTextField(placeholder: "Text", text: Binding(get: { MultilineTextField_Previews.text }, set: { newValue in MultilineTextField_Previews.text = newValue}))
    }
}
