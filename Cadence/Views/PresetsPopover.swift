import SwiftUI

struct PresetsPopover: View {
    let presetManager: PresetManager
    let hasExistingSteps: Bool
    let onLoad: (CadenceSequence) -> Void

    enum ActiveAlert: Identifiable {
        case confirmDelete(String)
        case confirmLoad(String)
        var id: String {
            switch self {
            case .confirmDelete(let name): return "delete-\(name)"
            case .confirmLoad(let name): return "load-\(name)"
            }
        }
    }

    @State private var presets: [String] = []
    @State private var activeAlert: ActiveAlert?
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
                            activeAlert = .confirmDelete(name)
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
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .confirmDelete(let name):
                return Alert(
                    title: Text("Delete Preset"),
                    message: Text("Delete preset \"\(name)\"?"),
                    primaryButton: .destructive(Text("Delete")) {
                        try? presetManager.delete(name: name)
                        refreshPresets()
                    },
                    secondaryButton: .cancel()
                )
            case .confirmLoad(let name):
                return Alert(
                    title: Text("Replace Sequence"),
                    message: Text("Loading a preset will replace your current sequence."),
                    primaryButton: .destructive(Text("Replace")) {
                        loadPreset(name)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private func refreshPresets() {
        presets = (try? presetManager.listPresets()) ?? []
    }

    private func attemptLoad(_ name: String) {
        if hasExistingSteps {
            activeAlert = .confirmLoad(name)
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
