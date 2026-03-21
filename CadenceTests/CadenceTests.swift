import XCTest
@testable import Cadence

final class SequenceStepTests: XCTestCase {

    // MARK: - isComplete

    func test_captureStep_isComplete() {
        let step = SequenceStep.capture(postCaptureDelay: 3)
        XCTAssertTrue(step.isComplete)
    }

    func test_switchCamera_withName_isComplete() {
        let step = SequenceStep.switchCamera(cameraName: "Canon EOS R5")
        XCTAssertTrue(step.isComplete)
    }

    func test_switchCamera_withoutName_isIncomplete() {
        let step = SequenceStep.switchCamera(cameraName: nil)
        XCTAssertFalse(step.isComplete)
    }

    func test_allOtherSteps_areComplete() {
        let steps: [SequenceStep] = [
            .setISO(value: "400"),
            .setAperture(value: "f/5.6"),
            .setShutterSpeed(value: "1/125"),
            .autofocus,
            .moveFocus(direction: .nearer, amount: .medium),
            .wait(seconds: 5)
        ]
        for step in steps {
            XCTAssertTrue(step.isComplete, "Expected \(step) to be complete")
        }
    }

    // MARK: - Codable round-trip

    func test_capture_roundTrip() throws {
        let original = SequenceStep.capture(postCaptureDelay: 7)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_switchCamera_withName_roundTrip() throws {
        // Camera name is intentionally NOT saved; decoded as nil
        let original = SequenceStep.switchCamera(cameraName: "Canon R5")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        // After decode, camera name should be nil (preset behavior)
        XCTAssertEqual(decoded, .switchCamera(cameraName: nil))
    }

    func test_setISO_roundTrip() throws {
        let original = SequenceStep.setISO(value: "800")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_setAperture_roundTrip() throws {
        let original = SequenceStep.setAperture(value: "f/8")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_setShutterSpeed_roundTrip() throws {
        let original = SequenceStep.setShutterSpeed(value: "1/250")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_autofocus_roundTrip() throws {
        let original = SequenceStep.autofocus
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_moveFocus_roundTrip() throws {
        let original = SequenceStep.moveFocus(direction: .further, amount: .large)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_wait_roundTrip() throws {
        let original = SequenceStep.wait(seconds: 15)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - JSON format (spec compliance)

    func test_capture_JSONFormat() throws {
        let step = SequenceStep.capture(postCaptureDelay: 3)
        let data = try JSONEncoder().encode(step)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "capture")
        let config = json["config"] as! [String: Int]
        XCTAssertEqual(config["postCaptureDelay"], 3)
    }

    func test_wait_JSONFormat() throws {
        let step = SequenceStep.wait(seconds: 10)
        let data = try JSONEncoder().encode(step)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "wait")
        let config = json["config"] as! [String: Int]
        XCTAssertEqual(config["seconds"], 10)
    }

    func test_switchCamera_JSONFormat_omitsCameraName() throws {
        // Per spec: Switch Camera steps save with no camera name
        let step = SequenceStep.switchCamera(cameraName: "Canon R5")
        let data = try JSONEncoder().encode(step)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "switchCamera")
        let config = json["config"] as! [String: String]
        XCTAssertTrue(config.isEmpty, "Camera name should not be saved in preset JSON")
    }

    // MARK: - Display

    func test_typeName() {
        XCTAssertEqual(SequenceStep.capture(postCaptureDelay: 3).typeName, "Capture")
        XCTAssertEqual(SequenceStep.switchCamera(cameraName: nil).typeName, "Switch Camera")
        XCTAssertEqual(SequenceStep.setISO(value: "400").typeName, "Set ISO")
        XCTAssertEqual(SequenceStep.setAperture(value: "f/5.6").typeName, "Set Aperture")
        XCTAssertEqual(SequenceStep.setShutterSpeed(value: "1/125").typeName, "Set Shutter Speed")
        XCTAssertEqual(SequenceStep.autofocus.typeName, "Autofocus")
        XCTAssertEqual(SequenceStep.moveFocus(direction: .nearer, amount: .medium).typeName, "Move Focus")
        XCTAssertEqual(SequenceStep.wait(seconds: 5).typeName, "Wait")
    }
}

final class CadenceSequenceTests: XCTestCase {

    func test_emptySequence_cannotRun() {
        let seq = CadenceSequence(steps: [])
        XCTAssertFalse(seq.canRun)
    }

    func test_sequenceWithCompleteSteps_canRun() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 3),
            .setISO(value: "400")
        ])
        XCTAssertTrue(seq.canRun)
    }

