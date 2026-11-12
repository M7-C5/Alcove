import Foundation
import CoreText
import UIKit

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
        var searchedBundles: [Bundle] = [Bundle.main, Bundle(for: BundleToken.self)]
        searchedBundles.append(contentsOf: Bundle.allBundles)

        for bundle in searchedBundles {
            let directURL = bundle.url(forResource: "cleanow", withExtension: "ttf")
            let subURL = bundle.url(forResource: "cleanow", withExtension: "ttf", subdirectory: "Resources/Fonts")
            let allTTFs = bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []

            let candidates = [directURL, subURL] + allTTFs.filter { $0.lastPathComponent.lowercased().contains("cleanow") }
            for url in candidates.compactMap({ $0 }) {
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    return
                }
            }
        }
    }
}

private final class BundleToken {}
