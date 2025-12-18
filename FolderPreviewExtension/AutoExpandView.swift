
import SwiftUI
import AppKit

struct AutoExpandView: NSViewRepresentable {
    var onExpand: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Run async to allow the Table to render its NSOutlineView first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = nsView.window {
                if let outlineView = window.contentView?.findInternalOutlineView() {
                    outlineView.expandItem(nil, expandChildren: true)
                }
            }
        }
    }
}

extension NSView {
    func findInternalOutlineView() -> NSOutlineView? {
        if let outline = self as? NSOutlineView {
            return outline
        }
        for subview in subviews {
            if let found = subview.findInternalOutlineView() {
                return found
            }
        }
        return nil
    }
}
