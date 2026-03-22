import SwiftUI

/// Stable wrapper for SequenceStep that provides a UUID for SwiftUI list identity.
/// SequenceStep itself is not Identifiable because enum identity would change on mutation,
/// causing SwiftUI list instability. This wrapper provides a stable UUID per list position.
struct IdentifiableStep: Identifiable {
    let id: UUID
    var step: SequenceStep

    init(step: SequenceStep) {
        self.id = UUID()
        self.step = step
    }
}

struct ContentView: View {
    @State private var steps: [IdentifiableStep] = []
    @State private var expandedStepID: UUID?
    @State private var showAddStepPopover = false
    @State private var showPresetsPopover = false
    @State private var showSavePresetSheet = false
    @State private var showResetConfirmation = false
    @State private var repeatCount: Int = 1
    @State private var saveError: String?

    @State private var runner = SequenceRunner()
    @State private var presetManager = PresetManager()

    private var canRun: Bool {
        !steps.isEmpty && steps.allSatisfy(\.step.isComplete)
    }

    private var runLabel: String {
        guard runner.isRunning else { return "Run" }
        return repeatCount > 1 ? "Running \(runner.currentIteration)/\(repeatCount)" : "Running…"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cadence")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                HStack(spacing: 4) {
                Button(action: { showSavePresetSheet = true }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14))
                        .frame(width: 22, height: 22)
                        .offset(y: -2)
                }
                .buttonStyle(.borderless)
                .disabled(steps.isEmpty || runner.isRunning)

                Button(action: { showPresetsPopover = true }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .disabled(runner.isRunning)
                .popover(isPresented: $showPresetsPopover) {
                    PresetsPopover(
                        presetManager: presetManager,
                        hasExistingSteps: !steps.isEmpty,
                        onLoad: loadPreset
                    )
                }
                } // HStack(spacing: 4)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            // Sequence list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, item in
                        StepCardView(
                            step: binding(for: item.id),
                            isExpanded: expandedStepID == item.id,
                            executionState: executionState(for: index),
                            onTap: { toggleExpanded(item.id) },
                            onRemove: { removeStep(item.id) }
                        )
                        .disabled(runner.isRunning)

                        if index < steps.count - 1 {
                            StepConnectorView()
                        }
                    }

                    Button(action: { showAddStepPopover.toggle() }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Step")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .disabled(runner.isRunning)
                    .popover(isPresented: $showAddStepPopover) {
                        AddStepPopover { step in
                            addStep(step)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Control bar
            ControlBar(
                isRunning: runner.isRunning,
                canRun: canRun,
                runLabel: runLabel,
                repeatCount: repeatCount,
                onRun: { runner.run(steps: steps.map(\.step), repeatCount: repeatCount) },
                onStop: { runner.stop() },
                onReset: { showResetConfirmation = true },
                onRepeatCountChange: { repeatCount = max(1, min(99, $0)) }
            )
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .overlay(alignment: .bottom) {
            if let toast = runner.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: runner.toastMessage)
        .alert("Reset Sequence", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) { steps.removeAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all steps from the current sequence.")
        }
        .alert("Error", isPresented: .init(
            get: { runner.error != nil },
            set: { if !$0 { runner.error = nil } }
        )) {
            Button("OK") { runner.error = nil }
        } message: {
            Text(runner.error?.message ?? "")
        }
        .sheet(isPresented: $showSavePresetSheet) {
            SavePresetSheet(presetManager: presetManager) { name in
                let seq = CadenceSequence(name: name, steps: steps.map(\.step))
                do {
                    try presetManager.save(seq, name: name)
                } catch {
                    saveError = error.localizedDescription
                }
            }
        }
        .alert("Save Failed", isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Helpers

    private func binding(for id: UUID) -> Binding<SequenceStep> {
        Binding(
            get: { steps.first(where: { $0.id == id })?.step ?? .wait(seconds: 5) },
            set: { newValue in
                if let index = steps.firstIndex(where: { $0.id == id }) {
                    steps[index].step = newValue
                }
            }
        )
    }

    private func executionState(for index: Int) -> StepExecutionState {
        guard runner.isRunning, let current = runner.currentStepIndex else { return .idle }
        if index < current { return .completed }
        if index == current { return .running }
        return .idle
    }

    private func toggleExpanded(_ id: UUID) {
        guard !runner.isRunning else { return }
        expandedStepID = expandedStepID == id ? nil : id
    }

    private func removeStep(_ id: UUID) {
        steps.removeAll(where: { $0.id == id })
        if expandedStepID == id { expandedStepID = nil }
    }

    private func addStep(_ step: SequenceStep) {
        let item = IdentifiableStep(step: step)
        steps.append(item)
        expandedStepID = item.id
        showAddStepPopover = false
    }

    private func loadPreset(_ sequence: CadenceSequence) {
        steps = sequence.steps.map { IdentifiableStep(step: $0) }
        expandedStepID = nil
        showPresetsPopover = false
    }
}
