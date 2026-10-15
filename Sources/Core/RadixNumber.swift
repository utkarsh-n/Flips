import Foundation

/// One unsigned byte. Every base describes the same quantity; only the digits change.
public struct RadixNumber: Equatable, Hashable, Sendable {
    public private(set) var value: Int

    public init(_ value: Int) {
        self.value = min(255, max(0, value))
    }

    public var binary: String { String(repeating: "0", count: 8 - String(value, radix: 2).count) + String(value, radix: 2) }
    public var hexadecimal: String {
        let digits = String(value, radix: 16, uppercase: true)
        return String(repeating: "0", count: 2 - digits.count) + digits
    }
    public var decimal: String { String(value) }

    /// Ordered left to right, exactly as they appear in the binary representation.
    public var bits: [RadixBit] {
        (0..<8).reversed().map { index in
            let weight = 1 << index
            return RadixBit(bitIndex: index, weight: weight, isOn: value & weight != 0)
        }
    }

    public var highNibble: Int { value >> 4 }
    public var lowNibble: Int { value & 0x0F }

    /// Bit zero is the rightmost bit, worth one. Invalid positions leave the byte unchanged.
    public mutating func toggleBit(index: Int) {
        guard (0..<8).contains(index) else { return }
        value ^= 1 << index
    }

    public func togglingBit(index: Int) -> RadixNumber {
        var copy = self
        copy.toggleBit(index: index)
        return copy
    }

    /// Use up to eight places, the maximum needed to write a byte in any supported base.
    public func representation(base: Int, minimumDigits: Int = 1) throws -> String {
        try Self.validate(base: base, minimumDigits: minimumDigits)
        let digits = String(value, radix: base, uppercase: true)
        return String(repeating: "0", count: max(0, minimumDigits - digits.count)) + digits
    }

    /// For decimal 123: 1×100, 2×10, 3×1. In every base, the contributions sum to `value`.
    public func positionalDigits(base: Int, minimumDigits: Int = 1) throws -> [PositionalDigit] {
        let characters = Array(try representation(base: base, minimumDigits: minimumDigits))
        return characters.enumerated().map { offset, symbol in
            let exponent = characters.count - offset - 1
            let placeValue = (0..<exponent).reduce(1) { product, _ in product * base }
            let digit = Self.digitValue(for: symbol)!
            return PositionalDigit(
                digit: digit,
                symbol: String(symbol),
                exponent: exponent,
                placeValue: placeValue,
                contribution: digit * placeValue
            )
        }
    }

    /// Parse bare digits; prefixes such as `0x` are deliberately omitted from the learning surface.
    public static func parse(_ text: String, base: Int) throws -> RadixNumber {
        guard (2...16).contains(base) else { throw RadixError.invalidBase(base) }
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw RadixError.empty }

