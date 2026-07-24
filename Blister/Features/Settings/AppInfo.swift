import Foundation

/// Reads the app's marketing version and build number from the bundle's Info.plist (spec §6.6).
enum AppInfo {
    /// e.g. `"1.0 (12)"`. Falls back to an em dash for any missing key rather than force-unwrapping.
    static var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (short?, build?): return "\(short) (\(build))"
        case let (short?, nil):    return short
        case let (nil, build?):    return build
        case (nil, nil):           return "—"
        }
    }
}
