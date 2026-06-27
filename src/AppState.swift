import SwiftUI
import AppKit
import IOKit
import Carbon

@_silgen_name("create_virtual_display")
func create_virtual_display() -> UInt32

@_silgen_name("destroy_virtual_display")
func destroy_virtual_display()

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var fireReachable: String = "unknown"
    @Published var adbAuthorized: String = "unknown"
    @Published var moonlightPresent: String = "unknown"
    @Published var sunshineRunning: String = "unknown"
    @Published var streamActive: String = "idle"
    @Published var androidUSB: String = "missing"
    @Published var profileName: String = "default"
    @Published var fireIP: String = ""
    @Published var androidIP: String = ""
    @Published var displayMode: String = ""
    
    @Published var dexterState: String = "setup" // "idle", "setup", "connecting", "success", "failed"
    @Published var isChecking = false
    
    private var savedBrightness: Float? = nil
    private let actionPath = "/Users/andrew/DexCast/bin/dexcast-action.zsh"
    
    init() {
        refresh()
        // Poll status every 4 seconds in the background
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            self.refresh()
        }
    }
    
    private func getBrightness() -> Float? {
        var brightness: Float = 1.0
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(0, IOServiceMatching("IODisplayConnect"), &iterator)
        if result == 0 { // KERN_SUCCESS
            var service = IOIteratorNext(iterator)
            while service != 0 {
                var val: Float = 0.0
                if IODisplayGetFloatParameter(service, 0, "brightness" as CFString, &val) == 0 {
                    brightness = val
                    IOObjectRelease(service)
                    break
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
        }
        return brightness
    }

    private func setBrightness(level: Float) {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(0, IOServiceMatching("IODisplayConnect"), &iterator)
        if result == 0 { // KERN_SUCCESS
            var service = IOIteratorNext(iterator)
            while service != 0 {
                IODisplaySetFloatParameter(service, 0, "brightness" as CFString, level)
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
        }
    }
    
    func refresh() {
        guard !isChecking else { return }
        isChecking = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [self.actionPath, "check-status"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.parseStatus(output)
                        self.updateDexterState()
                        self.isChecking = false
                    }
                } else {
                    DispatchQueue.main.async { self.isChecking = false }
                }
            } catch {
                DispatchQueue.main.async { self.isChecking = false }
            }
        }
    }
    
    private func parseStatus(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let val = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
            
            switch key {
            case "FIRE_REACHABLE": self.fireReachable = val
            case "ADB_AUTHORIZED": self.adbAuthorized = val
            case "MOONLIGHT_PRESENT": self.moonlightPresent = val
            case "SUNSHINE_RUNNING": self.sunshineRunning = val
            case "STREAM_ACTIVE": self.streamActive = val
            case "ANDROID_USB": self.androidUSB = val
            case "PROFILE_NAME": self.profileName = val
            case "FIRE_IP": self.fireIP = val
            case "ANDROID_IP": self.androidIP = val
            case "DISPLAY_MODE": self.displayMode = val
            default: break
            }
        }
    }
    
    func updateDexterState() {
        if fireIP.isEmpty || fireIP == "Not set" {
            dexterState = "setup"
            return
        }
        if fireReachable == "fail" || adbAuthorized == "unauthorized" || sunshineRunning == "missing" {
            dexterState = "failed"
            return
        }
        if streamActive == "ok" {
            dexterState = "success"
            return
        }
        if fireReachable == "ok" && adbAuthorized == "ok" && moonlightPresent == "ok" && sunshineRunning == "ok" {
            dexterState = "idle"
        } else {
            dexterState = "setup"
        }
    }
    
    func runAction(_ arg: String, wait: Bool = false) {
        let parts = arg.components(separatedBy: " ")
        runActionWithArgs(parts, wait: wait)
    }
    
    func runActionWithArgs(_ args: [String], wait: Bool = false) {
        let action = args.first ?? ""
        if action == "mac-fire" || action == "android-usb-fire" || action == "android-wifi-fire" {
            self.dexterState = "connecting"
            // Dim built-in display dynamically
            self.savedBrightness = getBrightness()
            setBrightness(level: 0.0)
        }
        
        if action == "stop-sunshine" || action == "stop-mirrors" {
            if self.virtualDisplayActive {
                destroy_virtual_display()
                self.virtualDisplayActive = false
            }
            if let oldVal = self.savedBrightness {
                setBrightness(level: oldVal)
                self.savedBrightness = nil
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [self.actionPath] + args
            do {
                try process.run()
                if wait { process.waitUntilExit() }
                
                if action == "mac-fire" || action == "android-usb-fire" || action == "android-wifi-fire" {
                    Thread.sleep(forTimeInterval: 6.0)
                }
                
                DispatchQueue.main.async {
                    self.refresh()
                    if action == "mac-fire" || action == "android-usb-fire" || action == "android-wifi-fire" {
                        if self.fireReachable == "ok" && self.adbAuthorized == "ok" && self.sunshineRunning == "ok" {
                            self.dexterState = "success"
                        } else {
                            self.dexterState = "failed"
                        }
                    }
                }
            } catch {}
        }
    }
    
    @Published var virtualDisplayActive: Bool = false
    
    func changeDisplayMode(_ newMode: String) {
        if newMode == "Virtual TV Screen" {
            let displayID = create_virtual_display()
            if displayID != 0 {
                self.virtualDisplayActive = true
                self.displayMode = newMode
                runActionWithArgs(["change-display", "\(displayID)"])
            }
        } else {
            if self.virtualDisplayActive {
                destroy_virtual_display()
                self.virtualDisplayActive = false
            }
            self.displayMode = newMode
            runActionWithArgs(["change-display", newMode])
        }
    }
}
