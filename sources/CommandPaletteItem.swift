//
//  CommandPaletteItem.swift
//  iTerm2
//
//  Created for Command Palette feature
//

import AppKit

/// Represents a single item in the command palette
@objc(iTermCommandPaletteItem)
class CommandPaletteItem: NSObject {
    enum Kind {
        case menuItem(NSMenuItem)
        case action(() -> Void)
    }

    let title: String
    let category: String
    let keyEquivalent: String?
    let icon: NSImage?
    private let kind: Kind

    var attributedTitle: NSAttributedString?
    var attributedCategory: NSAttributedString?

    init(title: String, category: String, keyEquivalent: String? = nil, icon: NSImage? = nil, kind: Kind) {
        self.title = title
        self.category = category
        self.keyEquivalent = keyEquivalent
        self.icon = icon
        self.kind = kind
        super.init()
    }

    convenience init(menuItem: NSMenuItem, category: String) {
        let keyEquiv = Self.formatKeyEquivalent(menuItem)
        let icon = menuItem.image ?? Self.defaultIcon(for: category)
        self.init(
            title: menuItem.title,
            category: category,
            keyEquivalent: keyEquiv,
            icon: icon,
            kind: .menuItem(menuItem)
        )
    }

    func execute() {
        switch kind {
        case .menuItem(let menuItem):
            guard let action = menuItem.action else { return }
            if menuItem.isEnabled {
                NSApp.sendAction(action, to: menuItem.target, from: menuItem)
            }
        case .action(let action):
            action()
        }
    }

    var isEnabled: Bool {
        switch kind {
        case .menuItem(let menuItem):
            return menuItem.isEnabled
        case .action:
            return true
        }
    }

    private static func formatKeyEquivalent(_ menuItem: NSMenuItem) -> String? {
        guard !menuItem.keyEquivalent.isEmpty else { return nil }

        var parts: [String] = []
        let modifiers = menuItem.keyEquivalentModifierMask

        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        let key = menuItem.keyEquivalent.uppercased()
        parts.append(key)

        return parts.joined()
    }

    private static func defaultIcon(for category: String) -> NSImage? {
        let symbolName: String
        switch category {
        case "iTerm2":
            return NSImage(named: NSImage.applicationIconName)
        case "Shell":
            symbolName = SFSymbol.chevronLeftSlashChevronRight.rawValue
        case "Edit":
            symbolName = SFSymbol.pencil.rawValue
        case "View":
            symbolName = SFSymbol.eye.rawValue
        case "Session":
            symbolName = SFSymbol.rectangleStack.rawValue
        case "Scripts":
            symbolName = SFSymbol.doc.rawValue
        case "Profiles":
            symbolName = SFSymbol.person.rawValue
        case "Toolbelt":
            symbolName = SFSymbol.sidebarRight.rawValue
        case "Window":
            symbolName = SFSymbol.macwindow.rawValue
        case "Help":
            symbolName = SFSymbol.questionmarkCircle.rawValue
        default:
            symbolName = SFSymbol.command.rawValue
        }

        return NSImage.it_image(forSymbolName: symbolName,
                                accessibilityDescription: category,
                                fallbackImageName: "command",
                                for: CommandPaletteItem.self)
    }
}
