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

enum RelativeDirection: String, Codable, CaseIterable {
    case up, down
}

enum SwitchCameraMode: Codable, Equatable {
    case specific(cameraName: String?)
    case next

    private enum CodingKeys: String, CodingKey { case mode }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mode = (try? container.decode(String.self, forKey: .mode)) ?? "specific"
        self = mode == "next" ? .next : .specific(cameraName: nil)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .specific: try container.encode("specific", forKey: .mode)
        case .next:     try container.encode("next", forKey: .mode)
        }
    }
}

enum CameraValueMode: Codable, Equatable {
    case absolute(value: String)
    case relative(direction: RelativeDirection, steps: Int)

    private enum CodingKeys: String, CodingKey { case mode, value, direction, steps }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mode = (try? container.decode(String.self, forKey: .mode)) ?? "absolute"
        if mode == "relative" {
            let direction = try container.decode(RelativeDirection.self, forKey: .direction)
            let steps = try container.decode(Int.self, forKey: .steps)
            self = .relative(direction: direction, steps: steps)
        } else {
            let value = (try? container.decode(String.self, forKey: .value)) ?? ""
            self = .absolute(value: value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .absolute(let value):
            try container.encode("absolute", forKey: .mode)
            try container.encode(value, forKey: .value)
        case .relative(let direction, let steps):
            try container.encode("relative", forKey: .mode)
            try container.encode(direction, forKey: .direction)
            try container.encode(steps, forKey: .steps)
        }
    }
}

// MARK: - SequenceStep

/// An individual step in a Cadence sequence.
/// Note: SequenceStep does NOT conform to Identifiable. When used in SwiftUI Lists,
/// wrap in IdentifiableStep (see ContentView) to get a stable UUID per list item.
enum SequenceStep: Codable, Equatable {
    case capture(postCaptureDelay: Int)
    case switchCamera(mode: SwitchCameraMode)
    case setISO(mode: CameraValueMode)
    case setAperture(mode: CameraValueMode)
    case setShutterSpeed(mode: CameraValueMode)
    case autofocus
    case moveFocus(direction: FocusDirection, amount: FocusAmount)
    case wait(seconds: Int)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case type, config }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "capture":
            let config = try container.decode([String: Int].self, forKey: .config)
            self = .capture(postCaptureDelay: config["postCaptureDelay"] ?? 3)
        case "switchCamera":
            // Old format: {} — defaults to .specific(nil) via SwitchCameraMode.init
            // New format: { "mode": "specific" } or { "mode": "next" }
            let mode = (try? container.decode(SwitchCameraMode.self, forKey: .config)) ?? .specific(cameraName: nil)
            self = .switchCamera(mode: mode)
        case "setISO":
            // Old format: { "value": "400" } — defaults to .absolute via CameraValueMode.init
            let mode = (try? container.decode(CameraValueMode.self, forKey: .config)) ?? .absolute(value: "400")
            self = .setISO(mode: mode)
        case "setAperture":
            let mode = (try? container.decode(CameraValueMode.self, forKey: .config)) ?? .absolute(value: "f/5.6")
            self = .setAperture(mode: mode)
        case "setShutterSpeed":
            let mode = (try? container.decode(CameraValueMode.self, forKey: .config)) ?? .absolute(value: "1/125")
            self = .setShutterSpeed(mode: mode)
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
        case .switchCamera(let mode):
            try container.encode("switchCamera", forKey: .type)
            try container.encode(mode, forKey: .config)
        case .setISO(let mode):
            try container.encode("setISO", forKey: .type)
            try container.encode(mode, forKey: .config)
        case .setAperture(let mode):
            try container.encode("setAperture", forKey: .type)
            try container.encode(mode, forKey: .config)
        case .setShutterSpeed(let mode):
            try container.encode("setShutterSpeed", forKey: .type)
            try container.encode(mode, forKey: .config)
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

    var isComplete: Bool {
        switch self {
        case .switchCamera(let mode):
            if case .specific(let name) = mode { return name != nil }
            return true
        case .setISO(let mode), .setAperture(let mode), .setShutterSpeed(let mode):
            if case .absolute(let value) = mode { return !value.isEmpty }
            return true
        default:
            return true
        }
    }

    // MARK: - Display

    var typeName: String {
        switch self {
        case .capture:        return "Capture"
        case .switchCamera:   return "Switch Camera"
        case .setISO:         return "Set ISO"
        case .setAperture:    return "Set Aperture"
        case .setShutterSpeed: return "Set Shutter Speed"
        case .autofocus:      return "Autofocus"
        case .moveFocus:      return "Move Focus"
        case .wait:           return "Wait"
        }
    }

    var configSummary: String {
        switch self {
        case .capture(let delay):
            return "Post-capture delay: \(delay)s"
        case .switchCamera(let mode):
            switch mode {
            case .specific(let name): return name ?? "⚠ No camera selected"
            case .next:               return "Next camera (wraps)"
            }
        case .setISO(let mode):
            switch mode {
            case .absolute(let value): return "ISO \(value)"
            case .relative(let dir, let steps):
                return "ISO \(dir == .up ? "+" : "−")\(steps) step\(steps == 1 ? "" : "s")"
            }
        case .setAperture(let mode):
            switch mode {
            case .absolute(let value): return value
            case .relative(let dir, let steps):
                return "Aperture \(dir == .up ? "+" : "−")\(steps) step\(steps == 1 ? "" : "s")"
            }
        case .setShutterSpeed(let mode):
            switch mode {
            case .absolute(let value): return value
            case .relative(let dir, let steps):
                return "Shutter \(dir == .up ? "+" : "−")\(steps) step\(steps == 1 ? "" : "s")"
            }
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
