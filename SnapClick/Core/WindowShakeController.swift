import AppKit
import ApplicationServices
import CoreGraphics

final class WindowShakeController {
    private struct MouseDownState {
        let point: CGPoint
        let timestamp: TimeInterval
    }

    private struct RestoreEntry {
        let windowID: CGWindowID
        let element: AXUIElement
        let frame: CGRect
        let frontToBackRank: Int
    }

    private struct RestoreSession {
        let keptWindowID: CGWindowID
        let keptWindow: AXUIElement
        let entries: [RestoreEntry]
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private var mouseDownState: MouseDownState?
    private var draggedWindow: AXUIElement?
    private var draggedWindowID: CGWindowID?
    private var recognizer = WindowShakeRecognizer()
    private var restoreSession: RestoreSession?
    private var elevatedWindow: (windowID: CGWindowID, element: AXUIElement, originalLevel: Int32)?

    func start() {
        guard eventTap == nil else { return }
        guard PermissionManager.shared.checkAccessibilityPermission() else {
            PermissionManager.shared.requestAccessibilityPermission()
            startRetryingAfterPermissionGrant()
            return
        }
        guard InputMonitoringPermission.isGranted else {
            InputMonitoringPermission.request()
            startRetryingAfterPermissionGrant()
            return
        }
        stopRetrying()

        let eventMask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<WindowShakeController>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            } else {
                controller.handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            InputMonitoringPermission.request()
            startRetryingAfterPermissionGrant()
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    func stop() {
        stopRetrying()
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        releaseElevatedWindow()
        clearGesture()
    }

    private func startRetryingAfterPermissionGrant() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if PermissionManager.shared.checkAccessibilityPermission(), InputMonitoringPermission.isGranted {
                timer.invalidate()
                self.retryTimer = nil
                self.start()
            }
        }
    }

    private func stopRetrying() {
        retryTimer?.invalidate()
        retryTimer = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        let timestamp = TimeInterval(event.timestamp) / 1_000_000_000
        switch type {
        case .leftMouseDown:
            releaseElevatedWindow()
            mouseDownState = MouseDownState(point: event.location, timestamp: timestamp)
            draggedWindow = nil
            draggedWindowID = nil
            recognizer = WindowShakeRecognizer()
        case .leftMouseDragged:
            handleMouseDragged(point: event.location, timestamp: timestamp)
        case .leftMouseUp:
            releaseElevatedWindow()
            clearGesture()
        default:
            break
        }
    }

    private func handleMouseDragged(point: CGPoint, timestamp: TimeInterval) {
        guard let mouseDownState else { return }

        if draggedWindow == nil {
            guard hypot(point.x - mouseDownState.point.x, point.y - mouseDownState.point.y) >= 4 else { return }
            guard let window = standardWindow(at: point),
                  let windowID = windowID(for: window),
                  titleBarBounds(for: window)?.contains(point) == true else {
                clearGesture()
                return
            }
            draggedWindow = window
            draggedWindowID = windowID
            recognizer.begin(at: mouseDownState.point, timestamp: mouseDownState.timestamp)
        }

        guard let draggedWindow, let draggedWindowID else { return }
        if recognizer.update(to: point, timestamp: timestamp) {
            performShake(keptWindow: draggedWindow, keptWindowID: draggedWindowID)
        }
    }

    private func clearGesture() {
        mouseDownState = nil
        draggedWindow = nil
        draggedWindowID = nil
        recognizer = WindowShakeRecognizer()
    }

    private func performShake(keptWindow: AXUIElement, keptWindowID: CGWindowID) {
        if let restoreSession {
            guard restoreSession.keptWindowID == keptWindowID else { return }
            self.restoreSession = nil
            restore(restoreSession)
            return
        }

        let entries = visibleRestorableWindows(excluding: keptWindowID)
        holdDraggedWindowAboveAnimations(keptWindow, windowID: keptWindowID)
        let minimizedEntries = setMinimizedConcurrently(entries, minimized: true)
        guard !minimizedEntries.isEmpty else { return }
        restoreSession = RestoreSession(
            keptWindowID: keptWindowID,
            keptWindow: keptWindow,
            entries: minimizedEntries
        )
        if CGSOrderWindow(CGSMainConnectionID(), keptWindowID, 1, 0) != 0 {
            AXUIElementPerformAction(keptWindow, kAXRaiseAction as CFString)
        }
    }

    private func restore(_ session: RestoreSession) {
        let liveEntries = session.entries.filter { windowID(for: $0.element) == $0.windowID }
        let orderedEntries = liveEntries.sorted(by: { $0.frontToBackRank > $1.frontToBackRank })
        holdDraggedWindowAboveAnimations(session.keptWindow, windowID: session.keptWindowID)
        _ = setMinimizedConcurrently(liveEntries, minimized: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self,
                  self.windowID(for: session.keptWindow) == session.keptWindowID else { return }
            let connection = CGSMainConnectionID()
            for entry in orderedEntries {
                guard self.windowID(for: entry.element) == entry.windowID else { continue }
                self.restoreFrame(entry.frame, to: entry.element)
                if CGSOrderWindow(connection, entry.windowID, -1, session.keptWindowID) != 0 {
                    AXUIElementPerformAction(entry.element, kAXRaiseAction as CFString)
                }
            }
            if CGSOrderWindow(connection, session.keptWindowID, 1, 0) != 0 {
                AXUIElementPerformAction(session.keptWindow, kAXRaiseAction as CFString)
            }
        }
    }

