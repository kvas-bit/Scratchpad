import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let popoverWidth: CGFloat = 320
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let store = ScratchPadStore()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        let image = NSImage(
            systemSymbolName: "square.and.pencil",
            accessibilityDescription: "ScratchPad"
        )
        image?.isTemplate = true
        button.image = image
        button.toolTip = "ScratchPad"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true

        let rootView = ScratchPadPopoverView(
            store: store,
            onHeightChange: { [weak self] height in
                self?.updatePopoverHeight(height)
            }
        )
        .frame(width: popoverWidth)
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: popoverWidth, height: 170)
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: popoverWidth, height: 170)
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func updatePopoverHeight(_ height: CGFloat) {
        let targetHeight = max(170, ceil(height))
        guard abs(popover.contentSize.height - targetHeight) > 0.5 else { return }
        popover.contentSize = NSSize(width: popoverWidth, height: targetHeight)
    }
}
