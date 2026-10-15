import SwiftUI
import RadixCore

struct ArithmeticPlaybackView: View {
    @Bindable var playground: Playground
    let playback: ArithmeticPlayback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var incrementing: Bool {
        playback.trace.operation == .increment
    }

    private var accent: Color {
        incrementing ? Palette.amber : Palette.lilac
    }

    private var pendingWeight: Int? {
        if playback.isComplete { return nil }
        return playback.currentStep?.pendingWeight ?? (playback.completedSteps == 0 ? 1 : nil)
    }

    private var pendingDescription: String {
        if let pendingWeight {
            return incrementing ? "Carry +\(pendingWeight)" : "Borrow debt −\(pendingWeight)"
        }
        return playback.trace.isWrap ? "8-bit wrap complete" : "Result settled"
    }

    private var explanation: String {
        if playback.isComplete { return playback.trace.explanation }
        return playback.currentStep?.explanation
            ?? "Start at the 1 place on the right. Each step changes one bit, then passes any carry or borrow debt to the next place."
    }

    var body: some View {
        LabCard(accent: accent) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(playback.trace.before.value) \(incrementing ? "+" : "−") 1 → \(playback.trace.after.value)")
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .accessibilityIdentifier("arithmeticEquation")
                    Spacer(minLength: 0)
                    Text("\(playback.completedSteps) / \(playback.trace.steps.count)")
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                        .accessibilityValue("\(playback.completedSteps) of \(playback.trace.steps.count) steps completed")
                        .accessibilityIdentifier("arithmeticProgress")
                }

                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    workingReadout("WORKING BITS", value: playback.workingNumber.binary,
                                   color: Palette.mint, identifier: "arithmeticWorkingBinary")
                    Spacer(minLength: 0)
                    workingReadout("DEC", value: "\(playback.workingNumber.value)",
                                   color: Palette.lilac, identifier: "arithmeticWorkingValue")
                    workingReadout("HEX", value: playback.workingNumber.hexadecimal,
                                   color: Palette.amber, identifier: "arithmeticWorkingHex")
                }

                HStack(spacing: 8) {
                    Label(pendingDescription, systemImage: pendingWeight == nil ? "checkmark.circle" : "arrow.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                        .accessibilityIdentifier("arithmeticPending")
                    Spacer(minLength: 0)
                    Text(playback.isComplete ? "Complete" : playback.isPaused ? "Paused" : "Playing")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }

                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("arithmeticExplanation")

                ProgressView(value: Double(playback.completedSteps), total: Double(max(1, playback.trace.steps.count)))
                    .tint(accent)
                    .accessibilityHidden(true)

                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(playback.isPaused ? "Resume" : "Pause") {
                            if playback.isPaused {
                                playground.resumeArithmetic()
                            } else {
                                playground.pauseArithmetic()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(playback.isComplete)
                        .accessibilityIdentifier("arithmeticPauseToggle")

                        Button("Next step") { playground.stepArithmetic() }
                            .frame(maxWidth: .infinity)
                            .disabled(playback.isComplete)
                            .accessibilityIdentifier("arithmeticNextBit")

                        Button("Stop") { playground.cancelArithmetic() }
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("arithmeticCancel")
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.compactGlass)
                    .tint(accent)
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.05), value: playback.completedSteps)
        .accessibilityIdentifier("arithmeticTracePanel")
    }

    private func workingReadout(_ label: String, value: String, color: Color, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TinyLabel(label, color: color)
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .accessibilityIdentifier(identifier)
        }
    }
}
