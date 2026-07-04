import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("globalHotkeyEnabled") private var hotkeyEnabled = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var needsAccessibility = false

    var body: some View {
        Form {
            Toggle("Summon MDness anywhere with fn + Space", isOn: $hotkeyEnabled)
                .onChange(of: hotkeyEnabled) { _, enabled in
                    if enabled {
                        let installed = HotkeyManager.shared.enable(promptIfNeeded: true)
                        needsAccessibility = !installed
                        if !installed {
                            hotkeyEnabled = false
                        }
                    } else {
                        HotkeyManager.shared.disable()
                    }
                }

            if needsAccessibility {
                Text("MDness needs Accessibility access to listen for fn + Space. Grant it in System Settings → Privacy & Security → Accessibility, then turn the toggle on again.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Toggle("Start MDness at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Text("Enable both so the shortcut works right after login.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420)
    }
}
