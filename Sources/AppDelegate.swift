import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let store = WidgetStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        window = makeWindow()
        window.orderFront(nil)
        setupEditMenu()
    }

    private func makeWindow() -> NSWindow {
        let contentView = WidgetView(store: store)
        let hostingView = NSHostingView(rootView: contentView)
        let visualEffect = makeVisualEffect(hosting: hostingView)

        let win = ResizableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 420),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.contentView = visualEffect
        win.minSize = NSSize(width: 260, height: 200)
        win.maxSize = NSSize(width: 600, height: 1_200)
        win.acceptsMouseMovedEvents = true
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        win.isMovableByWindowBackground = true
        win.addResizeCorner()
        win.setFrameAutosaveName("StocksWidget")
        if !win.setFrameUsingName("StocksWidget"), let screen = NSScreen.main {
            let rect = screen.visibleFrame
            win.setFrameOrigin(NSPoint(x: rect.maxX - 320, y: rect.maxY - 440))
        }
        return win
    }

    private func makeVisualEffect(hosting: NSHostingView<WidgetView>) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.state = .active
        view.blendingMode = .behindWindow
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true

        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        return view
    }

    private func setupEditMenu() {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }
}
