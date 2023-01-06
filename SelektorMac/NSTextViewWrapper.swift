//
//  NSTextFieldAdapter.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/2/23.
//

import SwiftUI
import AppKit

class CustomTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == "\n" {
            self.window?.makeFirstResponder(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

final class Coordinator: NSObject, NSTextViewDelegate {
    var text: Binding<String>
    var calculatedHeight: Binding<CGFloat>
    var onDone: (() -> Void)?
    
    init(text: Binding<String>, calculatedHeight: Binding<CGFloat>, onDone: (() -> Void)?) {
        self.text = text
        self.calculatedHeight = calculatedHeight
        self.onDone = onDone
    }
    
    func textDidChange(_ notification: Notification) {
        logger.debug("textDidChange \(notification)")
        guard let textView = notification.object as? NSTextView else {
            logger.warning("notification object was not a NSTextView \(notification.object) -- \(notification)")
            return
        }
        text.wrappedValue = textView.string
            .replacingOccurrences(of: "\n", with: " ")
            .replacing(try! Regex(" +"), with: " ")
        NSTextViewWrapper.recalculateHeight(view: textView, result: calculatedHeight)
    }
    
    func textDidEndEditing(_ notification: Notification) {
        if let onDone = onDone {
            onDone()
        }
    }
}

class ResizeObserver {
    var calculatedHeight: Binding<CGFloat>
    var prevFrame: CGRect = CGRect(x: 0, y: 0, width: 0, height: 0)
    lazy var updaterFunc = {
        debounce(interval: 500, queue: DispatchQueue.main) { view in
            NSTextViewWrapper.recalculateHeight(view: view, result: self.calculatedHeight)
        }
    }()
    
    init(calculatedHeight: Binding<CGFloat>) {
        self.calculatedHeight = calculatedHeight
    }
    
    func onFrameChanged(_ notification: Notification) {
        logger.debug("onFrameChanged \(notification)")
        guard let view = notification.object as? NSTextView else {
            return
        }
        let newFrame = view.frame
        if newFrame.width != prevFrame.width {
            updaterFunc(view)
        }
        prevFrame = newFrame
    }
}

struct NSTextViewWrapper: NSViewRepresentable {
    typealias NSViewType = NSTextView
    
    var text: Binding<String>
    var calculatedHeight: Binding<CGFloat>
    var onDone: (() -> Void)?
    var previousFrame: CGRect = CGRect(x: 0, y: 0, width: 0, height: 0)
    var resizeObserver: ResizeObserver
    
    init(text: Binding<String>, calculatedHeight: Binding<CGFloat>, onDone: (() -> Void)?) {
        self.text = text
        self.calculatedHeight = calculatedHeight
        self.onDone = onDone
        self.resizeObserver = ResizeObserver(calculatedHeight: calculatedHeight)
    }
    
    func makeNSView(context: Context) -> NSTextView {
        let textField = CustomTextView()
        textField.delegate = context.coordinator
        textField.isEditable = true
        textField.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textField.isSelectable = true
        textField.backgroundColor = .clear
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.autoresizingMask = [.width]
        textField.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: textField, queue: nil, using: resizeObserver.onFrameChanged(_:))
        return textField
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
        logger.debug("updateNSView \(nsView)")
        if nsView.string != self.text.wrappedValue {
            nsView.string = self.text.wrappedValue
        }
        NSTextViewWrapper.recalculateHeight(view: nsView, result: calculatedHeight)
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: text, calculatedHeight: calculatedHeight, onDone: onDone)
    }
    
    static func recalculateHeight(view: NSTextView, result: Binding<CGFloat>) {
        let newSize = view.visibleRect
        logger.info("recalc size newSize: \(newSize)")
        if result.wrappedValue != newSize.height {
            DispatchQueue.main.async {
                result.wrappedValue = newSize.height
            }
        }
    }
}
