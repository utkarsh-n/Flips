import Foundation
import SwiftUI
import RadixCore

struct DiscoverView: View {
    @Bindable var playground: Playground
    var onExplore: () -> Void = {}

    @AppStorage("radix.missions.completed") private var savedMissionIDs = "[]"
    @State private var missionIndex = 0
    @State private var answer = RadixNumber(0)
    @State private var showsHint = false
    @State private var feedback: MissionFeedback?
    @State private var preparedForTesting = false
    @State private var completionPulse = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var responseAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88)
    }
    private var responseTransition: AnyTransition {
        reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
    }

    private var missions: [RadixMission] { RadixMission.catalog }
    private var mission: RadixMission { missions[missionIndex] }
    private var completedIDs: Set<String> {
        guard let data = savedMissionIDs.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids)
    }
    private var completedCount: Int {
        missions.filter { completedIDs.contains(missionKey($0)) }.count
    }

    var body: some View {
        RadixScreen {
            RadixHeader(
                kicker: "DISCOVER",
                title: "Make it click.",
                subtitle: "Little challenges. Real connections. Build a number and see what it can do."
            )

            if !missions.isEmpty {
                missionProgress
                missionLab
            }

            HexColorLab(playground: playground)
            NumberSystemGuide()
        }
        .onAppear {
            playground.stop()
            if !preparedForTesting, ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                savedMissionIDs = "[]"
                preparedForTesting = true
            }
        }
        .onChange(of: feedback?.isNewCompletion) { _, isNewCompletion in
            if isNewCompletion == true, !reduceMotion { completionPulse += 1 }
        }
    }

    private var missionProgress: some View {
        LabCard(accent: Palette.lilac) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    TinyLabel("YOUR DISCOVERIES", color: Palette.lilac)
                    Spacer(minLength: 12)
                    Text("\(completedCount) / \(missions.count)")
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                        .accessibilityIdentifier("missionProgress")
                }
                ProgressView(value: Double(completedCount), total: Double(missions.count))
                    .tint(Palette.lilac)
                    .accessibilityLabel("Discoveries completed")
                    .accessibilityValue("\(completedCount) of \(missions.count)")
                Text(completedCount == missions.count
                     ? "Every mission discovered. Pick one to play again."
                     : "Progress saves after you check a correct answer.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
            }
            .animation(responseAnimation, value: completedCount)
        }
    }

    private var missionLab: some View {
        LabCard(accent: Palette.lilac) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    TinyLabel("MISSION \(missionIndex + 1)", color: Palette.lilac)
                    Spacer(minLength: 8)
                    missionPicker
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(mission.title)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text(mission.prompt)
                        .font(.body)
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TinyLabel("YOUR ANSWER")
                    BitBoard(number: answer, accent: Palette.lilac) { index in
                        let next = answer.togglingBit(index: index)
                        withAnimation(responseAnimation) {
                            answer = next
                            feedback = nil
                        }
                        playground.feedback(next.value & (1 << index) != 0 ? .bitOn : .bitOff)
                    }
                    compactAnswerReadouts
                }

                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: checkAnswer) {
                            Label("Check answer", systemImage: "checkmark")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Palette.lilac)
                        .foregroundStyle(Palette.background)
                        .accessibilityIdentifier("checkAnswer")

                        Button {
                            withAnimation(responseAnimation) { showsHint.toggle() }
                            playground.feedback(.selection)
                        } label: {
                            Image(systemName: showsHint ? "lightbulb.fill" : "lightbulb")
                                .font(.body.weight(.semibold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glass)
                        .tint(Palette.lilac)
                        .accessibilityLabel(showsHint ? "Hide hint" : "Show hint")
                    }
                }

                if showsHint {
                    Label {
                        Text(mission.hint)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lightbulb")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.amber)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    .transition(responseTransition)
                    .accessibilityIdentifier("missionHint")
                }

                if let feedback {
                    feedbackView(feedback)
                        .transition(responseTransition)
                }

                Rectangle()
                    .fill(Palette.line)
                    .frame(height: 1)

                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            selectMission((missionIndex - 1 + missions.count) % missions.count)
                        } label: {
                            Image(systemName: "arrow.left")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glass)
                        .tint(Palette.muted)
                        .accessibilityLabel("Previous mission")

                        Button {
                            selectMission((missionIndex + 1) % missions.count)
                        } label: {
                            HStack {
                                Text(missionIndex == missions.count - 1 ? "Replay from start" : "Next mission")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.glass)
                        .tint(Palette.lilac)
                        .accessibilityIdentifier("nextMission")
                    }
                }
            }
        }
    }

    private var missionPicker: some View {
        Menu {
            ForEach(missions.indices, id: \.self) { index in
                Button {
                    selectMission(index, emitsFeedback: false)
                } label: {
                    let item = missions[index]
                    if completedIDs.contains(missionKey(item)) {
                        Label("\(index + 1). \(item.title)", systemImage: "checkmark.circle.fill")
                    } else {
                        Text("\(index + 1). \(item.title)")
                    }
                }
            }
        } label: {
            Label("Choose", systemImage: "list.bullet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.lilac)
                .frame(minHeight: 44)
        }
        .buttonStyle(.glass)
        .tint(Palette.lilac)
        .accessibilityLabel("Choose a mission")
        .accessibilityIdentifier("missionPicker")
    }

    private var compactAnswerReadouts: some View {
        HStack(alignment: .top, spacing: 12) {
            answerReadout("DECIMAL", value: answer.decimal, color: Palette.lilac, identifier: "decimalReadout")
            answerReadout("BINARY", value: answer.binary, color: Palette.mint, identifier: "binaryReadout")
            answerReadout("HEX", value: answer.hexadecimal, color: Palette.amber, identifier: "hexReadout")
        }
        .padding(12)
        .background(Palette.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.line))
        .animation(responseAnimation, value: answer.value)
    }

    private func answerReadout(_ label: String, value: String, color: Color, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            TinyLabel(label, color: color)
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(reduceMotion ? .identity : (label == "HEX" ? .opacity : .numericText()))
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feedbackView(_ result: MissionFeedback) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(result.isCorrect ? "You’ve got it." : "Keep experimenting.")
            } icon: {
                Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "arrow.trianglehead.clockwise")
                    .symbolEffect(.bounce, options: .nonRepeating, value: completionPulse)
                    .symbolEffectsRemoved(reduceMotion)
            }
            .font(.system(.headline, design: .rounded))
            Text(result.message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if result.isCorrect {
                Button {
                    playground.set(answer.value)
                    onExplore()
                } label: {
                    Label("Play with this number", systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.glass)
                .tint(Palette.mint)
                .accessibilityIdentifier("useMissionNumber")
            }
        }
        .foregroundStyle(result.isCorrect ? Palette.mint : Palette.amber)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((result.isCorrect ? Palette.mint : Palette.amber).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("missionFeedback")
    }

    private func checkAnswer() {
        let isCorrect = mission.isSatisfied(by: answer)
        let isNewCompletion = isCorrect && !completedIDs.contains(missionKey(mission))
        if isNewCompletion {
            var ids = completedIDs
            ids.insert(missionKey(mission))
            if let data = try? JSONEncoder().encode(ids.sorted()),
               let string = String(data: data, encoding: .utf8) {
                savedMissionIDs = string
            }
        }
        playground.feedback(isCorrect ? (isNewCompletion ? .success : .selection) : .warning)
        withAnimation(responseAnimation) {
            feedback = MissionFeedback(
                isCorrect: isCorrect,
                isNewCompletion: isNewCompletion,
                message: isCorrect
                    ? mission.explanation
                    : "Your bits make \(answer.value) in decimal (\(answer.hexadecimal) in hex). \(answerAddition) Try changing a bit, then check again."
            )
        }
    }

    private var answerAddition: String {
        let powers = (0..<8).reversed().filter { answer.value & (1 << $0) != 0 }.map { String(1 << $0) }
        return powers.isEmpty ? "All the bits are off, so the total is 0." : "The lit places add up: \(powers.joined(separator: " + ")) = \(answer.value)."
    }

    private func selectMission(_ index: Int, emitsFeedback: Bool = true) {
        if emitsFeedback { playground.feedback(.navigation) }
        withAnimation(responseAnimation) {
            missionIndex = index
            answer = RadixNumber(0)
            showsHint = false
            feedback = nil
        }
    }

    private func missionKey(_ item: RadixMission) -> String { String(describing: item.id) }
}

