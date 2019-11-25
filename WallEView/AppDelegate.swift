import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var eventMonitor: EventMonitor?

    lazy var statusItem: NSStatusItem = {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = #imageLiteral(resourceName: "StatusBarButtonImage")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showContextMenu(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        return statusItem
    }()

    lazy var statusMenu: NSMenu = {
        let rightClickMenu = NSMenu()
        rightClickMenu.addItem(NSMenuItem(title: "Close", action: #selector(closeApp), keyEquivalent: ""))
        return rightClickMenu
    }()

    lazy var popover: NSPopover = NSPopover()

    @objc func showContextMenu(_ sender: NSStatusBarButton) {
        switch NSApp.currentEvent!.type {
        case .rightMouseUp:
            closePopover(sender: sender)
            // even though this is deprecated, setting `statusItem.menu` results in
            // interactions not being sent any more, not sure why
            statusItem.popUpMenu(statusMenu)
        case .leftMouseUp:
            togglePopover(sender)
        default:
            break
        }
    }

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }

    func showPopover(sender: Any?) {
        if let button = statusItem.button {
            let vc: ViewController? = NSStoryboard.main.viewController()
            popover.contentViewController = vc
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
        eventMonitor?.start()
    }

    func closePopover(sender: Any?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }

    @objc func closeApp() {
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        _ = statusItem

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, self.popover.isShown {
                self.closePopover(sender: event)
            }
        }
    }
}

