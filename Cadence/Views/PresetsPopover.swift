import SwiftUI

struct PresetsPopover: View {
    let presetManager: PresetManager
    let hasExistingSteps: Bool
    let onLoad: (CadenceSequence) -> Void

    @State private var presets: [String] = []
    @State private var showDeleteConfirmation: String?
    @State private var pendingLoadName: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if presets.isEmpty {
                Text("No saved presets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(presets, id: \.self) { name in
                    Button(action: { attemptLoad(name) }) {
                        Text(name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            showDeleteConfirmation = name
                        }
                    }
                    if name != presets.last {
                        Divider()
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 220)
        .onAppear { refreshPresets() }
        .alert("Delete Preset", isPresented: .init(
            get: { showDeleteConfirmation != nil },
            set: { if !$0 { showDeleteConfirmation = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let name = showDeleteConfirmation {
                    try? presetManager.delete(name: name)
                    refreshPresets()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete preset \"\(showDeleteConfirmation ?? "")\"?")
        }
        .alert("Replace Sequence", isPresented: .init(
            get: { pendingLoadName != nil },
            set: { if !$0 { pendingLoadName = nil } }
        )) {
            Button("Replace", role: .destructive) {
                if let name = pendingLoadName { loadPreset(name) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Loading a preset will replace your current sequence.")
        }
    }

    private func refreshPresets() {
        presets = (try? presetManager.listPresets()) ?? []
    }

    private func attemptLoad(_ name: String) {
        if hasExistingSteps {
            pendingLoadName = name
        } else {
            loadPreset(name)
        }
    }

    private func loadPreset(_ name: String) {
        guard let seq = try? presetManager.load(name: name) else { return }
        onLoad(seq)
        dismiss()
    }
}
