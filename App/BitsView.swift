import SwiftUI
import RadixCore

struct BitsView: View {
    @Bindable var playground: Playground
    @State private var sheet: BitsSheet?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { scrollProxy in
        RadixScreen {
            HStack(alignment: .top) {
                RadixHeader(kicker: "A playground for numbers", title: "Flips", subtitle: "Flip a bit. See the whole number change.")
                Spacer(minLength: 4)
                Button { playground.stop(); playground.feedback(.navigation); sheet = .guide } label: {
                    Image(systemName: "questionmark").font(.headline)
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(.glass).buttonBorderShape(.circle).foregroundStyle(Palette.muted)
                .accessibilityLabel("How to play and settings")
            }
            if let playback = playground.playback {
                ArithmeticPlaybackView(playground: playground, playback: playback)
                    .id("arithmeticPlaybackAnchor")
            } else {
                RadixReadouts(number: playground.number)
            }
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: Binding(get: { playground.slowMotionEnabled }, set: {
                    playground.slowMotionEnabled = $0
                    playground.feedback(.selection)
                })) {
                    Label("Slow motion", systemImage: "tortoise")
                        .font(.subheadline.weight(.medium))
                }
                .tint(Palette.mint)
                .accessibilityHint("Shows addition and subtraction one bit at a time")
                .accessibilityIdentifier("slowMotionToggle")
                if playground.slowMotionEnabled {
                    arithmeticSpeedControl
                }
                arithmeticExamples
                HStack {
                    TinyLabel("The switchboard", color: Palette.mint)
                    Spacer()
                    Text("8 bits = 1 byte").font(.caption).foregroundStyle(Palette.muted)
                }
                BitBoard(
                    number: playground.displayedNumber,
                    activeBitIndex: playground.playback?.isComplete == false ? playground.playback?.currentStep?.bitIndex : nil,
                    traceOperation: playground.playback?.trace.operation
                ) { playground.toggle($0) }
                .disabled(playground.hasArithmeticPlayback)
            }
            counterControls
            LabCard(accent: Palette.mint) {
                TinyLabel(playground.playback == nil ? "Follow the change" : "Working bit sum", color: Palette.mint)
                Text(playground.note).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("changeExplanation")
                Text(sum).font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(Palette.mint).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bitSum")
            }
            LabCard {
                HStack {
                    TinyLabel("Scrub the whole byte")
                    Spacer()
                    Text("0…255").font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.muted)
                }
                Slider(value: Binding(get: { Double(playground.number.value) }, set: { playground.scrub(to: Int($0.rounded())) }), in: 0...255, step: 1)
                    .tint(Palette.mint).accessibilityLabel("Decimal number").accessibilityIdentifier("numberSlider")
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 8) {
                        ForEach([0, 15, 16, 127, 255], id: \.self) { value in
                            Button("\(value)") { playground.set(value) }
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                                .buttonStyle(.glass).controlSize(.large)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(playground.number.value == value ? Palette.mint : Palette.muted)
                                .accessibilityLabel("Set number to \(value)")
                                .accessibilityIdentifier("preset\(value)")
                        }
                    }
                }
            }
            Button {
                playground.stop(); playground.feedback(.navigation); sheet = .logic
            } label: {
                HStack {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mix bits with logic").font(.headline)
                        Text("Try AND, OR, XOR, NOT & shifts").font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .foregroundStyle(Palette.mint).padding(.vertical, 10)
            }
            .buttonStyle(.glass).buttonBorderShape(.roundedRectangle(radius: 20))
            .accessibilityIdentifier("openLogic")
        }
        .onChange(of: playground.playback?.id) { _, playbackID in
            guard playbackID != nil else { return }
            if reduceMotion {
                scrollProxy.scrollTo("arithmeticPlaybackAnchor", anchor: .top)
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy.scrollTo("arithmeticPlaybackAnchor", anchor: .top)
                }
            }
        }
        }
        .task(id: playground.running) {
            guard playground.running else { return }
            while !Task.isCancelled && playground.running {
                if playground.hasArithmeticPlayback {
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                    continue
                }
                do { try await Task.sleep(for: .milliseconds(850)) } catch { return }
                guard !Task.isCancelled && playground.running else { return }
                guard !playground.hasArithmeticPlayback else { continue }
                playground.increment()
            }
        }
        .sheet(item: $sheet) { destination in
            Group {
                switch destination {
                case .guide: GuideView(playground: playground)
                case .logic: LogicView(playground: playground)
                }
            }
            .presentationDragIndicator(.visible)
        }
    }

    private var sum: String {
        let active = playground.displayedNumber.bits.filter(\.isOn).map { String($0.weight) }
        return active.isEmpty ? "0 = 0" : active.joined(separator: " + ") + " = \(playground.displayedNumber.value)"
    }

    private var speedText: String {
        playground.slowMotionSpeed.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var stepDurationText: String {
        playground.arithmeticStepSeconds.formatted(.number.precision(.fractionLength(2...2)))
    }

    private var arithmeticSpeedControl: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(speedText)×")
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Palette.mint)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .accessibilityIdentifier("arithmeticSpeedValue")
                Spacer(minLength: 0)
                Text("\(stepDurationText) s/bit")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.trailing)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .accessibilityLabel("\(stepDurationText) seconds per bit")
                    .accessibilityIdentifier("arithmeticStepDuration")
            }

            Slider(value: Binding(get: { playground.slowMotionSpeed }, set: { playground.setSlowMotionSpeed($0) }), in: 0.25...3, step: 0.25) { editing in
                if !editing { playground.feedback(.selection) }
            }
            .tint(Palette.mint)
            .accessibilityLabel("Slow-motion speed")
            .accessibilityValue("\(speedText) times, \(stepDurationText) seconds per bit")
            .accessibilityIdentifier("arithmeticSpeedSlider")

            HStack {
                Label("Slower", systemImage: "tortoise")
                Spacer(minLength: 8)
                Label("Faster", systemImage: "hare")
            }
            .font(.caption)
            .foregroundStyle(Palette.muted)
            .accessibilityHidden(true)
        }
    }

    private var arithmeticExamples: some View {
        GlassEffectContainer(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    carryExample
                    borrowExample
                    overflowExample
                    underflowExample
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        carryExample
                        borrowExample
                    }
                    HStack(spacing: 6) {
                        overflowExample
                        underflowExample
                    }
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 6) {
                    carryExample
                    borrowExample
                    overflowExample
                    underflowExample
                }
            }
            .font(.system(.caption, design: .monospaced, weight: .semibold))
        }
    }

    private var carryExample: some View {
        arithmeticExample("15 + 1", operation: .increment,
                          name: "Play carry example, 15 plus 1",
                          hint: "Enables slow motion and follows the carry using your chosen speed",
                          identifier: "arithmeticCarryExample")
    }

    private var borrowExample: some View {
        arithmeticExample("16 − 1", operation: .decrement,
                          name: "Play borrow example, 16 minus 1",
                          hint: "Enables slow motion and follows the borrow using your chosen speed",
                          identifier: "arithmeticBorrowExample")
    }

    private var overflowExample: some View {
        arithmeticExample("255 + 1", operation: .increment, startingAt: 255,
                          name: "Play overflow wrap example, 255 plus 1 ends at 0",
                          hint: "Enables slow motion and follows the carry beyond eight bits using your chosen speed",
                          identifier: "arithmeticOverflowExample")
    }

    private var underflowExample: some View {
        arithmeticExample("0 − 1", operation: .decrement, startingAt: 0,
                          name: "Play underflow wrap example, 0 minus 1 ends at 255",
                          hint: "Enables slow motion and follows the borrow beyond eight bits using your chosen speed",
                          identifier: "arithmeticUnderflowExample")
    }

    private func arithmeticExample(_ formula: String, operation: RadixStepOperation, startingAt: Int? = nil,
                                   name: String, hint: String, identifier: String) -> some View {
        Button(formula) { playground.playArithmeticExample(operation, startingAt: startingAt) }
            .buttonStyle(.compactGlass)
            .tint(operation == .increment ? Palette.amber : Palette.lilac)
            .foregroundStyle(operation == .increment ? Palette.amber : Palette.lilac)
            .accessibilityLabel(name)
            .accessibilityHint(hint)
            .accessibilityIdentifier(identifier)
    }

    private var counterControls: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                Button { playground.stop(); playground.decrement() } label: {
                    Text("−1")
                }
                .buttonStyle(.compactGlass)
                .disabled(playground.hasArithmeticPlayback)
                .accessibilityLabel("Subtract one").accessibilityIdentifier("decrement")
                Button { playground.toggleCounting() } label: {
                    Label(playground.running ? "Pause" : "Count", systemImage: playground.running ? "pause.fill" : "play.fill")
                        .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                }
                .buttonStyle(CompactGlassButtonStyle(tint: Palette.mint))
                .foregroundStyle(Palette.background)
                .disabled(playground.hasArithmeticPlayback && !playground.running)
                .accessibilityIdentifier("countToggle")
                Button { playground.stop(); playground.increment() } label: {
                    Text("+1")
                }
                .buttonStyle(.compactGlass)
                .disabled(playground.hasArithmeticPlayback)
                .accessibilityLabel("Add one").accessibilityIdentifier("increment")
            }
            .frame(maxWidth: .infinity)
        }
        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
        .foregroundStyle(Palette.mint)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: playground.running)
    }
}

