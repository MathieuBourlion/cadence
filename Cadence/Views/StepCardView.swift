import SwiftUI

struct StepCardView: View {
    @Binding var step: SequenceStep
    let isExpanded: Bool
    let executionState: StepExecutionState
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var pulseOpacity: Double = 1.0
    @State private var cameraList: [String] = []
    @State private var cameraListError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.typeName)
                        .font(.headline)
                    Text(step.configSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            // Expanded editing controls
            if isExpanded {
                Divider()
                stepEditor
            }
        }
        .padding(12)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: borderWidth)
                .opacity(executionState == .running ? pulseOpacity : 1.0)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            if executionState == .running {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.4
                }
            }
        }
        .onChange(of: executionState) { _, newValue in
            if newValue == .running {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.4
                }
            } else {
                withAnimation(.default) {
                    pulseOpacity = 1.0
                }
            }
        }
        .task(id: isExpanded) {
            if isExpanded, case .switchCamera = step {
                await fetchCameras()
            }
        }
    }

    private var borderColor: Color {
        switch executionState {
        case .idle:
            return step.isComplete ? .clear : .yellow
        case .running:
            return .green
        case .completed:
            return .green
        }
    }

    private var borderWidth: CGFloat {
        switch executionState {
        case .idle:
            return step.isComplete ? 0 : 1.5
        case .running:
            return 2
        case .completed:
            return 1.5
        }
    }

    @ViewBuilder
    private var stepEditor: some View {
        switch step {
        case .capture(let delay):
            Stepper("Post-capture delay: \(delay)s", value: Binding(
                get: { delay },
                set: { step = .capture(postCaptureDelay: max($0, 3)) }
            ), in: 3...30)

        case .switchCamera(let mode):
            switchCameraEditor(mode: mode)

        case .setISO(let mode):
            cameraValueEditor(
                label: "ISO",
                mode: mode,
                values: SequenceStep.isoValues,
                defaultValue: "400",
                makeStep: { .setISO(mode: $0) }
            )

        case .setAperture(let mode):
            cameraValueEditor(
                label: "Aperture",
                mode: mode,
                values: SequenceStep.apertureValues,
                defaultValue: "f/5.6",
                makeStep: { .setAperture(mode: $0) }
            )

        case .setShutterSpeed(let mode):
            cameraValueEditor(
                label: "Shutter Speed",
                mode: mode,
                values: SequenceStep.shutterSpeedValues,
                defaultValue: "1/125",
                makeStep: { .setShutterSpeed(mode: $0) }
            )

        case .autofocus:
            Text("Triggers autofocus then waits 1 second")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .moveFocus(let direction, let amount):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Picker("Direction", selection: Binding(
                        get: { direction },
                        set: { step = .moveFocus(direction: $0, amount: amount) }
                    )) {
                        ForEach(FocusDirection.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                    Picker("Amount", selection: Binding(
                        get: { amount },
                        set: { step = .moveFocus(direction: direction, amount: $0) }
                    )) {
                        ForEach(FocusAmount.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                }
                Text("Exact movement varies by camera and lens.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .wait(let seconds):
            Stepper("Wait: \(seconds)s", value: Binding(
                get: { seconds },
                set: { step = .wait(seconds: $0) }
            ), in: 1...60)
        }
    }

    @ViewBuilder
    private func switchCameraEditor(mode: SwitchCameraMode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mode picker: specific or next
            Picker("Mode", selection: Binding(
                get: {
                    if case .next = mode { return "next" }
                    return "specific"
                },
                set: { newMode in
                    if newMode == "next" {
                        step = .switchCamera(mode: .next)
                    } else {
                        step = .switchCamera(mode: .specific(cameraName: nil))
                    }
                }
            )) {
                Text("Specific camera").tag("specific")
                Text("Next camera (wraps)").tag("next")
            }
            .pickerStyle(.segmented)

            // If specific mode, show camera picker
            if case .specific(let currentName) = mode {
                if let error = cameraListError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if cameraList.isEmpty {
                    Text("Connect cameras in Capture One to select")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Camera", selection: Binding(
                        get: { currentName ?? "" },
                        set: { step = .switchCamera(mode: .specific(cameraName: $0.isEmpty ? nil : $0)) }
                    )) {
                        Text("Select camera...").tag("")
                        ForEach(cameraList, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cameraValueEditor(
        label: String,
        mode: CameraValueMode,
        values: [String],
        defaultValue: String,
        makeStep: @escaping (CameraValueMode) -> SequenceStep
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mode picker: absolute or relative
            Picker("Mode", selection: Binding(
                get: {
                    if case .relative = mode { return "relative" }
                    return "absolute"
                },
                set: { newMode in
                    if newMode == "relative" {
                        step = makeStep(.relative(direction: .up, steps: 1))
                    } else {
                        step = makeStep(.absolute(value: defaultValue))
                    }
                }
            )) {
                Text("Absolute").tag("absolute")
                Text("Relative").tag("relative")
            }
            .pickerStyle(.segmented)

            switch mode {
            case .absolute(let value):
                Picker(label, selection: Binding(
                    get: { value },
                    set: { step = makeStep(.absolute(value: $0)) }
                )) {
                    ForEach(values, id: \.self) { Text($0).tag($0) }
                }
            case .relative(let direction, let steps):
                HStack {
                    Picker("Direction", selection: Binding(
                        get: { direction },
                        set: { step = makeStep(.relative(direction: $0, steps: steps)) }
                    )) {
                        ForEach(RelativeDirection.allCases, id: \.self) {
                            Text($0 == .up ? "Up" : "Down").tag($0)
                        }
                    }
                    Stepper("\(steps) step\(steps == 1 ? "" : "s")", value: Binding(
                        get: { steps },
                        set: { step = makeStep(.relative(direction: direction, steps: max(1, $0))) }
                    ), in: 1...10)
                }
            }
        }
    }

    private func fetchCameras() async {
        cameraListError = nil
        let result = AppleScriptBridge.fetchCameraList()
        switch result {
        case .success(let cameras):
            cameraList = cameras
            // If previously selected camera is no longer available, reset to incomplete
            if case .switchCamera(let mode) = step,
               case .specific(let name) = mode,
               let name,
               !cameras.contains(name) {
                step = .switchCamera(mode: .specific(cameraName: nil))
            }
        case .failure:
            cameraListError = "Connect cameras in Capture One to select"
            cameraList = []
        }
    }
}

enum StepExecutionState {
    case idle
    case running
    case completed
}
