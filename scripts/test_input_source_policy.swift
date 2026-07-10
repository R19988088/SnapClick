import AppKit
import Foundation

@main
struct InputSourcePolicyTest {
    static func main() {
        assert(
            InputSourcePolicy.activationAction(
                preferredID: "preferred",
                currentID: "other",
                isException: false
            ) == .select("preferred")
        )
        assert(
            InputSourcePolicy.activationAction(
                preferredID: "preferred",
                currentID: "other",
                isException: true
            ) == .ignore
        )
        assert(
            InputSourcePolicy.sourceChangeAction(
                preferredID: "preferred",
                currentID: "manual",
                isException: false,
                retainUserSelection: true,
                hasManualSwitchIntent: true,
                isProgrammatic: false
            ) == .adopt("manual")
        )
        assert(
            InputSourcePolicy.sourceChangeAction(
                preferredID: "preferred",
                currentID: "manual",
                isException: false,
                retainUserSelection: false,
                hasManualSwitchIntent: true,
                isProgrammatic: false
            ) == .select("preferred")
        )
        assert(
            InputSourcePolicy.sourceChangeAction(
                preferredID: "preferred",
                currentID: "system",
                isException: false,
                retainUserSelection: true,
                hasManualSwitchIntent: false,
                isProgrammatic: false
            ) == .select("preferred")
        )
        assert(
            InputSourcePolicy.sourceChangeAction(
                preferredID: "preferred",
                currentID: "manual",
                isException: true,
                retainUserSelection: true,
                hasManualSwitchIntent: true,
                isProgrammatic: false
            ) == .ignore
        )
        assert(
            InputSourcePolicy.sourceChangeAction(
                preferredID: "preferred",
                currentID: "preferred",
                isException: false,
                retainUserSelection: false,
                hasManualSwitchIntent: false,
                isProgrammatic: true
            ) == .ignore
        )

        let controlSpace = InputSourceHotkey(keyCode: 49, modifiers: 262_144)
        assert(
            InputSourceIntentDetector.matchesKeyboardSwitch(
                keyCode: 49,
                modifiers: 262_144,
                configuredHotkeys: [controlSpace]
            )
        )
        assert(
            !InputSourceIntentDetector.matchesKeyboardSwitch(
                keyCode: 48,
                modifiers: 1_048_576,
                configuredHotkeys: [controlSpace]
            )
        )
        assert(
            !InputSourceIntentDetector.matchesKeyboardSwitch(
                keyCode: 57,
                modifiers: 0,
                configuredHotkeys: []
            )
        )
        assert(
            InputSourceIntentDetector.matchesKeyboardSwitch(
                keyCode: 57,
                modifiers: 0,
                configuredHotkeys: [InputSourceHotkey(keyCode: 57, modifiers: 0)]
            )
        )
        assert(
            !InputSourceIntentDetector.matchesKeyboardSwitch(
                keyCode: 0,
                modifiers: 0,
                configuredHotkeys: []
            )
        )

        let mouseDown = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )!
        assert(
            !InputSourceIntentDetector.matchesKeyboardSwitch(
                event: mouseDown,
                configuredHotkeys: []
            )
        )
        assert(
            InputSourcePolicy.replacementPreferredID(
                preferredID: "missing",
                availableIDs: ["fallback", "exception-current"],
                isException: true
            ) == nil
        )
        assert(
            InputSourcePolicy.replacementPreferredID(
                preferredID: "missing",
                availableIDs: ["fallback", "current"],
                isException: false
            ) == "fallback"
        )

        print("InputSourcePolicy tests passed")
    }
}
