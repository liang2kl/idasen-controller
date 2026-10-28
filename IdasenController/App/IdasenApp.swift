import SwiftUI

@main
struct IdasenApp: App {
    @State private var desk = DeskController()
    @State private var presets = PresetStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environment(desk)
                .environment(presets)
        } label: {
            MenuBarLabel(desk: desk)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    let desk: DeskController
    @AppStorage("showHeightInMenuBar") private var showHeight = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "table.furniture")
            if showHeight, desk.isConnected, let height = desk.height {
                Text(height.heightText).monospacedDigit()
            }
        }
    }
}

extension Double {
    /// A height in centimetres with one decimal, e.g. "72.5".
    var heightText: String { formatted(.number.precision(.fractionLength(1))) }
}
