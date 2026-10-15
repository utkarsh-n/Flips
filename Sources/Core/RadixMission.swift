/// Build a quantity with the live bits. The same number remains visible in every base.
public struct RadixMission: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let prompt: String
    public let hint: String
    public let explanation: String
    public let target: Int

    public func isSatisfied(by number: RadixNumber) -> Bool { number.value == target }

    public static let catalog: [RadixMission] = [
        RadixMission(
            id: "first-spark", title: "First spark",
            prompt: "Switch on the smallest bit. Make 1.",
            hint: "The rightmost place is worth 1.",
            explanation: "Binary 00000001 is decimal 1. One active place contributes one.", target: 1
        ),
        RadixMission(
            id: "two-places", title: "Two places",
            prompt: "Make 3 using two bits.",
            hint: "Combine the 2 place and the 1 place.",
            explanation: "Binary 00000011 means 2 + 1. Each place is worth twice the one on its right.", target: 3
        ),
        RadixMission(
            id: "one-big-bit", title: "One big bit",
            prompt: "Make 8 with just one active bit.",
            hint: "Look for the place labeled 8.",
            explanation: "Binary 00001000 is 8. A digit's position decides its value.", target: 8
        ),
        RadixMission(
            id: "mix-the-weights", title: "Mix the weights",
            prompt: "Make 13 from three active places.",
            hint: "Start with 8, then find the 5 that remains.",
            explanation: "Binary 00001101 means 8 + 4 + 1 = 13. Its hex digit is D.", target: 13
        ),
        RadixMission(
            id: "fill-a-nibble", title: "Fill a nibble",
            prompt: "Turn on all four bits on the right. Make 15.",
            hint: "Add 8 + 4 + 2 + 1.",
            explanation: "Four bits are a nibble. Binary 1111 is decimal 15 and hex F.", target: 15
        ),
        RadixMission(
            id: "cross-the-boundary", title: "Cross the boundary",
            prompt: "Make 16. Watch the hex number gain a new place.",
            hint: "One bit worth 16 replaces the four smaller places.",
            explanation: "Binary 00010000 is hex 10: one sixteen and zero ones. The base changes the place values.", target: 16
        ),
        RadixMission(
            id: "two-hex-digits", title: "Two hex digits",
            prompt: "Build hex 2A. That is decimal 42.",
            hint: "Use 32 + 8 + 2. The left nibble is 2; the right is A (10).",
            explanation: "Hex 2A means 2 × 16 + 10 = 42. Each hex digit describes exactly four binary bits.", target: 42
        ),
        RadixMission(
            id: "alternating", title: "An alternating byte",
            prompt: "Make the pattern 10101010.",
            hint: "Switch on 128, 32, 8, and 2.",
            explanation: "The two nibbles are both 1010, so the hex representation is AA. Their total is 170.", target: 170
        ),
        RadixMission(
            id: "ready-to-carry", title: "Ready to carry",
            prompt: "Make 127: fill every place except the largest.",
            hint: "Leave 128 off. Turn the other seven bits on.",
            explanation: "Binary 01111111 is 127. Add 1 in Bits to watch seven ones reset as the carry reaches 128.", target: 127
        ),
        RadixMission(
            id: "full-byte", title: "A full byte",
            prompt: "Fill all 8 places. Make the largest value this byte can hold.",
            hint: "Turn every bit on: 128 + 64 + 32 + 16 + 8 + 4 + 2 + 1.",
            explanation: "Binary 11111111 is decimal 255 and hex FF. Adding 1 needs a ninth bit; this 8-bit toy wraps to zero.", target: 255
        )
    ]
}
