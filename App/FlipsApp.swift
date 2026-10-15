import SwiftUI
import UIKit
import RadixCore

@main
struct FlipsApp: App {
    init() { StartupTrace.mark("App initialized") }

    var body: some Scene {
        WindowGroup { FlipsRootView().preferredColorScheme(.dark) }
    }
}

@MainActor
@Observable
final class Playground {
    let preferences: UserDefaults
    var number: RadixNumber {
        didSet { preferences.set(number.value, forKey: "radix.number") }
    }
    var note = "Every switch is worth twice the one to its right. Turn it on to add its weight."
    var running = false
    var changedBits: [Int] = []
    var playback: ArithmeticPlayback?
    private(set) var slowMotionSpeed: Double
    var slowMotionEnabled: Bool {
        didSet {
            preferences.set(slowMotionEnabled, forKey: "radix.slowMotion")
            stop()
        }
    }
    @ObservationIgnored private let tactile = TactileFeedback()
    @ObservationIgnored private var lastScrubTime = 0.0
    @ObservationIgnored private var arithmeticTask: Task<Void, Never>?
    @ObservationIgnored private var arithmeticGeneration = 0
    var hapticsEnabled: Bool {
        didSet { preferences.set(hapticsEnabled, forKey: "radix.haptics") }
    }

    init() {
        StartupTrace.mark("Playground initialization started")
        let isTesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        preferences = isTesting ? UserDefaults(suiteName: "com.utkarsh.flips.ui-tests")! : .standard
        if isTesting {
            preferences.removePersistentDomain(forName: "com.utkarsh.flips.ui-tests")
            number = RadixNumber(42)
            hapticsEnabled = false
            slowMotionEnabled = false
            slowMotionSpeed = 1
        } else {
            number = RadixNumber(preferences.object(forKey: "radix.number") as? Int ?? 42)
            hapticsEnabled = preferences.object(forKey: "radix.haptics") as? Bool ?? true
            slowMotionEnabled = preferences.object(forKey: "radix.slowMotion") as? Bool ?? false
            let savedSpeed = preferences.object(forKey: "radix.slowMotionSpeed") as? Double ?? 1
            slowMotionSpeed = Self.normalizedSpeed(savedSpeed)
        }
        StartupTrace.mark("Playground initialized")
    }

    func set(_ value: Int, feedback event: TactileEvent? = .confirm) {
        stop()
        change(to: RadixNumber(value))
        note = number.value == 0 ? "No switches are on. Zero looks like 0 in every base." : "Same amount, different digits. \(number.decimal) in decimal is \(number.hexadecimal) in hex."
        if let event { feedback(event) }
    }

    func toggle(_ index: Int) {
        stop()
        let weight = 1 << index
        let wasOn = (number.value & weight) != 0
        change(to: number.togglingBit(index: index))
        note = "\(wasOn ? "Removed" : "Added") \(weight). The lit switches now add up to \(number.value)."
        feedback(wasOn ? .bitOff : .bitOn)
    }

    var displayedNumber: RadixNumber { playback?.workingNumber ?? number }
    var hasArithmeticPlayback: Bool { playback.map { !$0.isComplete } ?? false }
    var arithmeticStepSeconds: Double { 0.6 / slowMotionSpeed }

    func setSlowMotionSpeed(_ speed: Double) {
        let next = Self.normalizedSpeed(speed)
        guard next != slowMotionSpeed else { return }
        slowMotionSpeed = next
        preferences.set(next, forKey: "radix.slowMotionSpeed")
        if hasArithmeticPlayback, playback?.isPaused == false {
            scheduleArithmetic()
        }
    }

    private static func normalizedSpeed(_ speed: Double) -> Double {
        speed.isFinite ? min(3, max(0.25, speed)) : 1
    }

    func playArithmeticExample(_ operation: RadixStepOperation, startingAt value: Int? = nil) {
        stop()
        if !slowMotionEnabled { slowMotionEnabled = true }
        change(to: RadixNumber(value ?? (operation == .increment ? 15 : 16)))
        beginArithmetic(operation)
    }

    func increment(animated: Bool = true) {
        guard !hasArithmeticPlayback else { return }
        if animated && slowMotionEnabled {
            beginArithmetic(.increment)
            return
        }
        playback = nil
        let transition = number.incrementTransition
        change(to: transition.after)
        note = transition.explanation
        if !running {
            feedback(transition.isOverflow ? .boundary : changedBits.count > 1 ? .carry : .step)
        }
    }

    func decrement(animated: Bool = true) {
        guard !hasArithmeticPlayback else { return }
        if animated && slowMotionEnabled {
            beginArithmetic(.decrement)
            return
        }
        playback = nil
        let wasZero = number.value == 0
        change(to: number.decremented)
        note = wasZero ? "This is an 8-bit counter: stepping below 0 wraps around to 255." : "Subtracted 1. Watch the lower bits borrow when a switch is off."
        feedback(wasZero ? .boundary : changedBits.count > 1 ? .carry : .step)
    }

    func stop() {
        running = false
        clearArithmetic()
    }

