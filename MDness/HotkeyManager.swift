import AppKit
import ApplicationServices

/// Global fn+Space hotkey via a CGEvent tap. Capturing (and swallowing) a
/// keystroke system-wide requires Accessibility permission. Call on the main
/// thread only.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    /// Installs the event tap. Returns false when Accessibility permission is
    /// missing; with `promptIfNeeded` the system permission dialog is shown.
    @discardableResult
    func enable(promptIfNeeded: Bool = false) -> Bool {
        guard eventTap == nil else { return true }

        if !AXIsProcessTrusted() {
            if promptIfNeeded {
                let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
                AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
            }
            return false
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, type, event, _ in
                HotkeyManager.handle(type: type, event: event)
            },
            userInfo: nil
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func disable() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private static func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables taps that stall or on secure input; re-enable ours.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = HotkeyManager.shared.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let spaceKeyCode: Int64 = 49
        let otherModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        guard type == .keyDown,
              event.getIntegerValueField(.keyboardEventKeycode) == spaceKeyCode,
              event.flags.contains(.maskSecondaryFn),
              event.flags.isDisjoint(with: otherModifiers) else {
            return Unmanaged.passUnretained(event)
        }

        DispatchQueue.main.async {
            HotkeyManager.shared.summon()
        }
        return nil // Swallow the keystroke so it doesn't reach the frontmost app.
    }

    /// Brings MDness forward; opens a fresh untitled document when no document
    /// window is available to show.
    private func summon() {
        NSApp.activate(ignoringOtherApps: true)
        let hasDocumentWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
        if !hasDocumentWindow {
            NSDocumentController.shared.newDocument(nil)
        }
    }
}
