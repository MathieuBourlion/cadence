import Foundation

// MARK: - Supporting Types

enum FocusDirection: String, Codable, CaseIterable {
    case nearer
    case further
}

enum FocusAmount: String, Codable, CaseIterable {
    case small
    case medium
    case large
}

// MARK: - SequenceStep

/// An individual step in a Cadence sequence.
/// Note: SequenceStep does NOT conform to Identifiable. When used in SwiftUI Lists,
/// wrap in IdentifiableStep (see ContentView) to get a stable UUID per list item.
enum SequenceStep: Codable, Equatable {
    case capture(postCaptureDelay: Int)
    case switchCamera(cameraName: String?)
    case setISO(value: String)
    case setAperture(value: String)
    case setShutterSpeed(value: String)
    case autofocus
    case moveFocus(direction: FocusDirection, amount: FocusAmount)
    case wait(seconds: Int)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type, config
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "capture":
            let config = try container.decode([String: Int].self, forKey: .config)
            self = .capture(postCaptureDelay: config["postCaptureDelay"] ?? 3)
        case "switchCamera":
            let config = try container.decode([String: String].self, forKey: .config)
            self = .switchCamera(cameraName: config["cameraName"])
        case "setISO":
            let config = try container.decode([String: String].self, forKey: .config)
            self = .setISO(value: config["value"] ?? "400")
        case "setAperture":
            let config = try container.decode([String: String].self, forKey: .config)
            self = .setAperture(value: config["value"] ?? "f/5.6")
        case "setShutterSpeed":
            let config = try container.decode([String: String].self, forKey: .config)
            self = .setShutterSpeed(value: config["value"] ?? "1/125")
        case "autofocus":
            self = .autofocus
        case "moveFocus":
            let config = try container.decode([String: String].self, forKey: .config)
            let direction = FocusDirection(rawValue: config["direction"] ?? "nearer") ?? .nearer
            let amount = FocusAmount(rawValue: config["amount"] ?? "medium") ?? .medium
            self = .moveFocus(direction: direction, amount: amount)
        case "wait":
            let config = try container.decode([String: Int].self, forKey: .config)
            self = .wait(seconds: config["seconds"] ?? 5)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                debugDescription: "Unknown step type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .capture(let delay):
            try container.encode("capture", forKey: .type)
            try container.encode(["postCaptureDelay": delay], forKey: .config)
        case .switchCamera:
            try container.encode("switchCamera", forKey: .type)
            // Camera name is NOT saved in presets — always loads as incomplete
            try container.encode([String: String](), forKey: .config)
        case .setISO(let value):
            try container.encode("setISO", forKey: .type)
            try container.encode(["value": value], forKey: .config)
        case .setAperture(let value):
            try container.encode("setAperture", forKey: .type)
            try container.encode(["value": value], forKey: .config)
        case .setShutterSpeed(let value):
            try container.encode("setShutterSpeed", forKey: .type)
            try container.encode(["value": value], forKey: .config)
        case .autofocus:
            try container.encode("autofocus", forKey: .type)
            try container.encode([String: String](), forKey: .config)
        case .moveFocus(let direction, let amount):
            try container.encode("moveFocus", forKey: .type)
            try container.encode(["direction": direction.rawValue, "amount": amount.rawValue], forKey: .config)
        case .wait(let seconds):
            try container.encode("wait", forKey: .type)
            try container.encode(["seconds": seconds], forKey: .config)
        }
    }

    // MARK: - Validation

    /// Returns false only for switchCamera steps where no camera has been selected.
    var isComplete: Bool {
        if case .switchCamera(let name) = self {
            return name != nil
        }
        return true
    }

    // MARK: - Display

    var typeName: String {
        switch self {
        case .capture: return "Capture"
        case .switchCamera: return "Switch Camera"
        case .setISO: return "Set ISO"
        case .setAperture: return "Set Aperture"
        case .setShutterSpeed: return "Set Shutter Speed"
        case .autofocus: return "Autofocus"
        case .moveFocus: return "Move Focus"
        case .wait: return "Wait"
        }
    }

    var configSummary: String {
        switch self {
        case .capture(let delay):
            return "Post-capture delay: \(delay)s"
        case .switchCamera(let name):
            return name ?? "⚠ No camera selected"
        case .setISO(let value):
            return "ISO \(value)"
        case .setAperture(let value):
            return value
        case .setShutterSpeed(let value):
            return value
        case .autofocus:
            return "Triggers autofocus, waits 1s"
        case .moveFocus(let direction, let amount):
            return "\(amount.rawValue.capitalized) step \(direction.rawValue)"
        case .wait(let seconds):
            return "Wait \(seconds)s"
        }
    }

    // MARK: - Static value lists

    static let isoValues = ["100", "125", "160", "200", "250", "320", "400", "500",
                             "640", "800", "1000", "1250", "1600", "2000", "2500",
                             "3200", "6400", "12800", "25600"]

    static let apertureValues = ["f/1.4", "f/1.8", "f/2", "f/2.8", "f/3.5", "f/4",
                                  "f/5.6", "f/6.3", "f/7.1", "f/8", "f/11", "f/13",
                                  "f/16", "f/18", "f/22"]

    static let shutterSpeedValues = ["1/4000", "1/2000", "1/1000", "1/500", "1/250",
                                      "1/125", "1/60", "1/30", "1/15", "1/8", "1/4",
                                      "1/2", "1\"", "2\"", "4\"", "8\"", "15\"", "30\""]
}
