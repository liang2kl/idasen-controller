import ServiceManagement
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            StatusBar()
                .padding([.horizontal, .top], 14)
            HeightPanel()
                .padding(14)
            Divider()
                .padding(.horizontal, 14)
            PresetSection()
                .padding(8)
        }
        .frame(width: 290)
    }
}

private struct StatusBar: View {
    @Environment(DeskController.self) private var desk
    @AppStorage("showHeightInMenuBar") private var showHeightInMenuBar = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                menu
            }
            hint
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var menu: some View {
        Menu {
            Toggle("Show Height in Menu Bar", isOn: $showHeightInMenuBar)
            Toggle("Launch at Login", isOn: Binding {
                launchAtLogin
            } set: { enabled in
                try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                launchAtLogin = SMAppService.mainApp.status == .enabled
            })
            Divider()
            Button("Reconnect") { desk.reconnect() }
            Button("Forget This Desk") { desk.forgetDesk() }
                .disabled(desk.deskName == nil)
            Divider()
            Button("Quit Idasen") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var statusColor: Color {
        switch desk.state {
        case .connected: .green
        case .connecting, .scanning: .orange
        case .bluetoothOff, .unauthorized: .red
        }
    }

    private var statusText: String {
        switch desk.state {
        case .connected: desk.deskName ?? String(localized: "Desk")
        case .connecting: String(localized: "Connecting…")
        case .scanning: String(localized: "Searching for desk…")
        case .bluetoothOff: String(localized: "Bluetooth is off")
        case .unauthorized: String(localized: "Bluetooth access denied")
        }
    }

    @ViewBuilder private var hint: some View {
        switch desk.state {
        case .scanning:
            Text("Keep the desk nearby. To pair it for the first time, hold its Bluetooth button until the light blinks.")
        case .bluetoothOff:
            Text("Turn on Bluetooth to control your desk.")
        case .unauthorized:
            VStack(alignment: .leading, spacing: 6) {
                Text("Allow Idasen to use Bluetooth in System Settings.")
                Button("Open Privacy Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!)
                }
                .controlSize(.small)
            }
        case .connecting, .connected:
            EmptyView()
        }
    }
}
