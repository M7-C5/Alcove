import Foundation
import Testing
import UIKit
@testable import Alcove

@Suite("Cleanow Font Tests")
struct CleanowFontTests {
    @Test func cleanowFontLoadsSuccessfully() {
        FontRegistrar.registerCustomFonts()
        let font = UIFont(name: "Cleanow", size: 24)
        #expect(font != nil, "Cleanow font should be loadable by name 'Cleanow'")
    }
}
