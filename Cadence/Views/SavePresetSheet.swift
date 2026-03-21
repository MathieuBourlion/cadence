import SwiftUI

struct SavePresetSheet: View {
    let presetManager: PresetManager
    let onSave: (String) -> Void

    @State private var presetName = ""
    @State private var showOverwriteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Save Preset")
                .font(.headline)

            TextField("Preset name", text: $presetName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { attemptSave() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .alert("Overwrite Preset", isPresented: $showOverwriteConfirmation) {
            Button("Overwrite", role: .destructive) { save() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A preset named \"\(presetName)\" already exists. Overwrite it?")
        }
    }

    private func attemptSave() {
        let name = presetName.trimmingCharacters(in: .whitespaces)
        if presetManager.presetExists(name: name) {
            showOverwriteConfirmation = true
        } else {
            save()
        }
    }

    private func save() {
        let name = presetName.trimmingCharacters(in: .whitespaces)
        onSave(name)
        dismiss()
    }
}
