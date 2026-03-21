import SwiftUI

struct PresetsPopover: View {
    let presetManager: PresetManager
    let hasExistingSteps: Bool
    let onLoad: (CadenceSequence) -> Void

    @State private var presets: [String] = []
    @State private var deleteTargetName: String = ""
    @State private var showDeleteAlert = false
    @State private var loadTargetName: String = ""
    @State private var showLoadAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            presetList
        }
        .padding(.vertical, 8)
        .frame(width: 220)
        .onAppear { refreshPresets() }
        .alert("Delete Preset", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                try? presetManager.delete(name: deleteTargetName)
                refreshPresets()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete preset \"\(deleteTargetName)\"?")
        }
        .alert("Replace Sequence", isPresented: $showLoadAlert) {
            Button("Replace", role: .destructive) {
                commitLoad(loadTargetName)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Loading a preset will replace your current sequence.")
        }
    }

    @ViewBuilder
    private var presetList: some View {
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
                        deleteTargetName = name
                        showDeleteAlert = true
                    }
                }
                if name != presets.last {
                    Divider()
                }
            }
        }
    }

    private func refreshPresets() {
        presets = (try? presetManager.listPresets()) ?? []
    }

    private func attemptLoad(_ name: String) {
        if hasExistingSteps {
            loadTargetName = name
            showLoadAlert = true
        } else {
            commitLoad(name)
        }
    }

    private func commitLoad(_ name: String) {
        guard let seq = try? presetManager.load(name: name) else { return }
        onLoad(seq)
        // ContentView's loadPreset sets showPresetsPopover = false, closing this popover
    }
}
