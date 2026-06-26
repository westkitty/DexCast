import SwiftUI
import AppKit

class AppState: ObservableObject {
    @Published var fireReachable: String = "unknown"
    @Published var adbAuthorized: String = "unknown"
    @Published var moonlightPresent: String = "unknown"
    @Published var sunshineRunning: String = "unknown"
    @Published var profileName: String = "default"
    @Published var fireIP: String = ""
    @Published var androidIP: String = ""
    @Published var displayMode: String = ""
    
    @Published var dexterState: String = "setup" // "idle", "setup", "connecting", "success", "failed"
    @Published var isChecking = false
    
    private let actionPath = "/Users/andrew/DexCast/bin/dexcast-action.zsh"
    
    init() {
        refresh()
        // Poll status every 4 seconds in the background
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            self.refresh()
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
        if fireReachable == "ok" && adbAuthorized == "ok" && moonlightPresent == "ok" && sunshineRunning == "ok" {
            dexterState = "idle"
        } else {
            dexterState = "setup"
        }
    }
    
    func runAction(_ arg: String, wait: Bool = false) {
        if arg == "mac-fire" || arg == "android-usb-fire" || arg == "android-wifi-fire" {
            self.dexterState = "connecting"
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [self.actionPath, arg]
            do {
                try process.run()
                if wait { process.waitUntilExit() }
                
                if arg == "mac-fire" || arg == "android-usb-fire" || arg == "android-wifi-fire" {
                    Thread.sleep(forTimeInterval: 6.0)
                }
                
                DispatchQueue.main.async {
                    self.refresh()
                    if arg == "mac-fire" || arg == "android-usb-fire" || arg == "android-wifi-fire" {
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
}

struct DexterAvatarView: View {
    let state: String
    
    var fallbackIcon: String {
        switch state {
        case "idle": return "pawprint.fill"
        case "setup": return "gearshape.2.fill"
        case "connecting": return "arrow.clockwise.icloud.fill"
        case "success": return "checkmark.seal.fill"
        case "failed": return "exclamationmark.triangle.fill"
        default: return "pawprint"
        }
    }
    
    var fallbackColor: Color {
        switch state {
        case "idle": return .blue
        case "setup": return .orange
        case "connecting": return .cyan
        case "success": return .green
        case "failed": return .red
        default: return .secondary
        }
    }
    
    var label: String {
        switch state {
        case "idle": return "Ready to sit"
        case "setup": return "Setup needed"
        case "connecting": return "Connecting..."
        case "success": return "Enjoying Dexter!"
        case "failed": return "Connection failed"
        default: return "DexCast"
        }
    }
    
    var assetName: String {
        switch state {
        case "idle": return "dexter_idle"
        case "setup": return "dexter_setup"
        case "connecting": return "dexter_connecting"
        case "success": return "dexter_success"
        case "failed": return "dexter_failed"
        default: return ""
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if !assetName.isEmpty,
               let path = Bundle.main.path(forResource: assetName, ofType: "png"),
               let nsImg = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(fallbackColor.opacity(0.8), lineWidth: 3))
                    .shadow(color: fallbackColor.opacity(0.35), radius: 10, x: 0, y: 4)
            } else {
                ZStack {
                    Circle()
                        .fill(fallbackColor.opacity(0.12))
                        .frame(width: 130, height: 130)
                        .overlay(Circle().stroke(fallbackColor.opacity(0.8), lineWidth: 3))
                        .shadow(color: fallbackColor.opacity(0.2), radius: 10, x: 0, y: 4)
                    
                    Image(systemName: fallbackIcon)
                        .font(.system(size: 56))
                        .foregroundColor(fallbackColor)
                }
            }
            
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(fallbackColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(fallbackColor.opacity(0.12)))
        }
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let status: String
    
    var statusColor: Color {
        switch status {
        case "ok": return .green
        case "fail": return .red
        case "warn": return .orange
        default: return .secondary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(statusColor)
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(minWidth: 130)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct MiniActionButton: View {
    let title: String
    let icon: String
    var color: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }
}

struct SetupStep: Identifiable {
    let id: Int
    let title: String
    let desc: String
    let detail: String
    let btnText: String
    let actionArg: String
    let icon: String
}

struct SidebarView: View {
    @ObservedObject var state: AppState
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 0) {
                    Text("DexCast")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Sit With Dexter")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 8)
            
            Button(action: { selectedTab = 1 }) {
                HStack {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Dashboard")
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(selectedTab == 1 ? Color.white.opacity(0.08) : Color.clear))
                .foregroundColor(selectedTab == 1 ? .white : .secondary)
            }
            .buttonStyle(.plain)
            
            Button(action: { selectedTab = 0 }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Setup Wizard")
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(selectedTab == 0 ? Color.white.opacity(0.08) : Color.clear))
                .foregroundColor(selectedTab == 0 ? .white : .secondary)
            }
            .buttonStyle(.plain)
            
            Divider()
                .opacity(0.3)
                .padding(.vertical, 4)
            
            Text("QUICK CAST")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            MiniActionButton(title: "🐾 Sit With Dexter", icon: "play.display.fill", color: .orange) {
                state.runAction("mac-fire")
            }
            
            MiniActionButton(title: "Android USB Mirror", icon: "iphone", color: .cyan) {
                state.runAction("android-usb-fire")
            }
            
            MiniActionButton(title: "Android Wi-Fi Mirror", icon: "wifi", color: .cyan) {
                state.runAction("android-wifi-fire")
            }
            
            MiniActionButton(title: "Stop Mirrors", icon: "stop.fill", color: .red) {
                state.runAction("stop-mirrors")
            }
            
            Spacer()
            
            Group {
                Text("SYSTEM TOOLS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                MiniActionButton(title: "Sunshine Web UI", icon: "globe") {
                    state.runAction("webui")
                }
                MiniActionButton(title: "macOS Displays", icon: "display.2") {
                    state.runAction("displays")
                }
                MiniActionButton(title: "Open Log", icon: "doc.text") {
                    state.runAction("log")
                }
                MiniActionButton(title: "Reset ADB", icon: "arrow.clockwise") {
                    state.runAction("reset-adb")
                }
            }
            
            Divider()
                .opacity(0.3)
                .padding(.vertical, 4)
            
            Button(action: {
                let alert = NSAlert()
                alert.messageText = "Uninstall DexCast?"
                alert.informativeText = "Are you sure you want to remove all configuration profiles and settings files? The app binary folders will be deleted."
                alert.addButton(withTitle: "Uninstall")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .critical
                if alert.runModal() == .alertFirstButtonReturn {
                    state.runAction("uninstall")
                }
            }) {
                Label("Uninstall App", systemImage: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 200)
        .background(Color.black.opacity(0.3))
    }
}

struct HeaderView: View {
    let selectedTab: Int
    let profileName: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTab == 1 ? "Daily Workspace Casting" : "First-Time Config Wizard")
                    .font(.system(size: 20, weight: .bold))
                Text(selectedTab == 1 ? "Stream your laptop display directly to the Fire Stick." : "Follow these click-through steps to register and authorize your devices.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Active Profile")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Text(profileName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.045)))
        }
        .padding(16)
        .background(Color.white.opacity(0.015))
    }
}