        // Validate every symbol before considering magnitude, so mistakes are explained consistently.
        let digits = try input.map { symbol -> Int in
            guard let digit = digitValue(for: symbol), digit < base else {
                throw RadixError.invalidDigit(String(symbol), base: base)
            }
            return digit
        }
        var result = 0
        for digit in digits {
            // This bounded comparison avoids arithmetic overflow even for extremely long input.
            guard result <= (255 - digit) / base else { throw RadixError.outOfRange }
            result = result * base + digit
        }
        return RadixNumber(result)
    }

    public var incremented: RadixNumber { RadixNumber((value + 1) & 0xFF) }
    public var decremented: RadixNumber { RadixNumber((value + 255) & 0xFF) }

    /// Carries travel from the one's place leftward. A full byte wraps back to zero.
    public var incrementTransition: RadixIncrementTransition {
        var clearedBits: [Int] = []
        var nextBit = 0
        while nextBit < 8, value & (1 << nextBit) != 0 {
            clearedBits.append(nextBit)
            nextBit += 1
        }
        let overflow = nextBit == 8
        let explanation: String
        if overflow {
            explanation = "All 8 bits are 1. Adding 1 carries beyond this byte, so 255 wraps to 0. The next number, 256, needs a ninth bit."
        } else if clearedBits.isEmpty {
            explanation = "The rightmost bit is 0. Adding 1 switches it on: \(value) becomes \(value + 1)."
        } else {
            let count = clearedBits.count
            let bitWord = count == 1 ? "bit" : "bits"
            explanation = "The rightmost \(count) \(bitWord) \(count == 1 ? "is" : "are") 1. Reset \(count == 1 ? "it" : "them") to 0 and carry into the \(1 << nextBit) place: \(value) becomes \(value + 1)."
        }
        return RadixIncrementTransition(
            before: self,
            after: incremented,
            turnedOffBitIndices: clearedBits,
            turnedOnBitIndex: overflow ? nil : nextBit,
            isOverflow: overflow,
            explanation: explanation
        )
    }

    /// Flip one bit at a time, starting at the one's place. An unfinished byte is meaningful
    /// only together with its pending carry (addition) or debt (subtraction).
    public func arithmeticTrace(_ operation: RadixStepOperation) -> RadixArithmeticTrace {
        var working = self
        var steps: [RadixArithmeticStep] = []
        for bitIndex in 0..<8 {
            let weight = 1 << bitIndex
            let wasOn = working.value & weight != 0
            let before = working
            working.toggleBit(index: bitIndex)

            let continues: Bool
            let explanation: String
            switch operation {
            case .increment:
                continues = wasOn
                if continues {
                    let carry = weight * 2
                    let destination = bitIndex == 7 ? "beyond this byte" : "to the next place"
                    explanation = "Bit \(bitIndex) is 1. Clear it and carry \(carry) \(destination). Working bits \(working.binary) (\(working.value)) plus the pending carry \(carry) still equal \(value) + 1. This is an unfinished working state."
                } else {
                    explanation = "Bit \(bitIndex) is 0. Set it to absorb the pending \(weight). No carry remains: the working bits \(working.binary) are the completed result, \(working.value)."
                }
            case .decrement:
                continues = !wasOn
                if continues {
                    let debt = weight * 2
                    let destination = bitIndex == 7 ? "beyond this byte" : "to the next place"
                    explanation = "Bit \(bitIndex) is 0. Fill it with 1 and pass a debt of \(debt) \(destination). Working bits \(working.binary) (\(working.value)) minus the pending debt \(debt) still equal \(value) − 1. This is an unfinished working state."
                } else {
                    explanation = "Bit \(bitIndex) is 1. Clear it to repay the pending debt \(weight). No debt remains: the working bits \(working.binary) are the completed result, \(working.value)."
                }
            }
            steps.append(RadixArithmeticStep(
                bitIndex: bitIndex,
                before: before,
                after: working,
                pendingWeight: continues ? weight * 2 : nil,
                explanation: explanation,
                isBoundary: false
            ))
            if !continues { break }
        }

        let isWrap = steps.last?.pendingWeight == 256
        let explanation: String
        if isWrap {
            switch operation {
            case .increment:
                explanation = "The carry of 256 needs a ninth bit. This 8-bit byte drops that outside carry, so 255 + 1 wraps to 0. The completed bits are \(working.binary)."
            case .decrement:
                explanation = "The debt of 256 has reached beyond all eight bits. The working bits were 255 with a debt of 256, representing −1. This unsigned byte drops that outside debt, so 0 − 1 wraps to 255. The completed bits are \(working.binary)."
            }
            steps.append(RadixArithmeticStep(
                bitIndex: nil,
                before: working,
                after: working,
                pendingWeight: nil,
                explanation: explanation,
                isBoundary: true
            ))
        } else {
            switch operation {
            case .increment:
                explanation = "Add 1 to \(value): flip bits from right to left until the carry is absorbed. Unfinished working bits must be read with their pending carry. The completed result is \(working.value) (\(working.binary))."
            case .decrement:
                explanation = "Subtract 1 from \(value): flip bits from right to left until the borrow debt is repaid. Unfinished working bits must be read with their pending debt. The completed result is \(working.value) (\(working.binary))."
            }
        }
        return RadixArithmeticTrace(
            before: self,
            after: working,
            operation: operation,
            steps: steps,
            explanation: explanation,
            isWrap: isWrap
        )
    }

    public func applying(_ operation: BitOperation, operand: RadixNumber = RadixNumber(0)) -> RadixNumber {
        switch operation {
        case .and: return RadixNumber(value & operand.value)
        case .or: return RadixNumber(value | operand.value)
        case .xor: return RadixNumber(value ^ operand.value)
        case .not: return RadixNumber(value ^ 0xFF)
        }
    }

    /// Bits that move beyond the byte disappear; newly opened places contain zero.
    public func shiftedLeft(by count: Int = 1) -> RadixNumber {
        guard count > 0 else { return self }
        guard count < 8 else { return RadixNumber(0) }
        return RadixNumber((value << count) & 0xFF)
    }

    public func shiftedRight(by count: Int = 1) -> RadixNumber {
        guard count > 0 else { return self }
        guard count < 8 else { return RadixNumber(0) }
        return RadixNumber(value >> count)
    }

    private static func validate(base: Int, minimumDigits: Int) throws {
        guard (2...16).contains(base) else { throw RadixError.invalidBase(base) }
        guard (0...8).contains(minimumDigits) else { throw RadixError.invalidDigitCount(minimumDigits) }
    }

    private static func digitValue(for symbol: Character) -> Int? {
        guard let ascii = symbol.asciiValue else { return nil }
        switch ascii {
        case 48...57: return Int(ascii - 48)
        case 65...70: return Int(ascii - 65) + 10
        case 97...102: return Int(ascii - 97) + 10
        default: return nil
        }
    }
}

