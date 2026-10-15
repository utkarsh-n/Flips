import SwiftUI
import RadixCore

enum Palette {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.075)
    static let panel = Color(red: 0.072, green: 0.095, blue: 0.12)
    static let raised = Color(red: 0.115, green: 0.14, blue: 0.17)
    static let mint = Color(red: 0.48, green: 0.96, blue: 0.77)
    static let amber = Color(red: 1, green: 0.74, blue: 0.39)
    static let lilac = Color(red: 0.76, green: 0.69, blue: 1)
    static let text = Color(red: 0.94, green: 0.96, blue: 0.97)
    static let muted = Color(red: 0.65, green: 0.71, blue: 0.76)
    static let line = Color.white.opacity(0.10)
}

struct CompactGlassButtonStyle: ButtonStyle {
    var tint: Color? = nil
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        surface(configuration.label)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    @ViewBuilder private func surface(_ label: Configuration.Label) -> some View {
        if reduceTransparency {
            label
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(tint ?? Palette.raised, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
        } else if let tint {
            label
                .padding(.horizontal, 12).padding(.vertical, 7)
                .glassEffect(.regular.tint(tint).interactive(isEnabled), in: Capsule())
        } else {
            label
                .padding(.horizontal, 12).padding(.vertical, 7)
                .glassEffect(.regular.interactive(isEnabled), in: Capsule())
        }
    }
}

extension ButtonStyle where Self == CompactGlassButtonStyle {
    static var compactGlass: CompactGlassButtonStyle { CompactGlassButtonStyle() }
}

struct RadixScreen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) { content }
                .frame(maxWidth: 620)
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
        }
        .background {
            ZStack {
                Palette.background
                RadialGradient(colors: [Palette.mint.opacity(0.10), .clear], center: .topLeading, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Palette.lilac.opacity(0.08), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 400)
            }
            .ignoresSafeArea()
            .overlay {
                    Canvas { context, size in
                        for x in stride(from: 12.0, to: size.width, by: 24) {
                            for y in stride(from: 12.0, to: size.height, by: 24) {
                                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(Palette.muted.opacity(0.13)))
                            }
                        }
                    }
                    .allowsHitTesting(false)
            }
        }
        .foregroundStyle(Palette.text)
    }
}

struct LabCard<Content: View>: View {
    var accent: Color? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22).strokeBorder(accent?.opacity(0.23) ?? Palette.line, lineWidth: 1)
            }
    }
}

struct TinyLabel: View {
    var text: String
    var color: Color
    init(_ text: String, color: Color = Palette.muted) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased()).font(.system(.caption2, design: .monospaced, weight: .semibold))
            .tracking(1.7).foregroundStyle(color)
    }
}

struct RadixHeader: View {
    var kicker: String
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TinyLabel(kicker, color: Palette.mint)
            Text(title).font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text(subtitle).font(.subheadline).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("screenHeader")
    }
}

struct RadixReadouts: View {
    var number: RadixNumber
    var showDecimal = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 10) {
            if showDecimal {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        TinyLabel("Decimal · base 10", color: Palette.lilac)
                        Text("\(number.value)").font(.system(size: 70, weight: .semibold, design: .rounded))
                            .monospacedDigit().foregroundStyle(Palette.lilac)
                            .contentTransition(reduceMotion ? .identity : .numericText())
                            .accessibilityIdentifier("decimalReadout")
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("ONE NUMBER").font(.system(.caption2, design: .monospaced, weight: .medium)).tracking(1)
                        Text("three languages").font(.caption).foregroundStyle(Palette.muted)
                        HStack(spacing: 4) {
                            ForEach(0..<8) { index in
                                Capsule().fill(number.bits[index].isOn ? Palette.mint : Palette.raised)
                                    .frame(width: 5, height: number.bits[index].isOn ? 23 : 12)
                            }
                        }
                        .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.lilac.opacity(0.22)))
            }
            HStack(spacing: 10) {
                readout(label: "Binary · base 2", value: number.binary, color: Palette.mint, id: "binaryReadout")
                readout(label: "Hex · base 16", value: number.hexadecimal, color: Palette.amber, id: "hexReadout")
                    .frame(maxWidth: 125)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: number.value)
    }
    private func readout(label: String, value: String, color: Color, id: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TinyLabel(label, color: color)
            Text(value).font(.system(.title2, design: .monospaced, weight: .semibold))
                .foregroundStyle(color).minimumScaleFactor(0.65).lineLimit(1)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .accessibilityIdentifier(id)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(color.opacity(0.18)))
    }
}

