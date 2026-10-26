import AppKit

/// Application entry point.
/// We use the traditional AppDelegate approach instead of @main App
/// because we need fine-grained control over NSStatusItem lifecycle.

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
