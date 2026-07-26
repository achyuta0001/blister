#if DEBUG
import Testing
import UIKit
@testable import Blister

/// DEBUG-only smoke test: runs the real cleanup pipeline and writes its stages to the simulator's
/// Documents dir so a human can eyeball the result. Not a correctness assertion (Vision quality
/// varies by device/OS) — a manual inspection harness.
///
/// Two fixtures, because the two isolation paths have different simulator support:
/// - `car_test.jpg`, a loose car with no card → falls through to
///   `VNGenerateForegroundInstanceMaskRequest`, which cannot build an inference context in the
///   simulator (returns nil by design; verify on a device).
/// - a synthetic hand-held card → takes the `CardDetector` path, which is classical CV and **does**
///   run in the simulator, so the card-crop intermediate is real output.
struct PhotoCleanupSmokeTest {

    @Test func liftsCarOntoStudioBackdrop() async throws {
        let bundle = Bundle(identifier: "com.blister.app.BlisterTests")
        let url = try #require(bundle?.url(forResource: "car_test", withExtension: "jpg"),
                               "car_test.jpg missing from test bundle")
        let original = try #require(UIImage(contentsOfFile: url.path), "could not decode test image")

        let cleaned = await PhotoCleanup.cleaned(original)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try original.pngData()?.write(to: docs.appendingPathComponent("cleanup_before.png"))
        if let cleaned, let data = cleaned.pngData() {
            try data.write(to: docs.appendingPathComponent("cleanup_after.png"))
        }
        print("PHOTOCLEANUP_DOCS_DIR=\(docs.path)")
        print("PHOTOCLEANUP_RESULT=\(cleaned == nil ? "nil-no-subject" : "composited")")
    }
}
#endif
