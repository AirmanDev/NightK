import Foundation

@main
struct DisplayCompatibilitySmoke {
    static func main() {
        let version272 = OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0)
        let version271 = OperatingSystemVersion(majorVersion: 27, minorVersion: 1, patchVersion: 0)
        let version273 = OperatingSystemVersion(majorVersion: 27, minorVersion: 3, patchVersion: 0)
        func resolve(_ method: DisplayMethod, _ model: String, _ version: OperatingSystemVersion) -> DisplayMethod {
            DisplayCompatibility.resolvedMethod(method, hardwareModel: model, osVersion: version)
        }
        precondition(resolve(.automatic, "Mac17,8", version272) == .compatibility)
        precondition(resolve(.automatic, "Mac17,8", version271) == .gamma)
        precondition(resolve(.automatic, "Mac17,8", version273) == .gamma)
        precondition(resolve(.automatic, "MacBookPro18,2", version272) == .gamma)
        precondition(resolve(.gamma, "Mac17,8", version272) == .gamma)
        precondition(resolve(.compatibility, "MacBookPro18,2", version271) == .compatibility)
        precondition(DisplayCompatibility.overlayOpacity(kelvin: 6500) == 0)
        precondition(DisplayCompatibility.overlayOpacity(kelvin: 1000) > DisplayCompatibility.overlayOpacity(kelvin: 1400))
        precondition(DisplayCompatibility.overlayOpacity(kelvin: 1400) > DisplayCompatibility.overlayOpacity(kelvin: 4000))
        precondition(DisplayCompatibility.overlayOpacity(kelvin: 10) == DisplayCompatibility.overlayOpacity(kelvin: 1000))
        precondition(DisplayCompatibility.overlayOpacity(kelvin: 99999) == 0)
        precondition(DisplayCompatibility.overlayOpacity(kelvin: 1400) < 0.30)
        print("DISPLAY_COMPATIBILITY_TESTS_PASS (12 assertions)")
    }
}
