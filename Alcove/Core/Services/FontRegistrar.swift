import Foundation
import CoreText

/// Registers embedded custom fonts dynamically into the system font registry.
public enum FontRegistrar: Sendable {
    private static let isRegistered: Bool = {
        registerFonts()
        return true
    }()

    /// Ensures all custom fonts (e.g. Cleanow) are registered for UIFont and SwiftUI Font.
    public static func registerCustomFonts() {
        _ = isRegistered
    }

    private static func registerFonts() {
        var seenBundles = Set<URL>()
        let candidateBundles = ([Bundle.main, Bundle(for: BundleToken.self)] + Bundle.allBundles)
            .filter { seenBundles.insert($0.bundleURL).inserted }

        var seenFontURLs = Set<URL>()
        for bundle in candidateBundles {
            let directURL = bundle.url(forResource: "cleanow", withExtension: "ttf")
            let subURL = bundle.url(forResource: "cleanow", withExtension: "ttf", subdirectory: "Resources/Fonts")
            let allTTFs = bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []

            let candidates = ([directURL, subURL] + allTTFs.filter {
                $0.lastPathComponent.lowercased().contains("cleanow")
            })
            .compactMap { $0 }
            .filter { seenFontURLs.insert($0).inserted }

            for url in candidates {
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    return
                }
                if let cfError = error?.takeRetainedValue(),
                   CFErrorGetDomain(cfError) as String == kCTFontManagerErrorDomain as String,
                   CFErrorGetCode(cfError) == CTFontManagerError.alreadyRegistered.rawValue {
                    return
                }
            }
        }
    }
}

private final class BundleToken {}
