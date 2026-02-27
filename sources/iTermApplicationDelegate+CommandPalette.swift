//
//  iTermApplicationDelegate+CommandPalette.swift
//  iTerm2
//
//  Created for Command Palette feature
//

import AppKit

@objc
extension iTermApplicationDelegate {
    /// Opens the command palette window (⇧⌘P)
    @IBAction func openCommandPalette(_ sender: Any?) {
        CommandPaletteWindowController.shared.presentWindow()
    }
}
