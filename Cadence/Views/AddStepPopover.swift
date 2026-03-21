import SwiftUI

struct AddStepPopover: View {
    let onAdd: (SequenceStep) -> Void

    private let stepOptions: [(name: String, description: String, step: SequenceStep)] = [
        ("Capture", "Fire the shutter on the selected camera", .capture(postCaptureDelay: 3)),
        ("Switch Camera", "Select a different connected camera", .switchCamera(mode: .specific(cameraName: nil))),
        ("Set ISO", "Change the ISO setting", .setISO(mode: .absolute(value: "400"))),
        ("Set Aperture", "Change the aperture setting", .setAperture(mode: .absolute(value: "f/5.6"))),
        ("Set Shutter Speed", "Change the shutter speed", .setShutterSpeed(mode: .absolute(value: "1/125"))),
        ("Autofocus", "Trigger autofocus on the selected camera", .autofocus),
        ("Move Focus", "Adjust focus position nearer or further", .moveFocus(direction: .nearer, amount: .medium)),
        ("Wait", "Pause for a number of seconds", .wait(seconds: 5)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(stepOptions, id: \.name) { option in
                Button(action: { onAdd(option.step) }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.name)
                            .font(.headline)
                        Text(option.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                if option.name != stepOptions.last?.name {
                    Divider()
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 280)
    }
}
