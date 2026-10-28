import SwiftUI

/// The list of saved heights, with inline editing and drag to reorder.
struct PresetSection: View {
    @Environment(DeskController.self) private var desk
    @Environment(PresetStore.self) private var store
    @State private var editing: Preset?

    private static let rowHeight = 30.0
    private static let rowSpacing = 2.0
    private static let visibleRows = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Presets")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    editing = Preset(name: "", height: ((desk.height ?? 75) * 10).rounded() / 10)
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.medium))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Add Preset")
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            if store.presets.isEmpty, editing == nil {
                Text("Save heights you use often. Click + to add the current height.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            } else {
                ScrollView {
                    VStack(spacing: Self.rowSpacing) {
                        ForEach(store.presets) { preset in
                            PresetRow(preset: preset, isEditing: editing?.id == preset.id) {
                                editing = preset
                            }
                        }
                    }
                }
                .frame(height: listHeight)
                .scrollBounceBehavior(.basedOnSize)
            }

            if let preset = editing {
                PresetEditor(draft: preset) { editing = nil }
                    .id(preset.id)
                    .padding(.top, 4)
            }
        }
        .animation(.easeOut(duration: 0.15), value: editing)
    }

    private var listHeight: Double {
        let rows = Double(min(store.presets.count, Self.visibleRows))
        return rows * Self.rowHeight + max(0, rows - 1) * Self.rowSpacing
    }
}

private struct PresetRow: View {
    let preset: Preset
    let isEditing: Bool
    let onEdit: () -> Void
    @Environment(DeskController.self) private var desk
    @Environment(PresetStore.self) private var store
    @State private var hovering = false
    @State private var dropTargeted = false

    private var isTarget: Bool {
        desk.target.map { abs($0 - preset.height) < 0.05 } ?? false
    }

    private var isCurrent: Bool {
        !desk.isMoving && (desk.height.map { abs($0 - preset.height) < 0.5 } ?? false)
    }

    var body: some View {
        HStack(spacing: 6) {
            indicator
                .font(.caption.weight(.bold))
                .foregroundStyle(.tint)
                .frame(width: 12)
            Text(preset.name)
                .lineLimit(1)
            Spacer(minLength: 4)
            if hovering {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .help("Edit")
                Button {
                    store.delete(preset)
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete")
            }
            Text(verbatim: "\(preset.height.heightText) cm")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(background, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            if isTarget { desk.stop() } else { desk.move(to: preset.height) }
        }
        .contextMenu {
            Button("Edit…", action: onEdit)
            Button("Delete", role: .destructive) { store.delete(preset) }
        }
        .draggable(preset.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
            store.move(id, to: preset.id)
            return true
        } isTargeted: {
            dropTargeted = $0
        }
    }

    @ViewBuilder private var indicator: some View {
        if isTarget {
            Image(systemName: (desk.height ?? 0) < preset.height ? "arrow.up" : "arrow.down")
                .symbolEffect(.pulse)
        } else if isCurrent {
            Image(systemName: "checkmark")
        }
    }

    private var background: Color {
        if isEditing || dropTargeted || isTarget { .accentColor.opacity(0.18) }
        else if hovering { .primary.opacity(0.07) }
        else { .clear }
    }
}

private struct PresetEditor: View {
    @State var draft: Preset
    let onDone: () -> Void
    @Environment(DeskController.self) private var desk
    @Environment(PresetStore.self) private var store
    @State private var heightText = ""
    @FocusState private var nameFocused: Bool

    private var name: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var height: Double? {
        Double(heightText.replacingOccurrences(of: ",", with: "."))
            .flatMap { DeskProtocol.range.contains($0) ? $0 : nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: $draft.name)
                .focused($nameFocused)
            HStack(spacing: 6) {
                TextField("Height", text: $heightText)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                Text(verbatim: "cm")
                    .foregroundStyle(.secondary)
                Stepper("Height", value: Binding {
                    height ?? draft.height
                } set: {
                    heightText = $0.heightText
                }, in: DeskProtocol.range, step: 0.5)
                .labelsHidden()
                Spacer()
                Button("Use Current") {
                    if let current = desk.height { heightText = current.heightText }
                }
                .disabled(desk.height == nil)
            }
            HStack {
                if height == nil {
                    Text(verbatim: "\(Int(DeskProtocol.range.lowerBound))–\(Int(DeskProtocol.range.upperBound)) cm")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel", action: onDone)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || height == nil)
            }
        }
        .textFieldStyle(.roundedBorder)
        .controlSize(.small)
        .padding(10)
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            heightText = draft.height.heightText
            nameFocused = true
        }
    }

    private func save() {
        guard let height, !name.isEmpty else { return }
        draft.name = name
        draft.height = height
        store.save(draft)
        onDone()
    }
}
