import Testing
import CoreGraphics
@testable import Blister

/// Unit tests for the pure ``TiltMath`` helper. No SwiftUI required.
struct TiltMathTests {

    private let size = CGSize(width: 300, height: 400)

    @Test func zeroTranslationGivesZeroAnglesAndCenteredSheen() {
        let angles = TiltMath.tiltAngles(for: .zero, in: size)
        #expect(angles.x == 0)
        #expect(angles.y == 0)

        let sheen = TiltMath.sheenOffset(for: angles)
        #expect(sheen == .zero)
    }

    @Test func largeTranslationClampsToMaxDegrees() {
        let max = 12.0
        let big = CGSize(width: 10_000, height: -10_000)
        let angles = TiltMath.tiltAngles(for: big, in: size, maxDegrees: max)
        #expect(angles.y == max)
        #expect(angles.x == max)

        let bigNeg = CGSize(width: -10_000, height: 10_000)
        let anglesNeg = TiltMath.tiltAngles(for: bigNeg, in: size, maxDegrees: max)
        #expect(anglesNeg.y == -max)
        #expect(anglesNeg.x == -max)
    }

    @Test func rightDragGivesPositiveYAngle() {
        let angles = TiltMath.tiltAngles(for: CGSize(width: 40, height: 0), in: size)
        #expect(angles.y > 0)
        #expect(angles.x == 0)
    }

    @Test func upDragGivesPositiveXAngle() {
        // Up is a negative height in screen coordinates.
        let angles = TiltMath.tiltAngles(for: CGSize(width: 0, height: -40), in: size)
        #expect(angles.x > 0)
        #expect(angles.y == 0)
    }

    @Test func downDragGivesNegativeXAngle() {
        let angles = TiltMath.tiltAngles(for: CGSize(width: 0, height: 40), in: size)
        #expect(angles.x < 0)
    }

    @Test func anglesAreProportionalToDrag() {
        let small = TiltMath.tiltAngles(for: CGSize(width: 20, height: 0), in: size)
        let large = TiltMath.tiltAngles(for: CGSize(width: 40, height: 0), in: size)
        #expect(large.y > small.y)
    }

    @Test func nonPositiveSizeYieldsZeroAngle() {
        let angles = TiltMath.tiltAngles(for: CGSize(width: 50, height: 50), in: .zero)
        #expect(angles.x == 0)
        #expect(angles.y == 0)
    }

    @Test func sheenSlidesRightWithPositiveYAngle() {
        let sheen = TiltMath.sheenOffset(for: (x: 0, y: 6), maxDegrees: 12, travel: 60)
        #expect(sheen.width > 0)
        #expect(sheen.height == 0)
    }

    @Test func sheenSlidesUpWithPositiveXAngle() {
        // Positive X (up drag) → highlight moves up → negative offset height.
        let sheen = TiltMath.sheenOffset(for: (x: 6, y: 0), maxDegrees: 12, travel: 60)
        #expect(sheen.height < 0)
        #expect(sheen.width == 0)
    }

    @Test func sheenMovesFartherAsTiltIncreases() {
        let low = TiltMath.sheenOffset(for: (x: 0, y: 3), maxDegrees: 12, travel: 60)
        let high = TiltMath.sheenOffset(for: (x: 0, y: 9), maxDegrees: 12, travel: 60)
        #expect(high.width > low.width)
    }

    @Test func sheenClampsToTravelAtMaxTilt() {
        let travel: CGFloat = 60
        let sheen = TiltMath.sheenOffset(for: (x: 0, y: 12), maxDegrees: 12, travel: travel)
        #expect(sheen.width == travel)
    }
}
