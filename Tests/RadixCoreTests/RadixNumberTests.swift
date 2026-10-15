import XCTest
@testable import RadixCore

final class RadixNumberTests: XCTestCase {
    func testKnownRepresentationsAndNibbleRelationship() throws {
        let number = RadixNumber(42)
        XCTAssertEqual(number.binary, "00101010")
        XCTAssertEqual(number.hexadecimal, "2A")
        XCTAssertEqual(number.decimal, "42")
        XCTAssertEqual(number.highNibble, 2)
        XCTAssertEqual(number.lowNibble, 10)
        XCTAssertEqual(try number.representation(base: 8), "52")
        XCTAssertEqual(try number.representation(base: 3), "1120")
        XCTAssertEqual(RadixNumber(0).binary, "00000000")
        XCTAssertEqual(RadixNumber(0).hexadecimal, "00")
        XCTAssertEqual(RadixNumber(255).binary, "11111111")
        XCTAssertEqual(RadixNumber(255).hexadecimal, "FF")
    }

    func testByteRangeIsAlwaysBounded() {
        XCTAssertEqual(RadixNumber(-1).value, 0)
        XCTAssertEqual(RadixNumber(Int.min).value, 0)
        XCTAssertEqual(RadixNumber(256).value, 255)
        XCTAssertEqual(RadixNumber(Int.max).value, 255)
    }

    func testToggleUsesRightmostBitAsZeroAndDisplayUsesMSBFirst() {
        var number = RadixNumber(0)
        number.toggleBit(index: 0)
        number.toggleBit(index: 7)
        XCTAssertEqual(number.value, 129)
        XCTAssertEqual(number.bits.map(\.bitIndex), [7, 6, 5, 4, 3, 2, 1, 0])
        XCTAssertEqual(number.bits.map(\.weight), [128, 64, 32, 16, 8, 4, 2, 1])
        XCTAssertEqual(number.bits.map(\.isOn), [true, false, false, false, false, false, false, true])
        number.toggleBit(index: -1)
        number.toggleBit(index: 8)
        XCTAssertEqual(number.value, 129)
        XCTAssertEqual(number.togglingBit(index: 0).value, 128)
        XCTAssertEqual(number.value, 129, "The nonmutating operation preserves its input.")
    }

    func testEveryByteRoundTripsThroughEverySupportedBase() throws {
        for value in 0...255 {
            let number = RadixNumber(value)
            for base in 2...16 {
                let representation = try number.representation(base: base)
                XCTAssertEqual(try RadixNumber.parse(representation, base: base), number)
                let positions = try number.positionalDigits(base: base)
                XCTAssertEqual(positions.reduce(0) { $0 + $1.contribution }, value)
                XCTAssertTrue(positions.allSatisfy { (0..<base).contains($0.digit) })
            }
            XCTAssertEqual(number.highNibble * 16 + number.lowNibble, value)
            XCTAssertEqual(try RadixNumber.parse(number.binary, base: 2), number)
            XCTAssertEqual(try RadixNumber.parse(number.hexadecimal, base: 16), number)
        }
    }

    func testPositionalExplanationIncludesZeroPlacesAndPadding() throws {
        let decimal = try RadixNumber(105).positionalDigits(base: 10)
        XCTAssertEqual(decimal.map(\.symbol), ["1", "0", "5"])
        XCTAssertEqual(decimal.map(\.placeValue), [100, 10, 1])
        XCTAssertEqual(decimal.map(\.contribution), [100, 0, 5])
        let hex = try RadixNumber(42).positionalDigits(base: 16, minimumDigits: 2)
        XCTAssertEqual(hex.map(\.digit), [2, 10])
        XCTAssertEqual(hex.map(\.exponent), [1, 0])
        XCTAssertEqual(hex.map(\.contribution), [32, 10])
        let binary = try RadixNumber(3).positionalDigits(base: 2, minimumDigits: 8)
        XCTAssertEqual(binary.count, 8)
        XCTAssertEqual(binary.map(\.contribution), [0, 0, 0, 0, 0, 0, 2, 1])
    }

    func testParserExplainsInvalidInputAndCannotOverflow() throws {
        XCTAssertEqual(try RadixNumber.parse("  fF\n", base: 16).value, 255)
        XCTAssertEqual(try RadixNumber.parse("00000000255", base: 10).value, 255)
        assertError(.empty) { try RadixNumber.parse(" \n", base: 2) }
        assertError(.invalidBase(1)) { try RadixNumber.parse("0", base: 1) }
        assertError(.invalidBase(17)) { try RadixNumber.parse("0", base: 17) }
        assertError(.invalidDigit("2", base: 2)) { try RadixNumber.parse("102", base: 2) }
        assertError(.invalidDigit("G", base: 16)) { try RadixNumber.parse("G", base: 16) }
        assertError(.invalidDigit("-", base: 10)) { try RadixNumber.parse("-1", base: 10) }
        assertError(.invalidDigit("１", base: 10)) { try RadixNumber.parse("１", base: 10) }
        assertError(.invalidDigit("A\u{FE0F}", base: 16)) { try RadixNumber.parse("A\u{FE0F}", base: 16) }
        assertError(.invalidDigit(" ", base: 10)) { try RadixNumber.parse("1 2", base: 10) }
        assertError(.outOfRange) { try RadixNumber.parse("100000000", base: 2) }
        assertError(.outOfRange) { try RadixNumber.parse("100", base: 16) }
        assertError(.outOfRange) { try RadixNumber.parse(String(repeating: "9", count: 10_000), base: 10) }
        XCTAssertTrue(RadixError.invalidDigit("A", base: 10).localizedDescription.contains("0–9"))
        XCTAssertTrue(RadixError.invalidDigit("G", base: 16).localizedDescription.contains("A–F"))
    }

