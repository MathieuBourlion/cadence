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
            // Header row — wrapped in Button to handle expand/collapse
            Button(action: onTap) {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(duration: 0.2), value: isExpanded)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.typeName)
                            .font(.headline)
                            .foregroundStyle(.primary)
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
            }
            .buttonStyle(.plain)

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
                withAnimation(.default) { pulseOpacity = 1.0 }
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
        case .idle:      return step.isComplete ? .clear : .yellow
        case .running:   return .green
        case .completed: return .green
        }
    }

    private var borderWidth: CGFloat {
        switch executionState {
        case .idle:      return step.isComplete ? 0 : 1.5
        case .running:   return 2
        case .completed: return 1.5
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
                mode: mode,
                label: "ISO",
                values: SequenceStep.isoValues,
                defaultAbsolute: "400",
                makeStep: { step = .setISO(mode: $0) }
            )

        case .setAperture(let mode):
            cameraValueEditor(
                mode: mode,
                label: "Aperture",
                values: SequenceStep.apertureValues,
                defaultAbsolute: "f/5.6",
                makeStep: { step = .setAperture(mode: $0) }
            )

        case .setShutterSpeed(let mode):
            cameraValueEditor(
                mode: mode,
                label: "Shutter Speed",
                values: SequenceStep.shutterSpeedValues,
                defaultAbsolute: "1/125",
                makeStep: { step = .setShutterSpeed(mode: $0) }
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
            Picker("Mode", selection: Binding(
                get: { if case .next = mode { return "next" } else { return "specific" } },
                set: { newMode in
                    step = .switchCamera(mode: newMode == "next" ? .next : .specific(cameraName: nil))
                }
            )) {
                Text("Specific").tag("specific")
                Text("Next").tag("next")
            }
            .pickerStyle(.segmented)

            switch mode {
            case .specific:
                if let error = cameraListError {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                } else if cameraList.isEmpty {
                    Text("Connect cameras in Capture One to select")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Picker("Camera", selection: Binding(
                        get: { if case .specific(let name) = mode { return name ?? "" } else { return "" } },
                        set: { step = .switchCamera(mode: .specific(cameraName: $0.isEmpty ? nil : $0)) }
                    )) {
                        Text("Select camera...").tag("")
                        ForEach(cameraList, id: \.self) { Text($0).tag($0) }
                    }
                }
            case .next:
                Text("Selects the next camera in Capture One's list, wrapping back to the first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func cameraValueEditor(
        mode: CameraValueMode,
        label: String,
        values: [String],
        defaultAbsolute: String,
        makeStep: @escaping (CameraValueMode) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Mode", selection: Binding(
                get: { if case .relative = mode { return "relative" } else { return "absolute" } },
                set: { newMode in
                    if newMode == "relative" {
                        makeStep(.relative(direction: .up, steps: 1))
                    } else {
                        makeStep(.absolute(value: defaultAbsolute))
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
                    set: { makeStep(.absolute(value: $0)) }
                )) {
                    ForEach(values, id: \.self) { Text($0).tag($0) }
                }

            case .relative(let dir, let steps):
                HStack {
                    Picker("Direction", selection: Binding(
                        get: { dir },
                        set: { makeStep(.relative(direction: $0, steps: steps)) }
                    )) {
                        Text("Up").tag(RelativeDirection.up)
                        Text("Down").tag(RelativeDirection.down)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 120)

                    Stepper("\(steps) step\(steps == 1 ? "" : "s")", value: Binding(
                        get: { steps },
                        set: { makeStep(.relative(direction: dir, steps: max(1, min(18, $0)))) }
                    ), in: 1...18)
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
               let name, !cameras.contains(name) {
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
