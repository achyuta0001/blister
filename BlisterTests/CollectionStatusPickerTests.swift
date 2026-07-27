import CoreGraphics
import SwiftUI
import Testing
@testable import Blister

/// Pins the Garage / Wishlist segments to ``DesignTokens/minTapTarget``.
///
/// UIKit renders a `.segmented` picker at its own 32pt metric. The row *looked* like it had been
/// given room — `.padding(.vertical, spacingXS)` on the enclosing `VStack` — but padding grows the
/// form row while leaving the segments' hit area at 32pt, which is the failure this measures: it
/// subtracts the row's known chrome back off and checks what is left for the control itself, so
/// re-adding padding instead of sizing the control cannot make it pass.
@MainActor
struct CollectionStatusPickerTests {

    @Test func theSegmentsAreAtLeastAsTallAsTheMinimumTapTarget() throws {
        let title = "Add to"
        let width: CGFloat = 320

        let row = try #require(Self.renderedHeight(
            of: CollectionStatusPicker(title: title, selection: .constant(.owned)), width: width
        ), "ImageRenderer produced nothing for CollectionStatusPicker")
        let caption = try #require(Self.renderedHeight(
            of: Text(title).font(.caption), width: width
        ), "ImageRenderer produced nothing for the caption")

        // What the row spends on anything that is not the control: the `VStack` spacing under the
        // caption, plus the row's own vertical padding above and below.
        let chrome = DesignTokens.spacingXS * 3
        let control = row - caption - chrome
        print("PICKER_HEIGHTS row=\(row) caption=\(caption) control=\(control)")

        #expect(control >= DesignTokens.minTapTarget,
                "segments are \(control)pt, under the \(DesignTokens.minTapTarget)pt tap target")
    }

    private static func renderedHeight(of view: some View, width: CGFloat) -> CGFloat? {
        let renderer = ImageRenderer(content: view.frame(width: width))
        renderer.scale = 1
        guard let rendered = renderer.uiImage?.cgImage else { return nil }
        return CGFloat(rendered.height)
    }
}
