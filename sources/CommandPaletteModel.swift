//
//  CommandPaletteModel.swift
//  iTerm2
//
//  Created for Command Palette feature
//

import AppKit

/// Model that collects and filters command palette items
@objc(iTermCommandPaletteModel)
class CommandPaletteModel: NSObject {
    private(set) var items: [CommandPaletteItem] = []
    private var allItems: [CommandPaletteItem] = []

    override init() {
        super.init()
        rebuildItems()
    }

    func rebuildItems() {
        allItems = collectAllMenuItems()
        items = allItems
    }

    func filter(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmedQuery.isEmpty {
            items = allItems
            return
        }

        // Split query into terms for multi-word matching
        let queryTerms = trimmedQuery.split(separator: " ").map { String($0) }

        items = allItems.filter { item in
            let searchText = "\(item.category) \(item.title)".lowercased()
            return queryTerms.allSatisfy { term in
                searchText.contains(term)
            }
        }.sorted { lhs, rhs in
            // Prefer exact title matches
            let lhsTitleMatch = lhs.title.lowercased().hasPrefix(trimmedQuery)
            let rhsTitleMatch = rhs.title.lowercased().hasPrefix(trimmedQuery)

            if lhsTitleMatch != rhsTitleMatch {
                return lhsTitleMatch
            }

            // Then sort alphabetically by category and title
            if lhs.category != rhs.category {
                return lhs.category < rhs.category
            }
            return lhs.title < rhs.title
        }

        // Apply highlighting to matching items
        for item in items {
            item.attributedTitle = highlightMatches(in: item.title, query: queryTerms)
            item.attributedCategory = highlightMatches(in: item.category, query: queryTerms)
        }
    }

    private func highlightMatches(in text: String, query: [String]) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.count)

        // Default style
        attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: fullRange)

        // Find and highlight matching ranges
        let lowercasedText = text.lowercased()
        for term in query {
            var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex
            while let range = lowercasedText.range(of: term, range: searchRange) {
                let nsRange = NSRange(range, in: text)
                attributedString.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 13), range: nsRange)
                searchRange = range.upperBound..<lowercasedText.endIndex
            }
        }

        return attributedString
    }

    private func collectAllMenuItems() -> [CommandPaletteItem] {
        guard let mainMenu = NSApp.mainMenu else {
            return []
        }

        var collectedItems: [CommandPaletteItem] = []

        for topLevelItem in mainMenu.items {
            guard let submenu = topLevelItem.submenu else { continue }
            let category = topLevelItem.title

            collectMenuItems(from: submenu, category: category, into: &collectedItems)
        }

        // Sort items alphabetically by category, then by title
        return collectedItems.sorted { lhs, rhs in
            if lhs.category != rhs.category {
                return lhs.category < rhs.category
            }
            return lhs.title < rhs.title
        }
    }

    private func collectMenuItems(from menu: NSMenu, category: String, into items: inout [CommandPaletteItem], prefix: String = "") {
        for menuItem in menu.items {
            // Skip separators and disabled items without actions
            guard !menuItem.isSeparatorItem else { continue }
            guard menuItem.isEnabled || menuItem.action != nil else { continue }

            // Trigger menu item validation to update dynamic titles
            // This ensures items like "Switch to Dark Mode" / "Switch to Light Mode" are current
            if menuItem.action != nil {
                let validateSelector = NSSelectorFromString("validateMenuItem:")
                if let target = menuItem.target {
                    if target.responds(to: validateSelector) {
                        _ = target.perform(validateSelector, with: menuItem)
                    }
                } else {
                    // Target is nil, so check the responder chain (app delegate)
                    if let appDelegate = NSApp.delegate, appDelegate.responds(to: validateSelector) {
                        _ = (appDelegate as AnyObject).perform(validateSelector, with: menuItem)
                    }
                }
            }

            // Skip items with empty titles
            let title = menuItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            // Build the full title with prefix for nested menus
            let fullTitle = prefix.isEmpty ? title : "\(prefix) → \(title)"

            if let submenu = menuItem.submenu {
                // Recursively collect items from submenus
                collectMenuItems(from: submenu, category: category, into: &items, prefix: fullTitle)
            } else if menuItem.action != nil {
                // This is an actionable menu item
                let item = CommandPaletteItem(menuItem: menuItem, category: category)
                // Override title with full path if nested
                if !prefix.isEmpty {
                    items.append(CommandPaletteItem(
                        title: fullTitle,
                        category: category,
                        keyEquivalent: item.keyEquivalent,
                        icon: item.icon,
                        kind: .menuItem(menuItem)
                    ))
                } else {
                    items.append(item)
                }
            }
        }
    }
}