public struct RadixBit: Equatable, Hashable, Sendable {
    public let bitIndex: Int
    public let weight: Int
    public let isOn: Bool
}

public struct PositionalDigit: Equatable, Hashable, Sendable {
    public let digit: Int
    public let symbol: String
    public let exponent: Int
    public let placeValue: Int
    public let contribution: Int
}

public struct RadixIncrementTransition: Equatable, Sendable {
    public let before: RadixNumber
    public let after: RadixNumber
    public let turnedOffBitIndices: [Int]
    public let turnedOnBitIndex: Int?
    public let isOverflow: Bool
    public let explanation: String
}

public enum RadixStepOperation: Equatable, Sendable {
    case increment
    case decrement
}

public struct RadixArithmeticTrace: Equatable, Sendable {
    public let before: RadixNumber
    public let after: RadixNumber
    public let operation: RadixStepOperation
    public let steps: [RadixArithmeticStep]
    public let explanation: String
    public let isWrap: Bool
}

public struct RadixArithmeticStep: Equatable, Sendable {
    /// Zero is the rightmost bit. Nil denotes the terminal resolution outside this byte.
    public let bitIndex: Int?
    public let before: RadixNumber
    public let after: RadixNumber
    /// Outgoing carry/debt after this step; nil means the arithmetic is resolved.
    /// Before a wrap is resolved, this can reach 256 while `after` stays within 0...255.
    public let pendingWeight: Int?
    public let explanation: String
    public let isBoundary: Bool
}

public enum BitOperation: String, CaseIterable, Identifiable, Sendable {
    case and = "AND"
    case or = "OR"
    case xor = "XOR"
    case not = "NOT"

    public var id: String { rawValue }
    public var explanation: String {
        switch self {
        case .and: "A place stays on only when both inputs have a 1 there."
        case .or: "A place is on when either input has a 1 there."
        case .xor: "A place is on when exactly one input has a 1 there."
        case .not: "Every 0 becomes 1 and every 1 becomes 0, within these 8 bits."
        }
    }
}

public enum RadixError: Error, Equatable, LocalizedError, Sendable {
    case invalidBase(Int)
    case invalidDigitCount(Int)
    case empty
    case invalidDigit(String, base: Int)
    case outOfRange

    public var errorDescription: String? {
        switch self {
        case .invalidBase:
            "Choose a base from 2 to 16."
        case .invalidDigitCount:
            "Choose between 0 and 8 digit places for this byte."
        case .empty:
            "Enter a number to explore."
        case let .invalidDigit(symbol, base):
            "“\(symbol)” is not a digit in base \(base). Use \(Self.allowedDigits(base: base))."
        case .outOfRange:
            "Keep the value between 0 and 255. Larger numbers need more than 8 bits."
        }
    }

    private static func allowedDigits(base: Int) -> String {
        let last = base <= 10 ? String(base - 1) : String(UnicodeScalar(65 + base - 11)!)
        if base <= 10 { return "0–\(last)" }
        return base == 11 ? "0–9 and A" : "0–9 and A–\(last)"
    }
}
