import XCTest
@testable import Cadence

final class SequenceStepTests: XCTestCase {

    // MARK: - isComplete

    func test_captureStep_isComplete() {
        XCTAssertTrue(SequenceStep.capture(postCaptureDelay: 3).isComplete)
    }

    func test_switchCamera_specific_withName_isComplete() {
        XCTAssertTrue(SequenceStep.switchCamera(mode: .specific(cameraName: "Canon R5")).isComplete)
    }

    func test_switchCamera_specific_withoutName_isIncomplete() {
        XCTAssertFalse(SequenceStep.switchCamera(mode: .specific(cameraName: nil)).isComplete)
    }

    func test_switchCamera_next_isComplete() {
        XCTAssertTrue(SequenceStep.switchCamera(mode: .next).isComplete)
    }

    func test_allOtherSteps_areComplete() {
        let steps: [SequenceStep] = [
            .setISO(mode: .absolute(value: "400")),
            .setISO(mode: .relative(direction: .up, steps: 2)),
            .setAperture(mode: .absolute(value: "f/5.6")),
            .setAperture(mode: .relative(direction: .down, steps: 1)),
            .setShutterSpeed(mode: .absolute(value: "1/125")),
            .setShutterSpeed(mode: .relative(direction: .up, steps: 3)),
            .autofocus,
            .moveFocus(direction: .nearer, amount: .medium),
            .wait(seconds: 5)
        ]
        for step in steps {
            XCTAssertTrue(step.isComplete, "Expected \(step) to be complete")
        }
    }

    // MARK: - configSummary

    func test_configSummary_switchCamera_specificWithName() {
        XCTAssertEqual(
            SequenceStep.switchCamera(mode: .specific(cameraName: "Canon R5")).configSummary,
            "Canon R5"
        )
    }

    func test_configSummary_switchCamera_specificNoName() {
        XCTAssertEqual(
            SequenceStep.switchCamera(mode: .specific(cameraName: nil)).configSummary,
            "⚠ No camera selected"
        )
    }

    func test_configSummary_switchCamera_next() {
        XCTAssertEqual(
            SequenceStep.switchCamera(mode: .next).configSummary,
            "Next camera (wraps)"
        )
    }

    func test_configSummary_setISO_absolute() {
        XCTAssertEqual(SequenceStep.setISO(mode: .absolute(value: "800")).configSummary, "ISO 800")
    }

    func test_configSummary_setISO_relative_up_plural() {
        XCTAssertEqual(
            SequenceStep.setISO(mode: .relative(direction: .up, steps: 2)).configSummary,
            "ISO +2 steps"
        )
    }

    func test_configSummary_setISO_relative_down_singular() {
        XCTAssertEqual(
            SequenceStep.setISO(mode: .relative(direction: .down, steps: 1)).configSummary,
            "ISO −1 step"
        )
    }

    func test_configSummary_setAperture_relative() {
        XCTAssertEqual(
            SequenceStep.setAperture(mode: .relative(direction: .up, steps: 3)).configSummary,
            "Aperture +3 steps"
        )
    }

    func test_configSummary_setShutterSpeed_relative() {
        XCTAssertEqual(
            SequenceStep.setShutterSpeed(mode: .relative(direction: .down, steps: 1)).configSummary,
            "Shutter −1 step"
        )
    }

    // MARK: - Codable round-trip (new format)

    func test_capture_roundTrip() throws {
        let original = SequenceStep.capture(postCaptureDelay: 7)
        let decoded = try roundTrip(original)
        XCTAssertEqual(original, decoded)
    }

