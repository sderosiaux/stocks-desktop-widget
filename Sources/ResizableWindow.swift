import AppKit

class ResizableWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    func addResizeCorner() {
        guard let content = contentView else { return }
        let corner = ResizeCornerView()
        corner.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(corner)
        NSLayoutConstraint.activate([
            corner.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            corner.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            corner.widthAnchor.constraint(equalToConstant: 36),
            corner.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
}

class ResizeCornerView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setStrokeColor(NSColor.labelColor.withAlphaComponent(0.2).cgColor)
        ctx.setLineWidth(1)
        let offsets: [CGFloat] = [4, 8, 12]
        for offset in offsets {
            ctx.move(to: CGPoint(x: bounds.maxX - offset, y: bounds.minY))
            ctx.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + offset))
            ctx.strokePath()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        let startFrame = window.frame
        let startMouse = window.convertPoint(toScreen: event.locationInWindow)

        var keepRunning = true
        while keepRunning {
            guard let next = NSApp.nextEvent(
                matching: [.leftMouseDragged, .leftMouseUp],
                until: .distantFuture,
                inMode: .eventTracking,
                dequeue: true
            ) else { continue }

            switch next.type {
            case .leftMouseDragged:
                let current = window.convertPoint(toScreen: next.locationInWindow)
                let deltaX = current.x - startMouse.x
                let deltaY = startMouse.y - current.y

                var newWidth = startFrame.width + deltaX
                var newHeight = startFrame.height + deltaY
                newWidth = max(window.minSize.width, min(window.maxSize.width, newWidth))
                newHeight = max(window.minSize.height, min(window.maxSize.height, newHeight))

                let newOrigin = NSPoint(x: startFrame.origin.x, y: startFrame.maxY - newHeight)
                window.setFrame(
                    NSRect(origin: newOrigin, size: NSSize(width: newWidth, height: newHeight)),
                    display: true
                )

            case .leftMouseUp:
                keepRunning = false
                window.saveFrame(usingName: window.frameAutosaveName)

            default:
                break
            }
        }
    }
}