struct BitBoard: View {
    var number: RadixNumber
    var accent: Color = Palette.mint
    var activeBitIndex: Int? = nil
    var traceOperation: RadixStepOperation? = nil
    var onToggle: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 18) {
            bitRow(indices: [7, 6, 5, 4], label: "HIGH FOUR BITS", hexDigit: String(number.highNibble, radix: 16).uppercased(), multiplier: 16)
            bitRow(indices: [3, 2, 1, 0], label: "LOW FOUR BITS", hexDigit: String(number.lowNibble, radix: 16).uppercased(), multiplier: 1)
        }
    }
    private func bitRow(indices: [Int], label: String, hexDigit: String, multiplier: Int) -> some View {
        VStack(spacing: 9) {
            HStack {
                TinyLabel(label)
                Spacer()
                Text("\(hexDigit) × \(multiplier)")
                    .font(.system(.caption, design: .monospaced, weight: .semibold)).foregroundStyle(Palette.amber)
            }
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 10) {
                    ForEach(indices, id: \.self) { index in
                        BitSwitch(index: index, isOn: number.value & (1 << index) != 0, accent: accent,
                                  isActive: activeBitIndex == index, traceOperation: traceOperation) {
                            onToggle(index)
                        }
                    }
                }
            }
            HStack(spacing: 0) {
                Rectangle().fill(accent.opacity(0.15)).frame(height: 1)
                Image(systemName: "arrow.down").font(.system(size: 9)).foregroundStyle(Palette.amber).padding(.horizontal, 8)
                Text("HEX \(hexDigit)").font(.system(.caption2, design: .monospaced, weight: .bold)).foregroundStyle(Palette.amber)
                Image(systemName: "arrow.down").font(.system(size: 9)).foregroundStyle(Palette.amber).padding(.horizontal, 8)
                Rectangle().fill(accent.opacity(0.15)).frame(height: 1)
            }
            .accessibilityLabel("These four bits make hexadecimal digit \(hexDigit)")
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: number.value)
    }
}

private struct BitSwitch: View {
    var index: Int
    var isOn: Bool
    var accent: Color
    var isActive: Bool
    var traceOperation: RadixStepOperation?
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var weight: Int { 1 << index }
    private var traceAccent: Color { traceOperation == .decrement ? Palette.lilac : Palette.amber }
    private var traceLabel: String { traceOperation == .decrement ? "BORROW" : "CARRY" }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Text("\(weight)")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(isOn ? accent : Palette.muted)
                lens
                    .overlay {
                        if isActive {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(traceAccent, lineWidth: 2.5)
                                .accessibilityHidden(true)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if isActive {
                            Text(traceLabel)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(0.5)
                                .foregroundStyle(Palette.background)
                                .padding(.horizontal, 5).padding(.vertical, 3)
                                .background(traceAccent, in: Capsule())
                                .offset(y: 6)
                                .accessibilityHidden(true)
                        }
                    }
                    .scaleEffect(reduceMotion ? 1 : isActive ? 1.04 : isOn ? 1.025 : 1)
                    .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.72), value: isOn)
                    .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.8), value: isActive)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(BitPressStyle())
        .accessibilityLabel("Bit \(index), weight \(weight)")
        .accessibilityValue((isOn ? "1, on" : "0, off") + (isActive ? ", processed in this \(traceLabel.lowercased()) step" : ""))
        .accessibilityHint(isActive ? "Last processed bit in the \(traceLabel.lowercased()) step, worth \(weight)" : isOn ? "Subtracts \(weight)" : "Adds \(weight)")
        .accessibilityIdentifier("bit\(index)")
    }

    @ViewBuilder private var lens: some View {
        if reduceTransparency {
            lensContent
                .background(isOn ? Palette.raised : Palette.panel, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(isOn ? accent.opacity(0.7) : Palette.line, lineWidth: 1.2))
        } else {
            lensContent
                .glassEffect(.regular.tint(isOn ? accent.opacity(0.22) : .white.opacity(0.04)).interactive(), in: .rect(cornerRadius: 18))
        }
    }

    private var lensContent: some View {
        VStack(spacing: 7) {
            Image(systemName: "circle.fill")
                .resizable().scaledToFit()
                .foregroundStyle(isOn ? accent : Palette.muted.opacity(0.45))
                .frame(width: 11, height: 11)
                .symbolEffect(.bounce, options: .nonRepeating, value: isOn)
                .symbolEffectsRemoved(reduceMotion)
                .shadow(color: isOn ? accent.opacity(0.45) : .clear, radius: 6)
            Text(isOn ? "1" : "0")
                .font(.system(.title, design: .monospaced, weight: .semibold))
                .foregroundStyle(isOn ? accent : Palette.muted)
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
    }
}

private struct BitPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