    func test_switchCamera_specific_roundTrip_cameraNameDropped() throws {
        // Camera name is intentionally NOT saved; decoded as nil
        let original = SequenceStep.switchCamera(mode: .specific(cameraName: "Canon R5"))
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, .switchCamera(mode: .specific(cameraName: nil)))
    }

    func test_switchCamera_next_roundTrip() throws {
        let original = SequenceStep.switchCamera(mode: .next)
        let decoded = try roundTrip(original)
        XCTAssertEqual(original, decoded)
    }

    func test_setISO_absolute_roundTrip() throws {
        let original = SequenceStep.setISO(mode: .absolute(value: "800"))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_setISO_relative_roundTrip() throws {
        let original = SequenceStep.setISO(mode: .relative(direction: .up, steps: 3))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_setAperture_absolute_roundTrip() throws {
        let original = SequenceStep.setAperture(mode: .absolute(value: "f/8"))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_setAperture_relative_roundTrip() throws {
        let original = SequenceStep.setAperture(mode: .relative(direction: .down, steps: 2))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_setShutterSpeed_absolute_roundTrip() throws {
        let original = SequenceStep.setShutterSpeed(mode: .absolute(value: "1/250"))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_setShutterSpeed_relative_roundTrip() throws {
        let original = SequenceStep.setShutterSpeed(mode: .relative(direction: .up, steps: 1))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_autofocus_roundTrip() throws {
        let original = SequenceStep.autofocus
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_moveFocus_roundTrip() throws {
        let original = SequenceStep.moveFocus(direction: .further, amount: .large)
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_wait_roundTrip() throws {
        let original = SequenceStep.wait(seconds: 15)
        XCTAssertEqual(try roundTrip(original), original)
    }

    // MARK: - Codable migration (old JSON format → new API)

    func test_switchCamera_oldFormat_decodesAsSpecificNil() throws {
        // Old format: { "type": "switchCamera", "config": {} }
        let json = #"{"type":"switchCamera","config":{}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: json)
        XCTAssertEqual(decoded, .switchCamera(mode: .specific(cameraName: nil)))
    }

    func test_setISO_oldFormat_decodesAsAbsolute() throws {
        // Old format: { "type": "setISO", "config": { "value": "400" } }
        let json = #"{"type":"setISO","config":{"value":"400"}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: json)
        XCTAssertEqual(decoded, .setISO(mode: .absolute(value: "400")))
    }

    func test_setAperture_oldFormat_decodesAsAbsolute() throws {
        let json = #"{"type":"setAperture","config":{"value":"f\/5.6"}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: json)
        XCTAssertEqual(decoded, .setAperture(mode: .absolute(value: "f/5.6")))
    }

    func test_setShutterSpeed_oldFormat_decodesAsAbsolute() throws {
        let json = #"{"type":"setShutterSpeed","config":{"value":"1\/125"}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: json)
        XCTAssertEqual(decoded, .setShutterSpeed(mode: .absolute(value: "1/125")))
    }

    // MARK: - JSON format (spec compliance)

    func test_capture_JSONFormat() throws {
        let data = try JSONEncoder().encode(SequenceStep.capture(postCaptureDelay: 3))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "capture")
        XCTAssertEqual((json["config"] as! [String: Int])["postCaptureDelay"], 3)
    }

    func test_wait_JSONFormat() throws {
        let data = try JSONEncoder().encode(SequenceStep.wait(seconds: 10))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "wait")
        XCTAssertEqual((json["config"] as! [String: Int])["seconds"], 10)
    }

    func test_switchCamera_specific_JSONFormat_hasNoName() throws {
        let data = try JSONEncoder().encode(SequenceStep.switchCamera(mode: .specific(cameraName: "Canon")))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "switchCamera")
        let config = json["config"] as! [String: String]
        XCTAssertEqual(config["mode"], "specific")
        XCTAssertNil(config["cameraName"], "Camera name should not be saved")
    }

    func test_switchCamera_next_JSONFormat() throws {
        let data = try JSONEncoder().encode(SequenceStep.switchCamera(mode: .next))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual((json["config"] as! [String: String])["mode"], "next")
    }

    func test_setISO_absolute_JSONFormat() throws {
        let data = try JSONEncoder().encode(SequenceStep.setISO(mode: .absolute(value: "400")))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let config = json["config"] as! [String: String]
        XCTAssertEqual(config["mode"], "absolute")
        XCTAssertEqual(config["value"], "400")
    }

    func test_setISO_relative_JSONFormat() throws {
        let data = try JSONEncoder().encode(SequenceStep.setISO(mode: .relative(direction: .up, steps: 2)))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let config = json["config"] as! [String: Any]
        XCTAssertEqual(config["mode"] as? String, "relative")
        XCTAssertEqual(config["direction"] as? String, "up")
        XCTAssertEqual(config["steps"] as? Int, 2)
    }

    // MARK: - typeName

    func test_typeName() {
        XCTAssertEqual(SequenceStep.capture(postCaptureDelay: 3).typeName, "Capture")
        XCTAssertEqual(SequenceStep.switchCamera(mode: .next).typeName, "Switch Camera")
        XCTAssertEqual(SequenceStep.setISO(mode: .absolute(value: "400")).typeName, "Set ISO")
        XCTAssertEqual(SequenceStep.setAperture(mode: .absolute(value: "f/5.6")).typeName, "Set Aperture")
        XCTAssertEqual(SequenceStep.setShutterSpeed(mode: .absolute(value: "1/125")).typeName, "Set Shutter Speed")
        XCTAssertEqual(SequenceStep.autofocus.typeName, "Autofocus")
        XCTAssertEqual(SequenceStep.moveFocus(direction: .nearer, amount: .medium).typeName, "Move Focus")
        XCTAssertEqual(SequenceStep.wait(seconds: 5).typeName, "Wait")
    }

    // MARK: - Helpers

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }
}

final class CadenceSequenceTests: XCTestCase {

    func test_emptySequence_cannotRun() {
        XCTAssertFalse(CadenceSequence(steps: []).canRun)
    }

    func test_sequenceWithCompleteSteps_canRun() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 3),
            .setISO(mode: .absolute(value: "400"))
        ])
        XCTAssertTrue(seq.canRun)
    }

    func test_sequenceWithIncompleteStep_cannotRun() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 3),
            .switchCamera(mode: .specific(cameraName: nil))
        ])
        XCTAssertFalse(seq.canRun)
    }

    func test_switchCamera_next_isConsideredComplete_forCanRun() {
        let seq = CadenceSequence(steps: [
            .switchCamera(mode: .next)
        ])
        XCTAssertTrue(seq.canRun)
    }

    func test_strippedForPreset_clearsSpecificCameraName() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 3),
            .switchCamera(mode: .specific(cameraName: "Canon EOS R5")),
            .setISO(mode: .absolute(value: "400"))
        ])
        let stripped = seq.strippedForPreset()
        XCTAssertEqual(stripped.steps[1], .switchCamera(mode: .specific(cameraName: nil)))
    }

    func test_strippedForPreset_preservesNextMode() {
        let seq = CadenceSequence(steps: [.switchCamera(mode: .next)])
        let stripped = seq.strippedForPreset()
        XCTAssertEqual(stripped.steps[0], .switchCamera(mode: .next))
    }

    func test_strippedForPreset_preservesOtherSteps() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 5),
            .switchCamera(mode: .specific(cameraName: "Canon R5")),
            .wait(seconds: 10)
        ])
        let stripped = seq.strippedForPreset()
        XCTAssertEqual(stripped.steps[0], .capture(postCaptureDelay: 5))
        XCTAssertEqual(stripped.steps[2], .wait(seconds: 10))
    }

    func test_codableRoundTrip() throws {
        let original = CadenceSequence(name: "Test Preset", steps: [
            .capture(postCaptureDelay: 3),
            .setISO(mode: .absolute(value: "800")),
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
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.capture(postCaptureDelay: 3)),
            #"tell application "Capture One" to capture"#
        )
    }

    func test_switchCamera_specific_withName_script() {
        let script = AppleScriptBridge.scriptForStep(.switchCamera(mode: .specific(cameraName: "Canon EOS R5")))
        XCTAssertEqual(script, #"tell application "Capture One" to select camera of front document name "Canon EOS R5""#)
    }

    func test_switchCamera_specific_withoutName_returnsNil() {
        XCTAssertNil(AppleScriptBridge.scriptForStep(.switchCamera(mode: .specific(cameraName: nil))))
    }

    func test_switchCamera_next_returnsNil() {
        // .next is handled by SequenceRunner, not scriptForStep
        XCTAssertNil(AppleScriptBridge.scriptForStep(.switchCamera(mode: .next)))
    }

    func test_switchCamera_withQuoteInName_escapesCorrectly() {
        let script = AppleScriptBridge.scriptForStep(.switchCamera(mode: .specific(cameraName: #"Canon "R5""#)))
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains(#"\"R5\""#))
    }

    func test_setISO_absolute_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.setISO(mode: .absolute(value: "400"))),
            #"set ISO of camera of front document of application "Capture One" to "400""#
        )
    }

    func test_setISO_relative_returnsNil() {
        // Relative mode is handled by SequenceRunner
        XCTAssertNil(AppleScriptBridge.scriptForStep(.setISO(mode: .relative(direction: .up, steps: 2))))
    }

    func test_setAperture_absolute_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.setAperture(mode: .absolute(value: "f/5.6"))),
            #"set aperture of camera of front document of application "Capture One" to "f/5.6""#
        )
    }

    func test_setAperture_relative_returnsNil() {
        XCTAssertNil(AppleScriptBridge.scriptForStep(.setAperture(mode: .relative(direction: .down, steps: 1))))
    }

    func test_setShutterSpeed_absolute_plainValue_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.setShutterSpeed(mode: .absolute(value: "1/125"))),
            #"set shutter speed of camera of front document of application "Capture One" to "1/125""#
        )
    }

    func test_setShutterSpeed_absolute_longExposure_escapesQuote() {
        let script = AppleScriptBridge.scriptForStep(.setShutterSpeed(mode: .absolute(value: #"1""#)))
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains(#"\""#))
    }

    func test_setShutterSpeed_relative_returnsNil() {
        XCTAssertNil(AppleScriptBridge.scriptForStep(.setShutterSpeed(mode: .relative(direction: .up, steps: 1))))
    }

    func test_autofocus_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.autofocus),
            #"set autofocusing of camera of front document of application "Capture One" to true"#
        )
    }

    func test_moveFocus_nearerMedium_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.moveFocus(direction: .nearer, amount: .medium)),
            #"tell application "Capture One" to adjust focus of camera of front document by amount -3 sync true"#
        )
    }

    func test_moveFocus_furtherLarge_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.moveFocus(direction: .further, amount: .large)),
            #"tell application "Capture One" to adjust focus of camera of front document by amount 7 sync true"#
        )
    }

    func test_wait_returnsNilScript() {
        XCTAssertNil(AppleScriptBridge.scriptForStep(.wait(seconds: 5)))
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

    func test_readBackScript_forISO_absolute() {
        XCTAssertEqual(
            AppleScriptBridge.readBackScript(for: .setISO(mode: .absolute(value: "400"))),
            #"ISO of camera of front document of application "Capture One""#
        )
    }

    func test_readBackScript_forISO_relative_isNil() {
        // Relative handles its own read-back inside SequenceRunner
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .setISO(mode: .relative(direction: .up, steps: 1))))
    }

    func test_readBackScript_forAperture_absolute() {
        XCTAssertEqual(
            AppleScriptBridge.readBackScript(for: .setAperture(mode: .absolute(value: "f/5.6"))),
            #"aperture of camera of front document of application "Capture One""#
        )
    }

    func test_readBackScript_forAperture_relative_isNil() {
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .setAperture(mode: .relative(direction: .down, steps: 1))))
    }

    func test_readBackScript_forShutterSpeed_absolute() {
        XCTAssertEqual(
            AppleScriptBridge.readBackScript(for: .setShutterSpeed(mode: .absolute(value: "1/125"))),
            #"shutter speed of camera of front document of application "Capture One""#
        )
    }

    func test_readBackScript_forShutterSpeed_relative_isNil() {
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .setShutterSpeed(mode: .relative(direction: .up, steps: 1))))
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
            .setISO(mode: .absolute(value: "800"))
        ])
        try manager.save(seq, name: "Test")
        let loaded = try manager.load(name: "Test")
        XCTAssertEqual(loaded.steps.count, 2)
        XCTAssertEqual(loaded.steps[0], .capture(postCaptureDelay: 5))
        XCTAssertEqual(loaded.steps[1], .setISO(mode: .absolute(value: "800")))
    }

    func test_save_stripsSpecificCameraName() throws {
        let seq = CadenceSequence(steps: [.switchCamera(mode: .specific(cameraName: "Canon R5"))])
        try manager.save(seq, name: "CamTest")
        let loaded = try manager.load(name: "CamTest")
        XCTAssertEqual(loaded.steps[0], .switchCamera(mode: .specific(cameraName: nil)))
    }

    func test_save_preservesNextCameraMode() throws {
        let seq = CadenceSequence(steps: [.switchCamera(mode: .next)])
        try manager.save(seq, name: "NextCam")
        let loaded = try manager.load(name: "NextCam")
        XCTAssertEqual(loaded.steps[0], .switchCamera(mode: .next))
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
        XCTAssertEqual(try manager.listPresets(), ["Alpha", "Mango", "Zebra"])
    }

    func test_listPresets_emptyWhenNoPresets() throws {
        XCTAssertTrue(try manager.listPresets().isEmpty)
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
        // NOTE: currentIteration test is in Task 4 (added after SequenceRunner is updated)
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
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .setISO(mode: .absolute(value: "400"))), 0.0)
    }

    func test_postStepDelay_switchCamera_isZero() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .switchCamera(mode: .specific(cameraName: "Canon"))), 0.0)
    }

    func test_postStepDelay_switchCamera_next_isZero() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .switchCamera(mode: .next)), 0.0)
    }
}
