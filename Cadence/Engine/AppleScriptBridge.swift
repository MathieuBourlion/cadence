import Foundation
import AppKit

// MARK: - Error type

struct AppleScriptError: Error {
    let message: String
    let errorNumber: Int?

    init(errorDictionary: NSDictionary) {
        self.message = errorDictionary[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
        self.errorNumber = errorDictionary[NSAppleScript.errorNumber] as? Int
    }

    init(message: String, errorNumber: Int? = nil) {
        self.message = message
        self.errorNumber = errorNumber
    }
}

// MARK: - Bridge

/// Stateless struct with static methods. One method per command type.
/// All execution is synchronous — call only from a background context (SequenceRunner's Task).
enum AppleScriptBridge {

    // MARK: - Execution primitives

    /// Execute an AppleScript string. Returns success or a wrapped error.
    @discardableResult
    static func execute(_ script: String) -> Result<Void, AppleScriptError> {
        var errorDict: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return .failure(AppleScriptError(message: "Failed to compile AppleScript"))
        }
        appleScript.executeAndReturnError(&errorDict)
        if let errorDict {
            return .failure(AppleScriptError(errorDictionary: errorDict))
        }
        return .success(())
    }

    /// Execute an AppleScript and return the string result.
    static func executeForString(_ script: String) -> Result<String, AppleScriptError> {
        var errorDict: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return .failure(AppleScriptError(message: "Failed to compile AppleScript"))
        }
        let descriptor = appleScript.executeAndReturnError(&errorDict)
        if let errorDict {
            return .failure(AppleScriptError(errorDictionary: errorDict))
        }
        return .success(descriptor.stringValue ?? "")
    }

    /// Execute an AppleScript that returns a list of strings.
    static func executeForList(_ script: String) -> Result<[String], AppleScriptError> {
        var errorDict: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return .failure(AppleScriptError(message: "Failed to compile AppleScript"))
        }
        let descriptor = appleScript.executeAndReturnError(&errorDict)
        if let errorDict {
            return .failure(AppleScriptError(errorDictionary: errorDict))
        }
        let count = descriptor.numberOfItems
        guard count > 0 else { return .success([]) }
        var items: [String] = []
        for i in 1...count {
            if let item = descriptor.atIndex(i)?.stringValue {
                items.append(item)
            }
        }
        return .success(items)
    }

    // MARK: - Ping

    /// Returns success if Capture One is running, error otherwise.
    static func ping() -> Result<Void, AppleScriptError> {
        executeForString(#"application "Capture One" is running"#)
            .flatMap { value in
                value == "true" ? .success(()) : .failure(AppleScriptError(message: "Capture One is not running"))
            }
    }

    // MARK: - Camera list

    static func fetchCameraList() -> Result<[String], AppleScriptError> {
        executeForList(#"available camera identifiers of front document of application "Capture One""#)
    }

    // MARK: - Current value reads (for relative mode)

    static func fetchCurrentCamera() -> Result<String, AppleScriptError> {
        executeForString(#"name of camera of front document of application "Capture One""#)
    }

    static func fetchCurrentISO() -> Result<String, AppleScriptError> {
        executeForString(#"ISO of camera of front document of application "Capture One""#)
    }

    static func fetchCurrentAperture() -> Result<String, AppleScriptError> {
        executeForString(#"aperture of camera of front document of application "Capture One""#)
    }

    static func fetchCurrentShutterSpeed() -> Result<String, AppleScriptError> {
        executeForString(#"shutter speed of camera of front document of application "Capture One""#)
    }

    // MARK: - Step scripts

    /// Build and execute the AppleScript for a given step.
    /// Returns success or a wrapped error.
    @discardableResult
    static func execute(step: SequenceStep) -> Result<Void, AppleScriptError> {
        guard let script = scriptForStep(step) else {
            // Steps with no AppleScript (Wait) are handled by SequenceRunner directly
            return .success(())
        }
        return execute(script)
    }

    /// Returns the AppleScript string for the given step, or nil for steps that have no script.
    static func scriptForStep(_ step: SequenceStep) -> String? {
        switch step {
        case .capture:
            return #"tell application "Capture One" to capture"#

        case .switchCamera(let mode):
            switch mode {
            case .specific(let name):
                guard let name else { return nil }
                let escaped = name.replacingOccurrences(of: "\"", with: "\\\"")
                return #"tell application "Capture One" to select camera of front document name "\#(escaped)""#
            case .next:
                return nil  // Handled by SequenceRunner.executeNextCamera()
            }

        case .setISO(let mode):
            guard case .absolute(let value) = mode else { return nil }
            return #"tell application "Capture One" to set ISO of camera of front document to "\#(value)""#

        case .setAperture(let mode):
            guard case .absolute(let value) = mode else { return nil }
            return #"tell application "Capture One" to set aperture of camera of front document to "\#(value)""#

        case .setShutterSpeed(let mode):
            guard case .absolute(let value) = mode else { return nil }
            let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
            return #"tell application "Capture One" to set shutter speed of camera of front document to "\#(escaped)""#

        case .autofocus:
            return #"tell application "Capture One" to set autofocusing of camera of front document to true"#

        case .moveFocus(let direction, let amount):
            let n = moveFocusAmount(direction: direction, amount: amount)
            return #"tell application "Capture One" to adjust focus of camera of front document by amount \#(n) sync true"#

        case .wait:
            return nil  // Wait uses Task.sleep in SequenceRunner, not AppleScript
        }
    }

    // MARK: - Read-back scripts

    /// Returns the AppleScript to read back the current value of a setting after setting it.
    /// Returns nil for steps that don't have a read-back check.
    static func readBackScript(for step: SequenceStep) -> String? {
        switch step {
        case .setISO(let mode):
            guard case .absolute = mode else { return nil }  // relative handles its own read-back
            return #"ISO of camera of front document of application "Capture One""#
        case .setAperture(let mode):
            guard case .absolute = mode else { return nil }
            return #"aperture of camera of front document of application "Capture One""#
        case .setShutterSpeed(let mode):
            guard case .absolute = mode else { return nil }
            return #"shutter speed of camera of front document of application "Capture One""#
        default:
            return nil
        }
    }

    // MARK: - Helpers

    static func moveFocusAmount(direction: FocusDirection, amount: FocusAmount) -> Int {
        switch (direction, amount) {
        case (.nearer, .small):  return -1
        case (.nearer, .medium): return -3
        case (.nearer, .large):  return -7
        case (.further, .small): return 1
        case (.further, .medium): return 3
        case (.further, .large): return 7
        }
    }
}