    func toggleCounting() {
        if running {
            if hasArithmeticPlayback {
                pauseArithmetic()
            } else {
                running = false
                feedback(.confirm)
            }
            return
        }
        guard !hasArithmeticPlayback else { return }
        running = true
        feedback(.confirm)
    }

    func pauseArithmetic() {
        guard hasArithmeticPlayback, playback?.isPaused == false else { return }
        running = false
        invalidateArithmeticTask()
        playback?.isPaused = true
        feedback(.selection)
    }

    func resumeArithmetic() {
        guard hasArithmeticPlayback, playback?.isPaused == true else { return }
        playback?.isPaused = false
        feedback(.selection)
        scheduleArithmetic()
    }

    func stepArithmetic() {
        guard hasArithmeticPlayback else { return }
        running = false
        invalidateArithmeticTask()
        playback?.isPaused = true
        advanceArithmetic()
    }

    func cancelArithmetic() {
        running = false
        let wasActive = hasArithmeticPlayback
        clearArithmetic()
        if wasActive { feedback(.selection) }
    }

    private func beginArithmetic(_ operation: RadixStepOperation) {
        invalidateArithmeticTask()
        playback = ArithmeticPlayback(trace: number.arithmeticTrace(operation))
        note = "Follow the working bits one place at a time. The final number is saved when the carry or borrow finishes."
        scheduleArithmetic()
    }

    private func scheduleArithmetic() {
        invalidateArithmeticTask()
        let generation = arithmeticGeneration
        arithmeticTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let delay = self?.arithmeticStepSeconds else { return }
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self, self.arithmeticGeneration == generation,
                      self.hasArithmeticPlayback, self.playback?.isPaused == false else { return }
                self.advanceArithmetic()
                if !self.hasArithmeticPlayback { return }
            }
        }
    }

    private func advanceArithmetic() {
        guard var state = playback, !state.isComplete else { return }
        let step = state.trace.steps[state.completedSteps]
        state.completedSteps += 1
        if state.isComplete {
            state.isPaused = false
            change(to: state.trace.after)
            note = state.trace.explanation
            invalidateArithmeticTask()
        } else {
            note = step.explanation
        }
        playback = state
        feedback(step.isBoundary ? .boundary : .traceTick)
    }

    private func clearArithmetic() {
        let wasActive = hasArithmeticPlayback
        invalidateArithmeticTask()
        playback = nil
        if wasActive {
            note = "Stopped the slow-motion step. The number is still \(number.value); the unfinished carry or borrow was not applied."
        }
    }

    private func invalidateArithmeticTask() {
        arithmeticGeneration += 1
        arithmeticTask?.cancel()
        arithmeticTask = nil
    }

    func scrub(to value: Int) {
        let before = number.value
        let next = RadixNumber(value).value
        guard before != next else { return }
        set(next, feedback: nil)
        scrubFeedback(from: before, to: next)
    }

    func scrubFeedback(from old: Int, to new: Int) {
        guard hapticsEnabled, old != new else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let isBoundary = new == 0 || new == 255
        guard isBoundary || now - lastScrubTime >= 0.08 else { return }
        lastScrubTime = now
        feedback(isBoundary ? .boundary : .scrub)
    }

    func change(to next: RadixNumber) {
        changedBits = (0..<8).filter { ((number.value ^ next.value) & (1 << $0)) != 0 }
        number = next
    }

    func feedback(_ event: TactileEvent = .selection) {
        guard hapticsEnabled else { return }
        tactile.play(event)
    }
}

struct ArithmeticPlayback {
    let id = UUID()
    let trace: RadixArithmeticTrace
    var completedSteps = 0
    var isPaused = false

    var isComplete: Bool { completedSteps == trace.steps.count }
    var currentStep: RadixArithmeticStep? {
        completedSteps > 0 ? trace.steps[completedSteps - 1] : nil
    }
    var workingNumber: RadixNumber { currentStep?.after ?? trace.before }
}

struct FlipsRootView: View {
    @State private var playground = Playground()
    @State private var tab = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            Tab("Bits", systemImage: "switch.2", value: 0) {
                BitsView(playground: playground)
            }
            Tab("Bases", systemImage: "square.stack.3d.up", value: 1) {
                BasesView(playground: playground)
            }
            Tab("Discover", systemImage: "sparkles", value: 2) {
                DiscoverView(playground: playground, onExplore: { tab = 0 })
            }
        }
        .tint(Palette.mint)
        .defaultAppStorage(playground.preferences)
        .onAppear { StartupTrace.mark("Root appeared") }
        .onChange(of: tab) { _, _ in playground.stop() }
        .onChange(of: scenePhase) { _, phase in
            StartupTrace.mark("Scene \(String(describing: phase))")
            if phase != .active { playground.stop() }
        }
    }
}

private enum StartupTrace {
    static func mark(_ message: String) {
        guard ProcessInfo.processInfo.arguments.contains("--diagnose-startup") else { return }
        FileHandle.standardError.write(Data("Flips startup: \(message)\n".utf8))
    }
}
