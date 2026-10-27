import AppKit

/// Floating, non-activating HUD showing a grid of window previews.
final class SwitcherPanel {
    var onClick: ((Int) -> Void)?

    private let panel: NSPanel
    private let background = NSVisualEffectView()
    private let grid = NSStackView()
    private var items: [ItemView] = []

    private let padding: CGFloat = 16
    private let spacing: CGFloat = 8

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 20
        background.layer?.masksToBounds = true

        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = spacing
        grid.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: padding),
            grid.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -padding),
            grid.topAnchor.constraint(equalTo: background.topAnchor, constant: padding),
            grid.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -padding),
        ])
        panel.contentView = background
    }

    var isVisible: Bool { panel.isVisible }

    func show(_ apps: [NSRunningApplication], selected: Int, previews: (pid_t) -> NSImage?) {
        guard let screen = NSScreen.main, !apps.isEmpty else { return }
        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let (width, columns) = layout(count: apps.count, in: screen.visibleFrame.size)
        items = apps.enumerated().map { index, app in
            let item = ItemView(app: app, width: width, preview: previews(app.processIdentifier))
            item.onClick = { [weak self] in self?.onClick?(index) }
            return item
        }
        for start in stride(from: 0, to: items.count, by: columns) {
            let row = NSStackView(views: Array(items[start..<min(start + columns, items.count)]))
            row.spacing = spacing
            grid.addArrangedSubview(row)
        }
        select(selected)

        let size = background.fittingSize
        let frame = screen.visibleFrame
        panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                              width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
    }

    func select(_ index: Int) {
        for (i, item) in items.enumerated() { item.isSelected = i == index }
    }

    func setPreview(_ image: NSImage, for pid: pid_t) {
        items.first { $0.pid == pid }?.preview = image
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// Largest tile width (and matching column count) that fits every app on screen.
    private func layout(count: Int, in screen: NSSize) -> (width: CGFloat, columns: Int) {
        let maxWidth = screen.width * 0.9 - padding * 2
        let maxHeight = screen.height * 0.85 - padding * 2
        var width: CGFloat = 240
        while true {
            let columns = max(1, min(count, Int((maxWidth + spacing) / (width + spacing))))
            let rows = (count + columns - 1) / columns
            let height = CGFloat(rows) * (ItemView.height(forWidth: width) + spacing) - spacing
            if height <= maxHeight || width <= 80 { return (width, columns) }
            width -= 10
        }
    }
}

private final class ItemView: NSView {
    static let titleHeight: CGFloat = 22
    static func height(forWidth width: CGFloat) -> CGFloat { width * 0.625 + titleHeight + 12 }

    let pid: pid_t
    var onClick: (() -> Void)?
    var isSelected = false {
        didSet {
            layer?.backgroundColor = isSelected ? NSColor.white.withAlphaComponent(0.18).cgColor : nil
            label.textColor = isSelected ? .labelColor : .secondaryLabelColor
        }
    }
    var preview: NSImage? {
        didSet { thumbnail.image = preview ?? icon }
    }

    private let icon: NSImage?
    private let thumbnail = NSImageView()
    private let label: NSTextField

    init(app: NSRunningApplication, width: CGFloat, preview: NSImage?) {
        pid = app.processIdentifier
        icon = app.icon
        label = NSTextField(labelWithString: app.localizedName ?? "")
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        setAccessibilityLabel(app.localizedName)

        thumbnail.imageScaling = .scaleProportionallyUpOrDown
        thumbnail.image = preview ?? icon
        let smallIcon = NSImageView(image: app.icon ?? NSImage())
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = .secondaryLabelColor
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        for view in [thumbnail, smallIcon, label] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width),
            heightAnchor.constraint(equalToConstant: Self.height(forWidth: width)),
            smallIcon.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            smallIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            smallIcon.widthAnchor.constraint(equalToConstant: 18),
            smallIcon.heightAnchor.constraint(equalToConstant: 18),
            label.centerYAnchor.constraint(equalTo: smallIcon.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: smallIcon.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            thumbnail.topAnchor.constraint(equalTo: topAnchor, constant: Self.titleHeight + 4),
            thumbnail.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            thumbnail.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            thumbnail.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