    func test_sequenceWithIncompleteStep_cannotRun() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 3),
            .switchCamera(cameraName: nil)  // incomplete
        ])
        XCTAssertFalse(seq.canRun)
    }

    func test_strippedForPreset_removesCameraNames() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 3),
            .switchCamera(cameraName: "Canon EOS R5"),
            .setISO(value: "400")
        ])
        let stripped = seq.strippedForPreset()
        XCTAssertEqual(stripped.steps[1], .switchCamera(cameraName: nil))
    }

    func test_strippedForPreset_preservesOtherSteps() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 5),
            .switchCamera(cameraName: "Canon R5"),
            .wait(seconds: 10)
        ])
        let stripped = seq.strippedForPreset()
        XCTAssertEqual(stripped.steps[0], .capture(postCaptureDelay: 5))
        XCTAssertEqual(stripped.steps[2], .wait(seconds: 10))
    }

    func test_codableRoundTrip() throws {
        let original = CadenceSequence(name: "Test Preset", steps: [
            .capture(postCaptureDelay: 3),
            .setISO(value: "800"),
            .wait(seconds: 5)
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CadenceSequence.self, from: data)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.steps.count, original.steps.count)
    }
}

final class AppleScriptBridgeTests: XCTestCase {

    // MARK: - scriptForStep

    func test_capture_script() {
        let script = AppleScriptBridge.scriptForStep(.capture(postCaptureDelay: 3))
        XCTAssertEqual(script, #"tell application "Capture One" to capture"#)
    }

    func test_switchCamera_withName_script() {
        let script = AppleScriptBridge.scriptForStep(.switchCamera(cameraName: "Canon EOS R5"))
        XCTAssertEqual(script, #"tell application "Capture One" to select camera of front document name "Canon EOS R5""#)
    }

    func test_switchCamera_withoutName_returnsNil() {
        let script = AppleScriptBridge.scriptForStep(.switchCamera(cameraName: nil))
        XCTAssertNil(script)
    }

    func test_switchCamera_withQuoteInName_escapesCorrectly() {
        let script = AppleScriptBridge.scriptForStep(.switchCamera(cameraName: #"Canon "R5""#))
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains(#"\"R5\""#), "Quotes in camera name should be escaped")
    }

    func test_setISO_script() {
        let script = AppleScriptBridge.scriptForStep(.setISO(value: "400"))
        XCTAssertEqual(script, #"set ISO of camera of front document of application "Capture One" to "400""#)
    }

    func test_setAperture_script() {
        let script = AppleScriptBridge.scriptForStep(.setAperture(value: "f/5.6"))
        XCTAssertEqual(script, #"set aperture of camera of front document of application "Capture One" to "f/5.6""#)
    }

    func test_setShutterSpeed_withPlainValue_script() {
        let script = AppleScriptBridge.scriptForStep(.setShutterSpeed(value: "1/125"))
        XCTAssertEqual(script, #"set shutter speed of camera of front document of application "Capture One" to "1/125""#)
    }

    func test_setShutterSpeed_withLongExposure_escapesQuote() {
        let script = AppleScriptBridge.scriptForStep(.setShutterSpeed(value: #"1""#))
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains(#"\""#), "Quote in shutter speed value should be escaped")
    }

    func test_autofocus_script() {
        let script = AppleScriptBridge.scriptForStep(.autofocus)
        XCTAssertEqual(script, #"set autofocusing of camera of front document of application "Capture One" to true"#)
    }

    func test_moveFocus_script_nearerMedium() {
        let script = AppleScriptBridge.scriptForStep(.moveFocus(direction: .nearer, amount: .medium))
        XCTAssertEqual(script, #"tell application "Capture One" to adjust focus of camera of front document by amount -3 sync true"#)
    }

    func test_moveFocus_script_furtherLarge() {
        let script = AppleScriptBridge.scriptForStep(.moveFocus(direction: .further, amount: .large))
        XCTAssertEqual(script, #"tell application "Capture One" to adjust focus of camera of front document by amount 7 sync true"#)
    }

    func test_wait_returnsNilScript() {
        let script = AppleScriptBridge.scriptForStep(.wait(seconds: 5))
        XCTAssertNil(script)
    }

    // MARK: - moveFocusAmount

    func test_moveFocusAmount_allCombinations() {
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .nearer, amount: .small), -1)
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .nearer, amount: .medium), -3)
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .nearer, amount: .large), -7)
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .further, amount: .small), 1)
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .further, amount: .medium), 3)
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .further, amount: .large), 7)
    }

    // MARK: - readBackScript

    func test_readBackScript_forISO() {
        let script = AppleScriptBridge.readBackScript(for: .setISO(value: "400"))
        XCTAssertEqual(script, #"ISO of camera of front document of application "Capture One""#)
    }

    func test_readBackScript_forAperture() {
        let script = AppleScriptBridge.readBackScript(for: .setAperture(value: "f/5.6"))
        XCTAssertEqual(script, #"aperture of camera of front document of application "Capture One""#)
    }

    func test_readBackScript_forShutterSpeed() {
        let script = AppleScriptBridge.readBackScript(for: .setShutterSpeed(value: "1/125"))
        XCTAssertEqual(script, #"shutter speed of camera of front document of application "Capture One""#)
    }

    func test_readBackScript_forCapture_isNil() {
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .capture(postCaptureDelay: 3)))
    }

    func test_readBackScript_forWait_isNil() {
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .wait(seconds: 5)))
    }
}

final class PresetManagerTests: XCTestCase {