    private func setMinimizedConcurrently(_ entries: [RestoreEntry], minimized: Bool) -> [RestoreEntry] {
        guard !entries.isEmpty else { return [] }
        let value = minimized ? kCFBooleanTrue! : kCFBooleanFalse!
        let lock = NSLock()
        var succeeded: [(index: Int, entry: RestoreEntry)] = []
        succeeded.reserveCapacity(entries.count)

        DispatchQueue.concurrentPerform(iterations: entries.count) { index in
            let entry = entries[index]
            guard AXUIElementSetAttributeValue(
                entry.element,
                kAXMinimizedAttribute as CFString,
                value
            ) == .success else { return }
            lock.lock()
            succeeded.append((index, entry))
            lock.unlock()
        }
        return succeeded.sorted(by: { $0.index < $1.index }).map(\.entry)
    }

    private func holdDraggedWindowAboveAnimations(_ window: AXUIElement, windowID: CGWindowID) {
        releaseElevatedWindow()
        guard self.windowID(for: window) == windowID else { return }

        let connection = CGSMainConnectionID()
        var originalLevel: Int32 = 0
        guard CGSGetWindowLevel(connection, windowID, &originalLevel) == 0 else { return }
        let elevatedLevel = max(originalLevel + 1, CGWindowLevelForKey(.assistiveTechHighWindow))
        guard CGSSetWindowLevel(connection, windowID, elevatedLevel) == 0 else { return }

        elevatedWindow = (windowID, window, originalLevel)
    }

    private func releaseElevatedWindow() {
        guard let state = elevatedWindow else { return }
        elevatedWindow = nil

        let connection = CGSMainConnectionID()
        CGSSetWindowLevel(connection, state.windowID, state.originalLevel)
        guard windowID(for: state.element) == state.windowID else { return }
        if CGSOrderWindow(connection, state.windowID, 1, 0) != 0 {
            AXUIElementPerformAction(state.element, kAXRaiseAction as CFString)
        }
    }

    private func visibleRestorableWindows(excluding keptWindowID: CGWindowID) -> [RestoreEntry] {
        guard let windowInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var windowsByPID: [pid_t: [CGWindowID: AXUIElement]] = [:]
        var entries: [RestoreEntry] = []
        for (rank, item) in windowInfo.enumerated() {
            guard (item[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  (item[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true,
                  (item[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0 > 0,
                  let windowID = (item[kCGWindowNumber as String] as? NSNumber).map({ CGWindowID(truncating: $0) }),
                  windowID != keptWindowID,
                  let pid = (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value else { continue }

            let windows = windowsByPID[pid] ?? accessibilityWindows(for: pid)
            windowsByPID[pid] = windows
            guard let element = windows[windowID],
                  isStandardWindow(element),
                  !isMinimized(element),
                  isMinimizedAttributeSettable(element),
                  let frame = axBounds(element) else { continue }
            entries.append(RestoreEntry(windowID: windowID, element: element, frame: frame, frontToBackRank: rank))
        }
        return entries
    }

    private func accessibilityWindows(for pid: pid_t) -> [CGWindowID: AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [:] }
        var result: [CGWindowID: AXUIElement] = [:]
        for window in windows {
            if let id = windowID(for: window) {
                result[id] = window
            }
        }
        return result
    }

    private func standardWindow(at point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var hitElement: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hitElement) == .success,
              var element = hitElement else { return nil }

        for _ in 0..<12 {
            if role(of: element) == kAXWindowRole as String {
                return isStandardWindow(element) ? element : nil
            }
            guard let parent = elementAttribute(element, kAXParentAttribute as CFString) else { return nil }
            element = parent
        }
        return nil
    }

    private func isStandardWindow(_ window: AXUIElement) -> Bool {
        role(of: window) == kAXWindowRole as String
            && stringAttribute(window, kAXSubroleAttribute as CFString) == kAXStandardWindowSubrole as String
    }

    private func titleBarBounds(for window: AXUIElement) -> CGRect? {
        guard let windowFrame = axBounds(window) else { return nil }
        var bottom = windowFrame.minY + 28
        let attributes = [
            kAXCloseButtonAttribute,
            kAXMinimizeButtonAttribute,
            kAXZoomButtonAttribute,
            kAXTitleUIElementAttribute
        ]
        for attribute in attributes {
            if let value = elementAttribute(window, attribute as CFString),
               let bounds = axBounds(value) {
                bottom = max(bottom, bounds.maxY + 8)
            }
        }
        let height = min(max(bottom - windowFrame.minY, 28), 56)
        return CGRect(x: windowFrame.minX, y: windowFrame.minY, width: windowFrame.width, height: height)
    }

    private func role(of element: AXUIElement) -> String? {
        stringAttribute(element, kAXRoleAttribute as CFString)
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func isMinimized(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) ?? false
    }

    private func isMinimizedAttributeSettable(_ window: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(window, kAXMinimizedAttribute as CFString, &settable) == .success
            && settable.boolValue
    }

    private func windowID(for window: AXUIElement) -> CGWindowID? {
        var windowID = CGWindowID.zero
        return _AXUIElementGetWindow(window, &windowID) == .success && windowID != 0 ? windowID : nil
    }

    private func axBounds(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    private func restoreFrame(_ frame: CGRect, to window: AXUIElement) {
        guard let current = axBounds(window),
              abs(current.minX - frame.minX) > 1
                || abs(current.minY - frame.minY) > 1
                || abs(current.width - frame.width) > 1
                || abs(current.height - frame.height) > 1 else { return }
        var origin = frame.origin
        var size = frame.size
        if let position = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        }
        if let dimensions = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
        }
    }
}
