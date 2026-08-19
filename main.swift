import Cocoa
import CoreGraphics
import ApplicationServices

let textInputRoles: Set<String> = [
    kAXTextFieldRole as String,
    kAXTextAreaRole as String,
    kAXComboBoxRole as String,
    "AXSearchField",
    "AXSecureTextField",
]

// ---- self-managed rotating log -------------------------------------
let logDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("finder-typeban", isDirectory: true)
let logPath = logDir.appendingPathComponent("guard.log").path
let maxLogBytes = 1_000_000

func logLine(_ s: String) {
    let line = s + "\n"
    guard let data = line.data(using: .utf8) else { return }
    do {
        try FileManager.default.createDirectory(atPath: logDir.path,
                                                withIntermediateDirectories: true)
        if let fh = FileHandle(forWritingAtPath: logPath) {
            defer { try? fh.close() }
            fh.seekToEndOfFile()
            fh.write(data)
            let size = (try? FileManager.default.attributesOfItem(atPath: logPath))?[.size] as? Int ?? 0
            if size > maxLogBytes {
                let rotated = logPath + ".1"
                try? FileManager.default.removeItem(atPath: rotated)
                try? FileManager.default.moveItem(atPath: logPath, toPath: rotated)
            }
        } else {
            try data.write(to: URL(fileURLWithPath: logPath))
        }
    } catch {
        // ignore logging errors; never let logging break the guard
    }
}

// ---- decision logic --------------------------------------------------
func countSelection(_ el: AXUIElement) -> Int? {
    var v: CFTypeRef?
    if AXUIElementCopyAttributeValue(el, kAXSelectedChildrenAttribute as CFString, &v) == .success,
       let arr = v as? [AXUIElement] { return arr.count }
    if AXUIElementCopyAttributeValue(el, kAXSelectedRowsAttribute as CFString, &v) == .success,
       let arr = v as? [AXUIElement] { return arr.count }
    return nil
}

// Overlay processes whose text fields receive keyboard input while Finder
// stays the frontmost app. Extend this list if another overlay is affected.
let overlayBundleIDs: [String] = [
    "com.apple.Spotlight",
    "com.apple.Siri",
]

func overlayTextFieldFocused() -> Bool {
    for bundleID in overlayBundleIDs {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
            continue
        }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(ax, 0.15)
        var f: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ax, kAXFocusedUIElementAttribute as CFString, &f) == .success,
              CFGetTypeID(f) == AXUIElementGetTypeID() else {
            continue
        }
        let fe = f as! AXUIElement
        var roleV: CFTypeRef?
        guard AXUIElementCopyAttributeValue(fe, kAXRoleAttribute as CFString, &roleV) == .success,
              let role = roleV as? String else {
            continue
        }
        if textInputRoles.contains(role) {
            return true
        }
    }
    return false
}

func shouldAllowTyping(inFinder pid: pid_t) -> Bool {
    if overlayTextFieldFocused() {
        return true
    }

    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.15)

    var f: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &f) == .success,
          CFGetTypeID(f) == AXUIElementGetTypeID() else {
        return true
    }
    let focused = f as! AXUIElement

    var roleV: CFTypeRef?
    if AXUIElementCopyAttributeValue(focused, kAXRoleAttribute as CFString, &roleV) == .success,
       let role = roleV as? String, textInputRoles.contains(role) {
        return true
    }

    if let n = countSelection(focused) {
        return n > 0
    }

    var winV: CFTypeRef?
    if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &winV) == .success,
       CFGetTypeID(winV) == AXUIElementGetTypeID() {
        let win = winV as! AXUIElement
        if let n = countSelection(win) {
            return n > 0
        }
    }

    return true
}

func isPrintableCharacterKey(_ event: CGEvent) -> Bool {
    let flags = event.flags
    if flags.contains(.maskCommand) || flags.contains(.maskControl)
        || flags.contains(.maskAlternate) || flags.contains(.maskSecondaryFn) {
        return false
    }
    let kc = Int(event.getIntegerValueField(.keyboardEventKeycode))
    let printable: ClosedRange<Int> = 0...47
    if printable.contains(kc) && kc != 36 && kc != 48 && kc != 49 {
        return true
    }
    return false
}

// ---- cached decision (avoids NSWorkspace/AX work on every key) -------
var cacheTime: TimeInterval = 0
var cachedIsFinder = false
var cachedAllow = true

func cachedDecision() -> (isFinder: Bool, allow: Bool) {
    let now = Date().timeIntervalSinceReferenceDate
    if now - cacheTime < 0.08 {
        return (cachedIsFinder, cachedAllow)
    }
    cacheTime = now

    guard let front = NSWorkspace.shared.frontmostApplication,
          front.bundleIdentifier == "com.apple.finder" else {
        cachedIsFinder = false
        cachedAllow = true
        return (false, true)
    }
    cachedIsFinder = true
    cachedAllow = shouldAllowTyping(inFinder: front.processIdentifier)
    return (cachedIsFinder, cachedAllow)
}

// ---- event tap -------------------------------------------------------
let callback: CGEventTapCallBack = { _, type, event, _ in
    guard type == .keyDown else {
        if type == .leftMouseDown || type == .rightMouseDown {
            cacheTime = 0   // a click may change selection/focus; recompute next key
        }
        return Unmanaged.passUnretained(event)
    }
    guard isPrintableCharacterKey(event) else { return Unmanaged.passUnretained(event) }
    let (isFinder, allow) = cachedDecision()
    if !isFinder || allow {
        return Unmanaged.passUnretained(event)
    }
    let kc = event.getIntegerValueField(.keyboardEventKeycode)
    logLine("BLOCK kc=\(kc)")
    return nil
}

// Invalidate the cached decision as soon as the frontmost app changes
// (prevents swallowing keystrokes right after switching apps).
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification,
    object: nil,
    queue: .main
) { _ in
    cacheTime = 0
}

let mask = CGEventMask(
    (1 << CGEventType.keyDown.rawValue)
    | (1 << CGEventType.leftMouseDown.rawValue)
    | (1 << CGEventType.rightMouseDown.rawValue)
)

while true {
    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: callback,
        userInfo: nil
    ) else {
        let listen = CGPreflightListenEventAccess()
        let trusted = AXIsProcessTrusted()
        logLine("ERROR: cannot create event tap. listen=\(listen) axTrusted=\(trusted). Retrying in 3s...")
        sleep(3)
        continue
    }

    // watchdog: re-enable the tap if the system ever disables it
    let timer = Timer(timeInterval: 2.0, repeats: true) { _ in
        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
            logLine("re-enabled tap after system disable")
        }
    }
    RunLoop.main.add(timer, forMode: .common)

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    logLine("finder-typeban running (tap OK).")
    CFRunLoopRun()
}
