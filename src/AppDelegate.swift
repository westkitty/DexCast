import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "DexCast")
        }
        setupMenu()
        setupGlobalHotkey()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "🐾 Sit With Dexter", action: #selector(sitWithDexter), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "🛑 Stop Sunshine", action: #selector(stopSunshine), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Stop Mirrors", action: #selector(stopMirrors), keyEquivalent: "m"))
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Open DexCast Dashboard", action: #selector(openDashboard), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func sitWithDexter() {
        AppState.shared.runAction("mac-fire")
    }
    
    @objc func stopSunshine() {
        AppState.shared.runAction("stop-sunshine")
    }
    
    @objc func stopMirrors() {
        AppState.shared.runAction("stop-mirrors")
    }
    
    @objc func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func setupGlobalHotkey() {
        var hotKeyRef: EventHotKeyRef?
        let gMyHotKeyID = EventHotKeyID(signature: 0x44584353, id: 1) // "DXCS" signature in hex
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)
        
        let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            DispatchQueue.main.async {
                AppState.shared.runAction("mac-fire")
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
        
        // cmdKey = 0x0100, optionKey = 0x0800
        let modifiers = 0x0100 | 0x0800
        RegisterEventHotKey(2, UInt32(modifiers), gMyHotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