    func testRepresentationRejectsInvalidParameters() {
        assertError(.invalidBase(0)) { try RadixNumber(0).representation(base: 0) }
        assertError(.invalidDigitCount(-1)) { try RadixNumber(0).representation(base: 2, minimumDigits: -1) }
        assertError(.invalidDigitCount(9)) { try RadixNumber(0).positionalDigits(base: 16, minimumDigits: 9) }
    }

    func testCarryTransitionsTellTheStoryOfIncrementing() {
        let noCarry = RadixNumber(42).incrementTransition
        XCTAssertEqual(noCarry.after.value, 43)
        XCTAssertEqual(noCarry.turnedOffBitIndices, [])
        XCTAssertEqual(noCarry.turnedOnBitIndex, 0)
        XCTAssertFalse(noCarry.isOverflow)

        let boundary = RadixNumber(15).incrementTransition
        XCTAssertEqual(boundary.before.hexadecimal, "0F")
        XCTAssertEqual(boundary.after.hexadecimal, "10")
        XCTAssertEqual(boundary.turnedOffBitIndices, [0, 1, 2, 3])
        XCTAssertEqual(boundary.turnedOnBitIndex, 4)
        XCTAssertTrue(boundary.explanation.contains("16 place"))

        let overflow = RadixNumber(255).incrementTransition
        XCTAssertEqual(overflow.after.value, 0)
        XCTAssertEqual(overflow.turnedOffBitIndices, Array(0...7))
        XCTAssertNil(overflow.turnedOnBitIndex)
        XCTAssertTrue(overflow.isOverflow)
        XCTAssertTrue(overflow.explanation.contains("ninth bit"))
        XCTAssertEqual(RadixNumber(0).decremented.value, 255)
    }

    func testEveryCarryExactlyExplainsTheChangedPlaces() {
        for value in 0...255 {
            let transition = RadixNumber(value).incrementTransition
            var reconstructed = transition.before
            for bitIndex in transition.turnedOffBitIndices {
                XCTAssertTrue(transition.before.bits.first { $0.bitIndex == bitIndex }!.isOn)
                reconstructed.toggleBit(index: bitIndex)
            }
            if let bitIndex = transition.turnedOnBitIndex {
                XCTAssertFalse(transition.before.bits.first { $0.bitIndex == bitIndex }!.isOn)
                reconstructed.toggleBit(index: bitIndex)
            }
            XCTAssertEqual(reconstructed, transition.after)
            XCTAssertEqual(transition.after.decremented, transition.before)
        }
    }

    func testLogicTruthTablesAndByteBoundaries() {
        let a = RadixNumber(0b10101010)
        let b = RadixNumber(0b11001100)
        XCTAssertEqual(a.applying(.and, operand: b).binary, "10001000")
        XCTAssertEqual(a.applying(.or, operand: b).binary, "11101110")
        XCTAssertEqual(a.applying(.xor, operand: b).binary, "01100110")
        XCTAssertEqual(a.applying(.not).binary, "01010101")
        for value in 0...255 {
            let number = RadixNumber(value)
            XCTAssertEqual(number.applying(.not).applying(.not), number)
            XCTAssertEqual(number.applying(.xor, operand: number).value, 0)
            XCTAssertEqual(number.applying(.or, operand: number), number)
            XCTAssertEqual(number.applying(.and, operand: RadixNumber(255)), number)
        }
    }

    func testShiftsDropOverflowAndIntroduceZeroBits() {
        XCTAssertEqual(RadixNumber(129).shiftedLeft().value, 2)
        XCTAssertEqual(RadixNumber(129).shiftedRight().value, 64)
        XCTAssertEqual(RadixNumber(255).shiftedLeft(by: 7).value, 128)
        XCTAssertEqual(RadixNumber(255).shiftedRight(by: 7).value, 1)
        XCTAssertEqual(RadixNumber(255).shiftedLeft(by: 8).value, 0)
        XCTAssertEqual(RadixNumber(255).shiftedRight(by: Int.max).value, 0)
        XCTAssertEqual(RadixNumber(42).shiftedLeft(by: -1).value, 42)
        XCTAssertEqual(RadixNumber(42).shiftedRight(by: 0).value, 42)
    }

    func testMissionsAreUniqueAchievableAndValidateTheLiveByte() {
        XCTAssertEqual(RadixMission.catalog.count, 10)
        XCTAssertEqual(Set(RadixMission.catalog.map(\.id)).count, 10)
        for mission in RadixMission.catalog {
            XCTAssertTrue((0...255).contains(mission.target))
            XCTAssertTrue(mission.isSatisfied(by: RadixNumber(mission.target)))
            XCTAssertFalse(mission.isSatisfied(by: RadixNumber((mission.target + 1) % 256)))
            XCTAssertFalse(mission.prompt.isEmpty)
            XCTAssertFalse(mission.hint.isEmpty)
            XCTAssertFalse(mission.explanation.isEmpty)
        }
    }

    private func assertError<T>(
        _ expected: RadixError,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () throws -> T
    ) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { error in
            XCTAssertEqual(error as? RadixError, expected, file: file, line: line)
        }
    }
}
