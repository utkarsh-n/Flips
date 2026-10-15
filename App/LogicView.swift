import SwiftUI
import RadixCore

struct LogicView: View {
    @Bindable var playground: Playground
    @State private var operand = RadixNumber(15)
    @State private var operation: BitOperation = .xor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var result: RadixNumber { playground.number.applying(operation, operand: operand) }
    private var interactionAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.1)
    }

    var body: some View {
        NavigationStack {
            RadixScreen {
                RadixHeader(kicker: "The logic bench", title: "Bits meet bits.", subtitle: "Compare two numbers one switch at a time.")
                Picker("Operation", selection: $operation) {
                    ForEach(BitOperation.allCases) { op in Text(op.rawValue).tag(op) }
                }
                .pickerStyle(.segmented).accessibilityIdentifier("logicOperation")
                LabCard(accent: Palette.mint) {
                    TinyLabel("A · your switchboard", color: Palette.mint)
                    logicRow(playground.number, color: Palette.mint)
                    if operation != .not {
                        TinyLabel("B · tap to change", color: Palette.amber)
                        BitBoard(number: operand, accent: Palette.amber, onToggle: toggleOperand)
                        logicRow(operand, color: Palette.amber)
                    }
                }
                .animation(interactionAnimation, value: operation)
                LabCard(accent: Palette.lilac) {
                    TinyLabel("Result", color: Palette.lilac)
                    logicRow(result, color: Palette.lilac)
                    Text(operation.explanation).font(.subheadline)
                    truthTable
                    Button("Use \(result.value) on the switchboard") { playground.set(result.value); dismiss() }
                        .buttonStyle(.glassProminent).tint(Palette.lilac).foregroundStyle(Palette.background)
                        .accessibilityIdentifier("useLogicResult")
                }
                LabCard {
                    TinyLabel("Slide the bits")
                    Text("A left shift moves every bit one place toward a bigger weight. A right shift moves toward a smaller weight. Bits that leave the byte are lost.")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    GlassEffectContainer(spacing: 16) {
                        HStack {
                            Button("← Shift left") {
                                performAnimated {
                                    playground.set(playground.number.shiftedLeft().value, feedback: .step)
                                }
                            }
                            Spacer()
                            Button("Shift right →") {
                                performAnimated {
                                    playground.set(playground.number.shiftedRight().value, feedback: .step)
                                }
                            }
                        }
                        .buttonStyle(.glass).tint(Palette.mint)
                    }
                }
            }
            .navigationTitle("Logic").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        playground.feedback(.navigation)
                        dismiss()
                    }
                }
            }
        }
        .tint(Palette.mint)
        .onChange(of: operation) { _, _ in playground.feedback(.selection) }
    }

    private func logicRow(_ number: RadixNumber, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(number.binary).font(.system(.title2, design: .monospaced, weight: .semibold)).minimumScaleFactor(0.6).lineLimit(1)
                .contentTransition(reduceMotion ? .identity : .numericText())
            Spacer(minLength: 4)
            Text("\(number.value)").font(.system(.headline, design: .monospaced))
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
        .foregroundStyle(color)
        .animation(interactionAnimation, value: number.value)
    }

    private var truthTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            TinyLabel("The rule for one pair of bits")
            HStack(spacing: 8) {
                ForEach(0..<(operation == .not ? 2 : 4), id: \.self) { index in
                    let a = operation == .not ? index : index / 2
                    let b = index % 2
                    let answer = RadixNumber(a).applying(operation, operand: RadixNumber(b)).value & 1
                    VStack(spacing: 5) {
                        Text(operation == .not ? "\(a)" : "\(a) \(opSymbol) \(b)")
                        Text("↓").foregroundStyle(Palette.muted)
                        Text("\(answer)").foregroundStyle(Palette.lilac).fontWeight(.bold)
                            .contentTransition(reduceMotion ? .identity : .numericText())
                    }
                    .font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity)
                    .padding(.vertical, 10).background(Palette.raised, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .animation(interactionAnimation, value: operation)
    }

    private func toggleOperand(_ index: Int) {
        let next = operand.togglingBit(index: index)
        performAnimated { operand = next }
        playground.feedback(next.value & (1 << index) != 0 ? .bitOn : .bitOff)
    }

    private func performAnimated(_ action: () -> Void) {
        if reduceMotion {
            action()
        } else {
            withAnimation(interactionAnimation, action)
        }
    }

    private var opSymbol: String {
        switch operation { case .and: "&"; case .or: "|"; case .xor: "⊕"; case .not: "~" }
    }
}
