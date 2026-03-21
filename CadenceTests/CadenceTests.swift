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
