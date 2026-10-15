import SwiftUI
import RadixCore

struct BasesView: View {
    @Bindable var playground: Playground

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var representationSize = 46
    @State private var base = 16
    @State private var input = ""
    @State private var inputError: String?
    @State private var transition: BaseCountingTransition?
    @FocusState private var inputIsFocused: Bool

    private let supportedBases = [2, 8, 10, 16]

    private var representation: String {
        display(playground.number)
    }

    private var digits: [PositionalDigit] {
        (try? playground.number.positionalDigits(base: base)) ?? []
    }

    private var interactionAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.1)
    }

    private var baseName: String {
        switch base {
        case 2: "Binary"
        case 8: "Octal"
        case 10: "Decimal"
        default: "Hexadecimal"
        }
    }

    private var digitGuide: String {
        switch base {
        case 2: "Digits: 0 and 1"
        case 8: "Digits: 0–7"
        case 10: "Digits: 0–9"
        default: "Digits: 0–9, then A–F"
        }
    }

    var body: some View {
        RadixScreen {
            RadixHeader(
                kicker: "BASES LAB",
                title: "Same number. New digits.",
                subtitle: "A base tells you how many different digits you can use. Change the base and watch the places change."
            )

            representationCard
            countingCard
            placeValueCard
            inputCard
        }
        .tint(Palette.amber)
        .onAppear {
            playground.stop()
            input = representation
            inputError = nil
            transition = nil
        }
        .onChange(of: base) { _, _ in
            playground.feedback(.selection)
            inputIsFocused = false
            input = representation
            inputError = nil
            transition = nil
        }
        .onChange(of: playground.number.value) { _, _ in
            if !inputIsFocused {
                input = representation
                inputError = nil
            }
        }
    }

    private var representationCard: some View {
        LabCard(accent: Palette.amber) {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Number base", selection: $base) {
                    ForEach(supportedBases, id: \.self) { choice in
                        Text("\(choice)").tag(choice)
                            .accessibilityLabel("Base \(choice)")
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("basePicker")

                VStack(alignment: .leading, spacing: 5) {
                    TinyLabel("\(baseName.uppercased()) · BASE \(base)", color: Palette.amber)
                    Text(representation)
                        .font(.system(size: representationSize, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.amber)
                        .lineLimit(1)
                        .minimumScaleFactor(0.35)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                        .animation(interactionAnimation, value: base)
                        .accessibilityLabel("\(baseName) representation: \(spokenDigits(representation))")
                        .accessibilityIdentifier("baseRepresentation")
                    Text("Still \(playground.number.value) in decimal.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                }

                RadixReadouts(number: playground.number)
            }
        }
    }

    private var placeValueCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 16) {
                TinyLabel("WHAT EACH PLACE IS WORTH")
                Text("Moving left multiplies the place by \(base).")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Text("Start with the 1 place on the right. Multiply each digit by its place, then add the results.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 9)], spacing: 9) {
                    ForEach(digits, id: \.exponent) { digit in
                        BasePlaceTile(
                            digit: digit,
                            isHighlighted: transition?.changedPlaces.contains(digit.exponent) == true
                        )
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .animation(interactionAnimation, value: digits)

                VStack(alignment: .leading, spacing: 7) {
                    TinyLabel("ADD THE CONTRIBUTIONS")
                    Text(digits.map { String($0.contribution) }.joined(separator: " + "))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("= \(playground.number.value)")
                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Palette.amber)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                }

                if base == 16 {
                    Text("Hex uses letters for six more digits: A = 10, B = 11, C = 12, D = 13, E = 14, F = 15.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var inputCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                TinyLabel("TRY YOUR OWN NUMBER")
                Text("Enter \(baseName.lowercased()) digits")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Text(digitGuide)
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)

                TextField("A number in base \(base)", text: $input)
                    .font(.system(.title3, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(base == 16 ? .asciiCapable : .numbersAndPunctuation)
                    .submitLabel(.go)
                    .focused($inputIsFocused)
                    .padding(13)
                    .background(Palette.raised, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(inputError == nil ? Palette.line : Palette.amber, lineWidth: 1)
                    }
                    .accessibilityLabel("Number to convert from base \(base)")
                    .accessibilityIdentifier("baseInput")
                    .onSubmit(convertInput)
                    .onChange(of: input) { _, _ in inputError = nil }

                if let inputError {
                    Label(inputError, systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(Palette.amber)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("baseInputError")
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
                }

                Button(action: convertInput) {
                    Text("Convert number")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .foregroundStyle(Palette.background)
                .controlSize(.large)
                .accessibilityIdentifier("convertNumber")

                Text("This toy holds one byte: 0–255 in decimal. Enter digits without a prefix such as 0x.")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var countingCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 15) {
                TinyLabel("FOLLOW THE CARRY")
                Text("What happens after the last digit?")
                    .font(.headline)
                    .foregroundStyle(Palette.text)

                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button { count(by: -1) } label: {
                            Text("−1").frame(maxWidth: .infinity)
                        }
                        .accessibilityLabel("Subtract one")
                        .accessibilityIdentifier("baseDecrement")

                        Button { count(by: 1) } label: {
                            Text("+1").frame(maxWidth: .infinity)
                        }
                        .accessibilityLabel("Add one")
                        .accessibilityIdentifier("baseIncrement")
                    }
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }

                if let transition {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("\(transition.before) → \(transition.after)")
                            .font(.system(.title2, design: .monospaced, weight: .semibold))
                            .foregroundStyle(Palette.amber)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .contentTransition(reduceMotion ? .identity : .numericText())
                        Text(transition.explanation)
                            .font(.subheadline)
                            .foregroundStyle(Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("baseCountingExplanation")
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
                } else {
                    Text(carryPreview)
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var carryPreview: String {
        let lastDigit = String(base - 1, radix: base, uppercase: true)
        return "In base \(base), \(lastDigit) is the last digit. Add 1 and it becomes 10: a 0 in the ones place and a 1 in the next place. That 10 means \(base) in decimal."
    }

    private func display(_ number: RadixNumber) -> String {
        (try? number.representation(base: base)) ?? number.decimal
    }

    private func spokenDigits(_ representation: String) -> String {
        representation.map(String.init).joined(separator: ", ")
    }

    private func convertInput() {
        do {
            let result = try RadixNumber.parse(input, base: base)
            inputIsFocused = false
            performAnimated {
                transition = nil
                playground.set(result.value)
            }
            input = display(result)
            inputError = nil
            playground.note = "\(input) in base \(base) describes \(result.value) in decimal."
        } catch {
            playground.feedback(.warning)
            performAnimated {
                inputError = error.localizedDescription
            }
        }
    }

    private func count(by amount: Int) {
        inputIsFocused = false
        let before = playground.number
        let after = amount > 0 ? before.incremented : before.decremented
        let change = BaseCountingTransition(before: before, after: after, base: base, incrementing: amount > 0)
        performAnimated {
            transition = change
            if amount > 0 {
                playground.increment(animated: false)
            } else {
                playground.decrement(animated: false)
            }
        }
        input = display(after)
        inputError = nil
    }

    private func performAnimated(_ action: () -> Void) {
        if reduceMotion {
            action()
        } else {
            withAnimation(interactionAnimation, action)
        }
    }
}

private struct BasePlaceTile: View {
    let digit: PositionalDigit
    let isHighlighted: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            Text(digit.symbol)
                .font(.system(.title, design: .monospaced, weight: .bold))
                .foregroundStyle(Palette.amber)
                .contentTransition(reduceMotion ? .identity : .numericText())
            Text("× \(digit.placeValue)")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(Palette.muted)
            Text("= \(digit.contribution)")
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .foregroundStyle(Palette.text)
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .padding(.horizontal, 4)
        .background(isHighlighted ? Palette.amber.opacity(0.12) : Palette.raised, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Palette.amber.opacity(0.7) : Palette.line, lineWidth: 1)
        }
        .scaleEffect(isHighlighted && !reduceMotion ? 1.025 : 1)
        .animation(reduceMotion ? nil : .spring(duration: 0.26, bounce: 0.1), value: isHighlighted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(digit.symbol), worth \(digit.digit), times the \(digit.placeValue) place equals \(digit.contribution)")
        .accessibilityIdentifier("basePlace\(digit.exponent)")
    }
}

private struct BaseCountingTransition {
    let before: String
    let after: String
    let changedPlaces: Set<Int>
    let explanation: String

    init(before oldNumber: RadixNumber, after newNumber: RadixNumber, base: Int, incrementing: Bool) {
        before = (try? oldNumber.representation(base: base)) ?? oldNumber.decimal
        after = (try? newNumber.representation(base: base)) ?? newNumber.decimal
        let oldDigits = Array(before.reversed())
        let newDigits = Array(after.reversed())
        changedPlaces = Set((0..<max(oldDigits.count, newDigits.count)).filter { place in
            let oldDigit = place < oldDigits.count ? oldDigits[place] : "0"
            let newDigit = place < newDigits.count ? newDigits[place] : "0"
            return oldDigit != newDigit
        })

        if incrementing, oldNumber.value == 255 {
            explanation = "This byte is full at 255. Adding 1 would make 256, which needs a ninth bit. The toy wraps back to 0 because it keeps only 8 bits."
        } else if !incrementing, oldNumber.value == 0 {
            explanation = "Subtracting 1 from 0 wraps this unsigned byte to 255. It has no minus sign or negative values: it keeps only 8 bits."
        } else if incrementing {
            let lastDigit = Character(String(base - 1, radix: base, uppercase: true))
            let carryCount = oldDigits.prefix(while: { $0 == lastDigit }).count
            if carryCount == 0 {
                explanation = "The ones place has room for another digit. Add 1 there; all the other places stay the same."
            } else if carryCount == 1 {
                explanation = "\(lastDigit) is the last base-\(base) digit. Reset it to 0 and carry 1 into the \(base) place on its left."
            } else {
                let nextPlace = (0..<carryCount).reduce(1) { product, _ in product * base }
                explanation = "The rightmost \(carryCount) digits are all \(lastDigit). Reset them to 0 and carry 1 into the \(nextPlace) place."
            }
        } else {
            let borrowCount = oldDigits.prefix(while: { $0 == "0" }).count
            if borrowCount == 0 {
                explanation = "The ones place can give up 1. Subtract it there; all the other places stay the same."
            } else {
                let lastDigit = String(base - 1, radix: base, uppercase: true)
                let place = (0..<borrowCount).reduce(1) { product, _ in product * base }
                explanation = "The ones place is 0, so borrow from the \(place) place. Its digit drops by 1; the \(borrowCount == 1 ? "zero on its right becomes" : "zeros on its right become") \(lastDigit)."
            }
        }
    }
}
