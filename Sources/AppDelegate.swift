import AppKit
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let store = WidgetStore()
    private var statusItem: NSStatusItem?
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        window = makeWindow()
        window.orderFront(nil)
        setupEditMenu()
        setupStatusBar()
        store.startRefreshLoop()
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

    // MARK: - Menu bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.action = #selector(toggleWindow)
        button.target = self
        button.title = "◆"
        cancellable = store.$tickers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tickers in
                guard let button = self?.statusItem?.button else { return }
                self?.updateStatusButton(button, tickers: tickers)
            }
    }

    private func updateStatusButton(_ button: NSStatusBarButton, tickers: [TickerQuote]) {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "Stocks ", attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ]))

        guard !tickers.isEmpty else {
            result.append(NSAttributedString(string: "◆", attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 11, weight: .medium)
            ]))
            button.attributedTitle = result
            return
        }

        let avg = tickers.map { $0.dailyChangePercent }.reduce(0, +) / Double(tickers.count)
        let color: NSColor = avg >= 0 ? .systemGreen : .systemRed
        let text = String(format: "%+.1f%%", avg)
        result.append(NSAttributedString(string: text, attributes: [
            .foregroundColor: color,
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        ]))
        button.attributedTitle = result
    }

    @objc private func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Edit menu

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
