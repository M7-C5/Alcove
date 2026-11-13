import SwiftUI
import Testing
import UIKit
@testable import Alcove

@Suite("Alcove Color System Tests")
struct AlcoveColorsTests {
    @Test func allPaletteColorSetsResolveInAssetCatalog() {
        let assetNames = [
            "AlcoveBackground",
            "AlcoveBadgeGold",
            "AlcoveChipFill",
            "AlcoveChipShadow",
            "AlcoveInk",
            "AlcoveItemSurface",
            "AlcoveMutedInk",
            "AlcovePattern",
            "AlcovePrimaryFill",
            "AlcovePrimaryHighlight",
            "AlcovePrimaryShadow",
            "AlcoveProgressDone",
            "AlcoveProgressInactive",
            "AlcoveSecondaryShadow",
            "AlcoveSurface",
            "AlcoveSurfaceElevated"
        ]

        for name in assetNames {
            #expect(UIColor(named: name) != nil, "Color set '\(name)' should resolve from Assets.xcassets")
        }
    }

    @Test func semanticColorAliasesMatchBasePaletteTokens() {
        #expect(UIColor(Color.alcoveText) == UIColor(Color.alcoveInk))
        #expect(UIColor(Color.alcoveBorder) == UIColor(Color.alcoveInk))
        #expect(UIColor(Color.alcoveSecondaryFill) == UIColor(Color.alcoveBackground))
        #expect(UIColor(Color.alcoveSecondaryMid) == UIColor(Color.alcovePattern))
        #expect(UIColor(Color.alcoveChipHighlight) == UIColor(Color.alcoveBackground))
        #expect(UIColor(Color.alcoveBubbleFill) == UIColor(Color.alcoveBackground))
        #expect(UIColor(Color.alcoveAlertSurface) == UIColor(Color.alcoveSurface))
        #expect(UIColor(Color.alcoveContainerSurface) == UIColor(Color.alcoveSurface))
        #expect(UIColor(Color.alcoveProgressActive) == UIColor(Color.alcovePrimaryFill))
    }
}
