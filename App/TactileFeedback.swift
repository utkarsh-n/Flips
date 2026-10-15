import UIKit

enum TactileEvent {
    case selection, bitOn, bitOff, step, carry, boundary, scrub, traceTick
    case confirm, success, warning, navigation
}

/// Short system patterns with one physical meaning per event. Reuse the generators
/// so rapid bit flips and scrubbing do not allocate a new feedback object each time.
@MainActor
final class TactileFeedback {
    private lazy var selection = UISelectionFeedbackGenerator()
    private lazy var soft = UIImpactFeedbackGenerator(style: .soft)
    private lazy var rigid = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var light = UIImpactFeedbackGenerator(style: .light)
    private lazy var medium = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavy = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var notification = UINotificationFeedbackGenerator()

    func play(_ event: TactileEvent) {
        switch event {
        case .selection, .scrub:
            selection.selectionChanged()
            selection.prepare()
        case .bitOn:
            rigid.impactOccurred(intensity: 0.55)
            rigid.prepare()
        case .bitOff:
            soft.impactOccurred(intensity: 0.6)
            soft.prepare()
        case .step:
            light.impactOccurred(intensity: 0.45)
            light.prepare()
        case .traceTick:
            light.impactOccurred(intensity: 0.25)
            light.prepare()
        case .carry:
            medium.impactOccurred(intensity: 0.7)
            medium.prepare()
        case .boundary:
            heavy.impactOccurred(intensity: 0.8)
            heavy.prepare()
        case .confirm:
            light.impactOccurred(intensity: 0.75)
            light.prepare()
        case .navigation:
            soft.impactOccurred(intensity: 0.35)
            soft.prepare()
        case .success:
            notification.notificationOccurred(.success)
            notification.prepare()
        case .warning:
            notification.notificationOccurred(.warning)
            notification.prepare()
        }
    }
}