private struct MissionFeedback {
    let isCorrect: Bool
    let isNewCompletion: Bool
    let message: String
}

private struct HexColorLab: View {
    @Bindable var playground: Playground
    @State private var red = 103.0
    @State private var green = 224.0
    @State private var blue = 196.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var redByte: Int { Int(red.rounded()) }
    private var greenByte: Int { Int(green.rounded()) }
    private var blueByte: Int { Int(blue.rounded()) }
    private var hexColor: String { String(format: "#%02X%02X%02X", redByte, greenByte, blueByte) }
    private var swatch: Color { Color(red: red / 255, green: green / 255, blue: blue / 255) }
    private var swatchText: Color {
        func linearize(_ channel: Double) -> Double {
            let normalized = channel / 255
            return normalized <= 0.04045 ? normalized / 12.92 : pow((normalized + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
        let blackContrast = (luminance + 0.05) / 0.05
        let whiteContrast = 1.05 / (luminance + 0.05)
        return blackContrast >= whiteContrast ? .black : .white
    }

    var body: some View {
        LabCard(accent: Palette.lilac) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    TinyLabel("HEX IN THE WILD", color: Palette.lilac)
                    Text("Numbers make color.")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text("Mix red, green and blue. Each channel is a byte: a number from 0 to 255.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                }

                VStack(spacing: 8) {
                    Text(hexColor)
                        .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                        .contentTransition(reduceMotion ? .identity : .opacity)
                        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.9), value: hexColor)
                    Text("Your color, written in hex")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(swatchText)
                .frame(maxWidth: .infinity, minHeight: 142)
                .padding(16)
                .background(swatch, in: RoundedRectangle(cornerRadius: 20))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Color hex code \(hexColor)")
                .accessibilityIdentifier("hexColorSwatch")

                VStack(spacing: 18) {
                    ColorChannelSlider(name: "Red", value: $red, color: .red)
                    ColorChannelSlider(name: "Green", value: $green, color: Palette.mint)
                    ColorChannelSlider(name: "Blue", value: $blue, color: .cyan)
                }

                VStack(alignment: .leading, spacing: 10) {
                    TinyLabel("SIX DIGITS. THREE BYTES.")
                    HStack(spacing: 8) {
                        ColorByteReadout(name: "RED", value: redByte, color: .red)
                        ColorByteReadout(name: "GREEN", value: greenByte, color: Palette.mint)
                        ColorByteReadout(name: "BLUE", value: blueByte, color: .cyan)
                    }
                    Text("Each pair of hex digits holds 8 bits. FF is 255: that channel is fully on. 00 is 0: fully off.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onChange(of: redByte) { old, new in playground.scrubFeedback(from: old, to: new) }
        .onChange(of: greenByte) { old, new in playground.scrubFeedback(from: old, to: new) }
        .onChange(of: blueByte) { old, new in playground.scrubFeedback(from: old, to: new) }
    }
}

private struct ColorChannelSlider: View {
    let name: String
    @Binding var value: Double
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(Int(value.rounded()))")
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.9), value: Int(value.rounded()))
            }
            Slider(value: $value, in: 0...255, step: 1)
                .tint(color)
                .accessibilityLabel("\(name) channel")
                .accessibilityValue("\(Int(value.rounded())) of 255")
                .accessibilityIdentifier("color\(name)")
        }
    }
}

private struct ColorByteReadout: View {
    let name: String
    let value: Int
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 7) {
            TinyLabel(name, color: color)
            Text(String(format: "%02X", value))
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .foregroundStyle(Palette.text)
                .contentTransition(reduceMotion ? .identity : .opacity)
            Text("\(value)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.muted)
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 14))
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.9), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): decimal \(value), hex \(String(format: "%02X", value))")
    }
}

private struct NumberSystemGuide: View {
    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 16) {
                TinyLabel("THE SAME NUMBER. DIFFERENT ALPHABETS.")
                systemRow(name: "Binary", base: "BASE 2", detail: "Uses 0 and 1. Every place is worth twice the one to its right. Eight places make a byte.", color: Palette.mint)
                systemRow(name: "Decimal", base: "BASE 10", detail: "Uses 0 through 9. Places are ones, tens, hundreds… the numbers you already know.", color: Palette.lilac)
                systemRow(name: "Hexadecimal", base: "BASE 16", detail: "Uses 0 through 9, then A through F for 10 through 15. One hex digit neatly holds four bits.", color: Palette.amber)
            }
        }
    }

    private func systemRow(name: String, base: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(color)
                Spacer(minLength: 8)
                TinyLabel(base)
            }
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
