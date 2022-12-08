//
//  UITextViewWrapper.swift
//  Selektor
//
//  Created by Casey Marshall on 12/1/22.
//

import SwiftUI
import UIKit

final class Coordinator: NSObject, UITextViewDelegate {
    var text: Binding<String>
    var calculatedHeight: Binding<CGFloat>
    var onDone: (() -> Void)?
    
    init(text: Binding<String>, calculatedHeight: Binding<CGFloat>, onDone: (() -> Void)?) {
        self.text = text
        self.calculatedHeight = calculatedHeight
        self.onDone = onDone
    }
    
    func textViewDidChange(_ textView: UITextView) {
        text.wrappedValue = textView.text
        UITextViewWrapper.recalculateHeight(view: textView, result: calculatedHeight)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let onDone = self.onDone, text == "\n" {
            textView.resignFirstResponder()
            onDone()
            return false
        }
        return true
    }
}

struct UITextViewWrapper: UIViewRepresentable {
    typealias UIViewType = UITextView
    
    var text: Binding<String>
    var calculatedHeight: Binding<CGFloat>
    var onDone: (() -> Void)?
    
    func makeUIView(context: UIViewRepresentableContext<UITextViewWrapper>) -> UITextView {
        let textField = UITextView()
        textField.delegate = context.coordinator
        textField.isEditable = true
        textField.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textField.isSelectable = true
        textField.isScrollEnabled = false
        textField.backgroundColor = UIColor.clear
        textField.keyboardType = .asciiCapable
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        if nil != onDone {
            textField.returnKeyType = .done
        }
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textField
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != self.text.wrappedValue {
            uiView.text = self.text.wrappedValue
        }
        /*if uiView.window != nil, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }*/
        UITextViewWrapper.recalculateHeight(view: uiView, result: calculatedHeight)
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: text, calculatedHeight: calculatedHeight, onDone: onDone)
    }
    
    static func recalculateHeight(view: UITextView, result: Binding<CGFloat>) {
        let newSize = view.sizeThatFits(CGSize(width: view.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
        if result.wrappedValue != newSize.height {
            DispatchQueue.main.async {
                result.wrappedValue = newSize.height
            }
        }
    }
}
