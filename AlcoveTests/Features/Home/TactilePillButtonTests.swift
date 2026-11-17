import SwiftUI
import Testing
@testable import Alcove

@Suite("Tactile button accessibility") @MainActor
struct TactilePillButtonTests {
    @Test func compactButtonGrowsWithAccessibilityTextSize() throws {
        func height(at size: DynamicTypeSize) throws -> CGFloat {
            let button = TactilePillButton(title: "Add light", size: .compact, appearance: .cream,
                                           systemImage: "plus.circle", action: {})
                .environment(\.dynamicTypeSize, size)
            return try #require(ImageRenderer(content: VStack { button }).uiImage).size.height
        }
        let standard = try height(at: .large)
        let accessibility = try height(at: .accessibility3)
        #expect(abs(standard - 48) < 1)
        #expect(accessibility > standard, "Rendered heights: standard=\(standard), accessibility=\(accessibility)")
    }
}