private enum BitsSheet: String, Identifiable {
    case guide, logic
    var id: String { rawValue }
}

private struct GuideView: View {
    @Bindable var playground: Playground
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            RadixScreen {
                RadixHeader(kicker: "Start anywhere", title: "Same number. New eyes.", subtitle: "A base tells you how many different digits you have before you carry into the next place.")
                LabCard(accent: Palette.mint) {
                    Label("Binary has just 0 and 1", systemImage: "switch.2").font(.headline).foregroundStyle(Palette.mint)
                    Text("Each switch is a bit. Its weight doubles as you move left: 1, 2, 4, 8… Add the weights of the lit switches to find the number.")
                    Text("Try 8 + 2 + 1. You just made 11.").foregroundStyle(Palette.muted)
                }
                LabCard(accent: Palette.lilac) {
                    Text("Decimal is what you already use").font(.headline).foregroundStyle(Palette.lilac)
                    Text("It has ten digits, 0 through 9. Each place is ten times the one to its right: ones, tens, hundreds.")
                }
                LabCard(accent: Palette.amber) {
                    Text("Hex is a shortcut for binary").font(.headline).foregroundStyle(Palette.amber)
                    Text("Hexadecimal has sixteen digits: 0–9, then A–F for 10–15. Four bits have sixteen possible patterns, so one hex digit represents exactly four bits.")
                    Text("0010 1010 → 2A → 42").font(.system(.body, design: .monospaced)).foregroundStyle(Palette.amber)
                }
                LabCard {
                    Toggle("Touch feedback", isOn: $playground.hapticsEnabled).tint(Palette.mint)
                        .onChange(of: playground.hapticsEnabled) { _, enabled in
                            if enabled { playground.feedback(.bitOn) }
                        }
                    Text("Feel a crisp click when a bit turns on, a softer click when it turns off, and a stronger bump when the counter carries or wraps.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    Text("This playground uses whole numbers from 0 to 255: one unsigned byte. A full counter wraps back to zero. Negative numbers and fractions use additional rules.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
            }
            .navigationTitle("How to play").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { playground.feedback(.navigation); dismiss() } } }
        }
        .tint(Palette.mint)
    }
}
