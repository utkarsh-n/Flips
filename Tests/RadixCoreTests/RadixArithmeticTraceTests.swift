import XCTest
@testable import RadixCore

final class RadixArithmeticTraceTests: XCTestCase {
    func testEveryIncrementTracePreservesArithmeticWhileCarrying() {
        assertEveryTrace(.increment)
    }

    func testEveryDecrementTracePreservesArithmeticWhileBorrowing() {
        assertEveryTrace(.decrement)
    }

    func testCarryShowsWorkingBitsRatherThanPretendingEachIsAResult() {
        let trace = RadixNumber(7).arithmeticTrace(.increment)
        XCTAssertEqual(trace.steps.map(\.before.value), [7, 6, 4, 0])
        XCTAssertEqual(trace.steps.map(\.after.value), [6, 4, 0, 8])
        XCTAssertEqual(trace.steps.map(\.pendingWeight), [2, 4, 8, nil])
        XCTAssertTrue(trace.steps.dropLast().allSatisfy {
            $0.explanation.contains("Working bits") && $0.explanation.contains("pending carry")
        })
        XCTAssertTrue(trace.steps.last!.explanation.contains("completed result, 8"))
    }

    func testBorrowShowsGrowingWorkingByteAndPendingDebt() {
        let trace = RadixNumber(8).arithmeticTrace(.decrement)
        XCTAssertEqual(trace.steps.map(\.before.value), [8, 9, 11, 15])
        XCTAssertEqual(trace.steps.map(\.after.value), [9, 11, 15, 7])
        XCTAssertEqual(trace.steps.map(\.pendingWeight), [2, 4, 8, nil])
        XCTAssertTrue(trace.steps.dropLast().allSatisfy {
            $0.explanation.contains("Working bits") && $0.explanation.contains("pending debt")
        })
        XCTAssertTrue(trace.steps.last!.explanation.contains("completed result, 7"))
    }

    func testWrapsKeepOutsideCarryOrDebtUntilExplicitBoundaryResolution() {
        let carry = RadixNumber(255).arithmeticTrace(.increment)
        XCTAssertEqual(carry.steps.map(\.after.value), [254, 252, 248, 240, 224, 192, 128, 0, 0])
        XCTAssertEqual(carry.steps.map(\.pendingWeight), [2, 4, 8, 16, 32, 64, 128, 256, nil])
        XCTAssertTrue(carry.steps.last!.explanation.contains("ninth bit"))
        XCTAssertTrue(carry.explanation.contains("255 + 1 wraps to 0"))

        let borrow = RadixNumber(0).arithmeticTrace(.decrement)
        XCTAssertEqual(borrow.steps.map(\.after.value), [1, 3, 7, 15, 31, 63, 127, 255, 255])
        XCTAssertEqual(borrow.steps.map(\.pendingWeight), [2, 4, 8, 16, 32, 64, 128, 256, nil])
        XCTAssertTrue(borrow.steps.last!.explanation.contains("representing −1"))
        XCTAssertTrue(borrow.explanation.contains("0 − 1 wraps to 255"))
    }

    private func assertEveryTrace(
        _ operation: RadixStepOperation,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let delta = operation == .increment ? 1 : -1
        for value in 0...255 {
            let source = RadixNumber(value)
            let arithmeticResult = value + delta
            let expected = (arithmeticResult + 256) % 256
            let expectedWrap = !(0...255).contains(arithmeticResult)
            let trace = source.arithmeticTrace(operation)
            let context = "\(value), \(operation)"
            XCTAssertEqual(trace.before, source, context, file: file, line: line)
            XCTAssertEqual(trace.after.value, expected, context, file: file, line: line)
            XCTAssertEqual(trace.operation, operation, context, file: file, line: line)
            XCTAssertEqual(trace.isWrap, expectedWrap, context, file: file, line: line)
            XCTAssertFalse(trace.explanation.isEmpty, context, file: file, line: line)
            XCTAssertTrue((1...9).contains(trace.steps.count), context, file: file, line: line)

            // Final arithmetic independently identifies the highest changed place.
            let changedPlaces = value ^ expected
            let highestChangedBit = Int.bitWidth - changedPlaces.leadingZeroBitCount - 1
            let expectedIndices = Array(0...highestChangedBit)
            XCTAssertEqual(trace.steps.compactMap(\.bitIndex), expectedIndices, context, file: file, line: line)
            XCTAssertEqual(trace.steps.count, expectedIndices.count + (expectedWrap ? 1 : 0), context, file: file, line: line)

            var previous = source
            for (offset, step) in trace.steps.enumerated() {
                XCTAssertEqual(step.before, previous, context, file: file, line: line)
                XCTAssertTrue((0...255).contains(step.before.value), context, file: file, line: line)
                XCTAssertTrue((0...255).contains(step.after.value), context, file: file, line: line)
                XCTAssertFalse(step.explanation.isEmpty, context, file: file, line: line)
                let isLast = offset == trace.steps.count - 1
                XCTAssertEqual(step.pendingWeight == nil, isLast, context, file: file, line: line)
                if let bitIndex = step.bitIndex {
                    XCTAssertFalse(step.isBoundary, context, file: file, line: line)
                    XCTAssertEqual(step.before.value ^ step.after.value, 1 << bitIndex, context, file: file, line: line)
                    XCTAssertEqual(step.after.value + delta * (step.pendingWeight ?? 0), arithmeticResult, context, file: file, line: line)
                    if let pending = step.pendingWeight {
                        XCTAssertEqual(pending, 1 << (bitIndex + 1), context, file: file, line: line)
                        XCTAssertTrue((2...256).contains(pending), context, file: file, line: line)
                    }
                } else {
                    XCTAssertTrue(expectedWrap && isLast && step.isBoundary, context, file: file, line: line)
                    XCTAssertEqual(step.before, step.after, context, file: file, line: line)
                    XCTAssertEqual(step.after.value, expected, context, file: file, line: line)
                }
                previous = step.after
            }
            XCTAssertEqual(previous, trace.after, context, file: file, line: line)
        }
    }
}
