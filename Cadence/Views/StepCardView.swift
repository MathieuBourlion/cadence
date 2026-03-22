import SwiftUI

struct StepCardView: View {
    @Binding var step: SequenceStep
    @Binding var firstIterationOnly: Bool
    let isExpanded: Bool
    let executionState: StepExecutionState
    let onTap: () -> Void
    let onRemove: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let isFirst: Bool
    let isLast: Bool
    var globalFetchedISO: [String] = []
    var globalFetchedAperture: [String] = []
    var globalFetchedShutterSpeed: [String] = []

    @State private var pulseOpacity: Double = 1.0
    @State private var cameraList: [String] = []
    @State private var cameraListError: String?
    @State private var fetchedValues: [String]? = nil
    @State private var isFetchingValues = false
    @State private var fetchMessage: String? = nil

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
                        if firstIterationOnly {
                            Text("First pass only")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 2) {
                        Button(action: { firstIterationOnly.toggle() }) {
                            Image(systemName: firstIterationOnly ? "1.circle.fill" : "1.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(firstIterationOnly ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        }
                        .buttonStyle(.plain)
                        .help("First pass only — this step runs once and is skipped on repeat iterations")

                        Button(action: onMoveUp) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 11))
                                .foregroundStyle(isFirst ? .tertiary : .secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(isFirst)

                        Button(action: onMoveDown) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11))
                                .foregroundStyle(isLast ? .tertiary : .secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLast)

                        Button(action: onRemove) {
                            Image(systemName: "xmark")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
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
                globalValues: globalFetchedISO,
                defaultAbsolute: "400",
                makeStep: { step = .setISO(mode: $0) }
            )

        case .setAperture(let mode):
            cameraValueEditor(
                mode: mode,
                label: "Aperture",
                values: SequenceStep.apertureValues,
                globalValues: globalFetchedAperture,
                defaultAbsolute: "f/5.6",
                makeStep: { step = .setAperture(mode: $0) }
            )

        case .setShutterSpeed(let mode):
            cameraValueEditor(
                mode: mode,
                label: "Shutter Speed",
                values: SequenceStep.shutterSpeedValues,
                globalValues: globalFetchedShutterSpeed,
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
        globalValues: [String],
        defaultAbsolute: String,
        makeStep: @escaping (CameraValueMode) -> Void
    ) -> some View {
        // Priority: per-step fetch > global fetch > static fallback
        let displayValues = fetchedValues ?? (globalValues.isEmpty ? values : globalValues)
        VStack(alignment: .leading, spacing: 8) {
            Picker("Mode", selection: Binding(
                get: { if case .relative = mode { return "relative" } else { return "absolute" } },
                set: { newMode in
                    if newMode == "relative" {
                        makeStep(.relative(direction: .up, steps: 1))
                    } else {
                        makeStep(.absolute(value: displayValues.first ?? defaultAbsolute))
                    }
                }
            )) {
                Text("Absolute").tag("absolute")
                Text("Relative").tag("relative")
            }
            .pickerStyle(.segmented)

            switch mode {
            case .absolute(let value):
                HStack {
                    Picker(label, selection: Binding(
                        get: { value },
                        set: { makeStep(.absolute(value: $0)) }
                    )) {
                        ForEach(displayValues, id: \.self) { Text($0).tag($0) }
                    }
                    Button {
                        Task { await fetchValuesForStep() }
                    } label: {
                        if isFetchingValues {
                            ProgressView().controlSize(.mini).frame(width: 14)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                                .foregroundStyle(fetchedValues != nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isFetchingValues)
                    .help("Fetch available values from connected camera")
                }
                if let msg = fetchMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(fetchedValues != nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                }

            case .relative(let dir, let steps):
                HStack {
                    Spacer()
                    Stepper("\(steps) step\(steps == 1 ? "" : "s")", value: Binding(
                        get: { steps },
                        set: { makeStep(.relative(direction: dir, steps: max(1, min(18, $0)))) }
                    ), in: 1...18)
                    Picker("Direction", selection: Binding(
                        get: { dir },
                        set: { makeStep(.relative(direction: $0, steps: steps)) }
                    )) {
                        Text("Up").tag(RelativeDirection.up)
                        Text("Down").tag(RelativeDirection.down)
                    }
                    .pickerStyle(.segmented)
                    .frame(minWidth: 90)
                }
            }
        }
    }

    private func fetchValuesForStep() async {
        isFetchingValues = true
        fetchMessage = nil
        let currentStep = step
        let result = await Task.detached(priority: .userInitiated) {
            switch currentStep {
            case .setISO:          return AppleScriptBridge.fetchAvailableISO()
            case .setAperture:     return AppleScriptBridge.fetchAvailableAperture()
            case .setShutterSpeed: return AppleScriptBridge.fetchAvailableShutterSpeed()
            default:               return .success([String]())
            }
        }.value
        isFetchingValues = false
        switch result {
        case .success(let values) where !values.isEmpty:
            fetchedValues = values
            fetchMessage = "\(values.count) values loaded from camera"
        case .success:
            fetchMessage = "No values returned — camera may not support this"
        case .failure(let err):
            fetchMessage = "Failed: \(err.message)"
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
