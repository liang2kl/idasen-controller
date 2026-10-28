import SwiftUI

/// The live height readout with hold-to-move arrows.
struct HeightPanel: View {
    @Environment(DeskController.self) private var desk
    @Environment(PresetStore.self) private var store

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ArrowButton(up: false)
                Spacer()
                readout
                Spacer()
                ArrowButton(up: true)
            }
            VStack(spacing: 4) {
                HeightBar(height: desk.height, marks: store.presets.map(\.height))
                scale
            }
        }
    }

    private var scale: some View {
        HStack {
            Text(verbatim: "\(Int(DeskProtocol.range.lowerBound)) cm")
            Spacer()
            if desk.isMoving {
                Button(action: desk.stop) {
                    Label("Stop", systemImage: "stop.fill")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.caption.weight(.semibold))
                .transition(.opacity)
            }
            Spacer()
            Text(verbatim: "\(Int(DeskProtocol.range.upperBound)) cm")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .frame(height: 18)
        .animation(.easeOut(duration: 0.15), value: desk.isMoving)
    }

    private var readout: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(desk.height?.heightText ?? "—")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: desk.height ?? 0))
                .animation(.snappy, value: desk.height)
            Text(verbatim: "cm")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(desk.isConnected ? .primary : .tertiary)
    }
}

/// Moves the desk while held; a quick click nudges it by one centimetre.
private struct ArrowButton: View {
    let up: Bool
    @Environment(DeskController.self) private var desk
    @State private var pressed = false

    var body: some View {
        Image(systemName: up ? "chevron.up" : "chevron.down")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(pressed ? Color.white : Color.primary)
            .frame(width: 38, height: 38)
            .background(Circle().fill(pressed ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary)))
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressed else { return }
                        pressed = true
                        desk.beginHold(up: up)
                    }
                    .onEnded { _ in
                        pressed = false
                        desk.endHold()
                    }
            )
            .opacity(desk.isConnected ? 1 : 0.4)
            .allowsHitTesting(desk.isConnected)
            .help(up ? "Raise – hold to keep moving" : "Lower – hold to keep moving")
            .accessibilityElement()
            .accessibilityLabel(up ? "Raise" : "Lower")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                desk.beginHold(up: up)
                desk.endHold()
            }
    }
}

/// A track showing where the desk sits in its range, with ticks at each preset.
private struct HeightBar: View {
    var height: Double?
    var marks: [Double]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 6)
                if let height {
                    Capsule()
                        .fill(.tint)
                        .frame(width: max(6, width * fraction(height)), height: 6)
                }
                ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                    Capsule()
                        .fill(.secondary)
                        .frame(width: 2, height: 12)
                        .offset(x: width * fraction(mark) - 1)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 12)
        .animation(.snappy, value: height)
    }

    private func fraction(_ value: Double) -> Double {
        let range = DeskProtocol.range
        return (value.clamped(to: range) - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}