    var tempDirectory: URL!
    var manager: PresetManager!

    override func setUp() {
        super.setUp()
        // Use a temp directory so tests don't pollute ~/Library
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CadenceTests-\(UUID().uuidString)", isDirectory: true)
        manager = PresetManager(presetsDirectory: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func test_saveAndLoad_roundTrip() throws {
        let seq = CadenceSequence(name: "Test", steps: [
            .capture(postCaptureDelay: 5),
            .setISO(value: "800")
        ])
        try manager.save(seq, name: "Test")
        let loaded = try manager.load(name: "Test")
        XCTAssertEqual(loaded.steps.count, 2)
        XCTAssertEqual(loaded.steps[0], .capture(postCaptureDelay: 5))
        XCTAssertEqual(loaded.steps[1], .setISO(value: "800"))
    }

    func test_save_stripsCameraNames() throws {
        let seq = CadenceSequence(steps: [
            .switchCamera(cameraName: "Canon R5")
        ])
        try manager.save(seq, name: "CamTest")
        let loaded = try manager.load(name: "CamTest")
        XCTAssertEqual(loaded.steps[0], .switchCamera(cameraName: nil))
    }

    func test_delete_removesFile() throws {
        let seq = CadenceSequence(steps: [.autofocus])
        try manager.save(seq, name: "ToDelete")
        XCTAssertTrue(manager.presetExists(name: "ToDelete"))
        try manager.delete(name: "ToDelete")
        XCTAssertFalse(manager.presetExists(name: "ToDelete"))
    }

    func test_listPresets_returnsAlphabeticallySorted() throws {
        for name in ["Zebra", "Alpha", "Mango"] {
            try manager.save(CadenceSequence(steps: [.autofocus]), name: name)
        }
        let list = try manager.listPresets()
        XCTAssertEqual(list, ["Alpha", "Mango", "Zebra"])
    }

    func test_listPresets_emptyWhenNoPresets() throws {
        let list = try manager.listPresets()
        XCTAssertTrue(list.isEmpty)
    }

    func test_presetExists_falseForMissing() {
        XCTAssertFalse(manager.presetExists(name: "NonExistent"))
    }
}

@MainActor
final class SequenceRunnerTests: XCTestCase {

    func test_initialState() {
        let runner = SequenceRunner()
        XCTAssertFalse(runner.isRunning)
        XCTAssertNil(runner.currentStepIndex)
        XCTAssertNil(runner.error)
        XCTAssertNil(runner.toastMessage)
    }

    func test_postStepDelay_capture_usesConfiguredDelay() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .capture(postCaptureDelay: 5)), 5.0)
    }

    func test_postStepDelay_capture_enforcesMinimum3() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .capture(postCaptureDelay: 1)), 3.0)
    }

    func test_postStepDelay_autofocus_is1s() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .autofocus), 1.0)
    }

    func test_postStepDelay_moveFocus_is0_8s() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .moveFocus(direction: .nearer, amount: .small)), 0.8)
    }

    func test_postStepDelay_wait_usesSeconds() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .wait(seconds: 10)), 10.0)
    }

    func test_postStepDelay_setISO_isZero() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .setISO(value: "400")), 0.0)
    }

    func test_postStepDelay_switchCamera_isZero() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .switchCamera(cameraName: "Canon")), 0.0)
    }
}