struct DashboardView: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 24) {
                DexterAvatarView(state: state.dexterState)
                    .frame(width: 150)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("“Sit With Dexter”")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                    
                    Text("One click links your screen and lets you get back to what matters most.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Button(action: {
                        state.runAction("mac-fire")
                    }) {
                        HStack {
                            Image(systemName: "pawprint.fill")
                            Text("Sit With Dexter")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(RoundedRectangle(cornerRadius: 14).fill(state.dexterState == "failed" ? Color.red.opacity(0.8) : Color.orange))
                        .shadow(color: (state.dexterState == "failed" ? Color.red : Color.orange).opacity(0.3), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 10) {
                Text("SYSTEM CONNECTION GATES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    StatusCard(title: "Fire Stick IP",
                               value: state.fireIP.isEmpty || state.fireIP == "Not set" ? "Missing" : state.fireIP,
                               icon: "network",
                               status: (state.fireIP.isEmpty || state.fireIP == "Not set") ? "fail" : "ok")
                    
                    StatusCard(title: "Stick Reachability",
                               value: state.fireReachable == "ok" ? "Reachable" : (state.fireReachable == "fail" ? "Unreachable" : "Waiting"),
                               icon: "wifi",
                               status: state.fireReachable == "ok" ? "ok" : (state.fireReachable == "fail" ? "fail" : "unknown"))
                    
                    StatusCard(title: "ADB Authorized",
                               value: state.adbAuthorized == "ok" ? "Authorized" : (state.adbAuthorized == "unauthorized" ? "Unauthorized" : "Offline"),
                               icon: "key.fill",
                               status: state.adbAuthorized == "ok" ? "ok" : (state.adbAuthorized == "unauthorized" ? "fail" : "unknown"))
                    
                    StatusCard(title: "Moonlight Client",
                               value: state.moonlightPresent == "ok" ? "Installed" : (state.moonlightPresent == "missing" ? "Missing" : "Unknown"),
                               icon: "tv.fill",
                               status: state.moonlightPresent == "ok" ? "ok" : (state.moonlightPresent == "missing" ? "fail" : "unknown"))
                    
                    StatusCard(title: "Sunshine Server",
                               value: state.sunshineRunning == "ok" ? "Running" : (state.sunshineRunning == "installed_stopped" ? "Stopped" : "Missing"),
                               icon: "play.display.fill",
                               status: state.sunshineRunning == "ok" ? "ok" : (state.sunshineRunning == "installed_stopped" ? "warn" : "fail"))
                    
                    StatusCard(title: "Screen Mode",
                               value: state.displayMode.isEmpty ? "Sunshine" : state.displayMode,
                               icon: "display",
                               status: "ok")
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("TROUBLESHOOTING TIP")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                
                if state.adbAuthorized == "unauthorized" {
                    Text("⚠️ ADB Unauthorized: Look at the TV screen! Select \"Always allow from this computer\" and then click Allow. Then click \"Reset ADB\" in the sidebar.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                } else if state.fireReachable == "fail" {
                    Text("⚠️ Fire Stick Unreachable: Make sure the TV is on and connected to the Wi-Fi. The Fire Stick IP may have changed. Verify settings on the TV: Network -> IP.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                } else if state.sunshineRunning == "installed_stopped" {
                    Text("⚠️ Sunshine Stopped: Sunshine is installed but not running. Click \"Start Sunshine\" in the setup guide or sidebar to launch.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                } else {
                    Text("Everything looks healthy. If the stream doesn't launch automatically, make sure you've completed the Sunshine setup (open http://localhost:47990 to pair devices).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
        .padding(16)
    }
}

struct SetupWizardView: View {
    @ObservedObject var state: AppState
    @Binding var wizardStep: Int
    let wizardSteps: [SetupStep]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Step \(wizardStep + 1) of 10")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
                Spacer()
                Text(wizardSteps[wizardStep].desc)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.15))
                        Image(systemName: wizardSteps[wizardStep].icon)
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    }
                    .frame(width: 44, height: 44)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("STEP \(wizardSteps[wizardStep].id)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(wizardSteps[wizardStep].title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                
                Text(wizardSteps[wizardStep].detail)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .foregroundColor(.secondary)
                
                Divider().opacity(0.3)
                
                HStack {
                    if wizardSteps[wizardStep].actionArg != "none" {
                        Button(action: {
                            state.runAction(wizardSteps[wizardStep].actionArg, wait: wizardSteps[wizardStep].actionArg == "setup")
                        }) {
                            Text(wizardSteps[wizardStep].btnText)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if wizardStep > 0 { wizardStep -= 1 }
                    }) {
                        Text("Back")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .disabled(wizardStep == 0)
                    .opacity(wizardStep == 0 ? 0.3 : 1.0)
                    
                    Button(action: {
                        if wizardStep < 9 { wizardStep += 1 }
                    }) {
                        Text("Next Step")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .disabled(wizardStep == 9)
                    .opacity(wizardStep == 9 ? 0.3 : 1.0)
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(0..<10) { idx in
                    Button(action: { wizardStep = idx }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(idx + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(wizardStep == idx ? .orange : .secondary)
                            Text(wizardSteps[idx].desc)
                                .font(.system(size: 10))
                                .foregroundColor(wizardStep == idx ? .white : .secondary)
                                .lineLimit(1)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(wizardStep == idx ? Color.white.opacity(0.08) : Color.white.opacity(0.02)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(wizardStep == idx ? Color.orange.opacity(0.7) : Color.white.opacity(0.04), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10)
        }
        .padding(16)
    }
}

struct ContentView: View {
    @StateObject private var state = AppState()
    @State private var selectedTab = 1 // default to Dashboard
    @State private var wizardStep = 0
    
    let wizardSteps = [
        SetupStep(id: 1, title: "Welcome to DexCast",
                  desc: "Purpose & Story",
                  detail: "DexCast connects your MacBook to the TV so you can cast screens instantly and spend more time sitting with Dexter, your aging Phalène dog.\n\nPrimary Command: “Sit With Dexter”",
                  btnText: "Get Started", actionArg: "none", icon: "hand.wave.fill"),
        SetupStep(id: 2, title: "Install required tools",
                  desc: "Homebrew Dependencies",
                  detail: "Installs adb, scrcpy, localsend, and Sunshine. This will open a visible Terminal window so you can track the installation process directly.",
                  btnText: "Run Installer", actionArg: "install", icon: "terminal.fill"),
        SetupStep(id: 3, title: "Configure Fire Stick IP",
                  desc: "Network Matching",
                  detail: "Saves your Fire Stick IP configuration. Find it on the TV in Settings → My Fire TV → About → Network.",
                  btnText: "Configure Profile", actionArg: "setup", icon: "person.crop.circle.fill"),
        SetupStep(id: 4, title: "Enable Developer Mode",
                  desc: "Allow Debugging",
                  detail: "On the Fire Stick: Go to Settings → My Fire TV → About. Click the Device Name 7 times to unlock Developer Options. Then, go back to Developer Options and turn ADB Debugging ON.",
                  btnText: "I Completed This", actionArg: "none", icon: "tv.fill"),
        SetupStep(id: 5, title: "Install Moonlight on TV",
                  desc: "Game Stream Client",
                  detail: "On the Fire Stick, go to the App Store, search for \"Moonlight Game Streaming\", and install it.",
                  btnText: "I Installed It", actionArg: "none", icon: "arrow.down.to.line.circle.fill"),
        SetupStep(id: 6, title: "Authorize ADB",
                  desc: "Trust computer",
                  detail: "Starts ADB and opens a prompt on your TV. Watch the TV and choose \"Always allow from this computer\" and then click Allow. If it says unauthorized, rerun this step.",
                  btnText: "Authorize Fire Stick", actionArg: "authorize-fire", icon: "key.fill"),
        SetupStep(id: 7, title: "Start Sunshine Streamer",
                  desc: "Stream Host",
                  detail: "Starts the Sunshine streamer daemon in the background on your MacBook, which captures the display to cast it.",
                  btnText: "Start Sunshine", actionArg: "sunshine", icon: "play.fill"),
        SetupStep(id: 8, title: "Select Display Preference",
                  desc: "Screen Routing",
                  detail: "Select whether you want to mirror the MacBook display, cast the external display, or mirrored. We will open macOS Displays preferences to help.",
                  btnText: "Open Displays Preferences", actionArg: "displays", icon: "display.2"),
        SetupStep(id: 9, title: "Run Diagnostics (Doctor)",
                  desc: "Final Verification Check",
                  detail: "Verify all software paths, network connections, and ADB authorization states. This compiles a diagnostic report and opens the log.",
                  btnText: "Run Doctor Check", actionArg: "doctor", icon: "stethoscope"),
        SetupStep(id: 10, title: "First Sit With Dexter!",
                  desc: "One-Click Cast launch",
                  detail: "All gates have been successfully checked. Let's initiate the link and go sit with Dexter!",
                  btnText: "🐾 Sit With Dexter", actionArg: "mac-fire", icon: "pawprint.fill")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            SidebarView(state: state, selectedTab: $selectedTab)
            
            VStack(alignment: .leading, spacing: 0) {
                HeaderView(selectedTab: selectedTab, profileName: state.profileName)
                
                ScrollView {
                    if selectedTab == 1 {
                        DashboardView(state: state)
                    } else {
                        SetupWizardView(state: state, wizardStep: $wizardStep, wizardSteps: wizardSteps)
                    }
                }
            }
        }
        .frame(minWidth: 780, minHeight: 580)
    }
}

@main
struct DexCastApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
