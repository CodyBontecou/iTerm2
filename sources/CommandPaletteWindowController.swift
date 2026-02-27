//
//  CommandPaletteWindowController.swift
//  iTerm2
//
//  Created for Command Palette feature
//

import AppKit

@objc(iTermCommandPaletteWindowController)
class CommandPaletteWindowController: NSWindowController {

    // MARK: - Singleton

    @objc static let shared = CommandPaletteWindowController()

    // MARK: - UI Components

    private let searchField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = "Type a command…"
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 16)
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let tableView: NSTableView = {
        let table = NSTableView()
        table.headerView = nil
        table.rowHeight = 36
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .none
        table.allowsMultipleSelection = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CommandColumn"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)

        return table
    }()

    private let scrollView: NSScrollView = {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    private let visualEffectView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .menu
        view.state = .active
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let dividerView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.separatorColor.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Model

    private let model = CommandPaletteModel()

    // MARK: - Constants

    private let windowWidth: CGFloat = 600
    private let maxWindowHeight: CGFloat = 400
    private let searchFieldHeight: CGFloat = 44
    private let topMargin: CGFloat = 170

    // MARK: - Initialization

    private init() {
        let contentRect = NSRect(x: 0, y: 0, width: 600, height: 400)
        let window = CommandPaletteWindow(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )

        super.init(window: window)

        setupWindow()
        setupViews()
        setupConstraints()
        setupTableView()
        setupSearchField()
    }

    required init?(coder: NSCoder) {
        it_fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupWindow() {
        guard let window = self.window else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .modalPanel
        window.delegate = self

        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 12
        window.contentView?.layer?.masksToBounds = true
        window.contentView?.layer?.borderWidth = 0.5
        window.contentView?.layer?.borderColor = NSColor(white: 0.5, alpha: 0.5).cgColor
    }

    private func setupViews() {
        guard let contentView = window?.contentView else { return }

        contentView.addSubview(visualEffectView)
        contentView.addSubview(searchField)
        contentView.addSubview(dividerView)
        contentView.addSubview(scrollView)

        scrollView.documentView = tableView
    }

    private func setupConstraints() {
        guard let contentView = window?.contentView else { return }

        NSLayoutConstraint.activate([
            // Visual effect fills the entire window
            visualEffectView.topAnchor.constraint(equalTo: contentView.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Search field at top
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            // Divider below search field
            dividerView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            dividerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dividerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dividerView.heightAnchor.constraint(equalToConstant: 1),

            // Scroll view fills remaining space
            scrollView.topAnchor.constraint(equalTo: dividerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        tableView.target = self
    }

    private func setupSearchField() {
        searchField.delegate = self
    }

    // MARK: - Public Methods

    @objc func presentWindow() {
        model.rebuildItems()
        model.filter(query: "")

        searchField.stringValue = ""
        tableView.reloadData()

        positionWindow()

        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(searchField)

        if !model.items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    // MARK: - Private Methods

    private func positionWindow() {
        guard let window = self.window,
              let screen = NSScreen.main ?? NSApp.keyWindow?.screen else { return }

        updateWindowHeight()

        var frame = window.frame
        frame.origin.x = screen.frame.midX - frame.width / 2
        frame.origin.y = screen.frame.maxY - topMargin - frame.height

        window.setFrame(frame, display: true)
    }

    private func updateWindowHeight() {
        guard let window = self.window else { return }

        let rowCount = model.items.count
        let tableHeight = CGFloat(rowCount) * (tableView.rowHeight + tableView.intercellSpacing.height)
        let contentHeight = searchFieldHeight + min(tableHeight, maxWindowHeight - searchFieldHeight)

        var frame = window.frame
        let heightDelta = contentHeight - frame.height
        frame.size.height = contentHeight
        frame.origin.y -= heightDelta

        window.setFrame(frame, display: true, animate: window.isVisible)
    }

    private func executeSelectedItem() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < model.items.count else { return }

        let item = model.items[selectedRow]
        window?.close()

        // Execute after window closes to avoid issues with menu items
        DispatchQueue.main.async {
            item.execute()
        }
    }

    @objc private func tableViewDoubleClicked(_ sender: Any) {
        executeSelectedItem()
    }

    private func moveSelection(by delta: Int) {
        let newRow = tableView.selectedRow + delta
        guard newRow >= 0 && newRow < model.items.count else { return }

        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)
    }
}

// MARK: - NSWindowDelegate

extension CommandPaletteWindowController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        window?.close()
    }
}

// MARK: - NSSearchFieldDelegate

extension CommandPaletteWindowController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        model.filter(query: searchField.stringValue)
        tableView.reloadData()
        updateWindowHeight()

        if !model.items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
            return true
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            executeSelectedItem()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            window?.close()
            return true
        default:
            return false
        }
    }
}

// MARK: - NSTableViewDataSource

extension CommandPaletteWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return model.items.count
    }
}

// MARK: - NSTableViewDelegate

extension CommandPaletteWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellId = NSUserInterfaceItemIdentifier("CommandPaletteCell")
        let cell = tableView.makeView(withIdentifier: cellId, owner: nil) as? CommandPaletteCellView
            ?? CommandPaletteCellView(identifier: cellId)

        let item = model.items[row]
        cell.configure(with: item)

        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return CommandPaletteRowView()
    }
}

// MARK: - CommandPaletteWindow

private class CommandPaletteWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            close()
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - CommandPaletteRowView

private class CommandPaletteRowView: NSTableRowView {
    private let backgroundLayer: CALayer = {
        let layer = CALayer()
        layer.cornerRadius = 6
        return layer
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(backgroundLayer)
    }

    required init?(coder: NSCoder) {
        it_fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds.insetBy(dx: 8, dy: 1)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        CALayer.performWithoutAnimation {
            if isSelected {
                if effectiveAppearance.it_isDark {
                    backgroundLayer.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
                } else {
                    backgroundLayer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
                }
            } else {
                backgroundLayer.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
}

// MARK: - CommandPaletteCellView

private class CommandPaletteCellView: NSTableCellView {
    private let iconView: NSImageView = {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let categoryLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let shortcutLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .tertiaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setupViews()
    }

    required init?(coder: NSCoder) {
        it_fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(categoryLabel)
        addSubview(shortcutLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: shortcutLabel.leadingAnchor, constant: -8),

            categoryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            categoryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
            categoryLabel.trailingAnchor.constraint(lessThanOrEqualTo: shortcutLabel.leadingAnchor, constant: -8),

            shortcutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            shortcutLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            shortcutLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 100),
        ])
    }

    func configure(with item: CommandPaletteItem) {
        iconView.image = item.icon

        if let attributedTitle = item.attributedTitle {
            titleLabel.attributedStringValue = attributedTitle
        } else {
            titleLabel.stringValue = item.title
        }

        if let attributedCategory = item.attributedCategory {
            categoryLabel.attributedStringValue = attributedCategory
        } else {
            categoryLabel.stringValue = item.category
        }

        shortcutLabel.stringValue = item.keyEquivalent ?? ""

        // Dim disabled items
        let alpha: CGFloat = item.isEnabled ? 1.0 : 0.5
        titleLabel.alphaValue = alpha
        categoryLabel.alphaValue = alpha
        iconView.alphaValue = alpha
    }
}
