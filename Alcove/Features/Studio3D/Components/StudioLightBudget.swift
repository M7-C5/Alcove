import Metal

/// Older GPUs have a per-object dynamic-light limit. Newer GPUs lift it.
enum StudioLightBudget {
    private static let supportsExtendedLights = MTLCreateSystemDefaultDevice()?.supportsFamily(.apple6) == true

    static func maximumFixtures(sunlightActive: Bool) -> Int? {
        limit(supportsExtendedLights: supportsExtendedLights, sunlightActive: sunlightActive)
    }

    static func limit(supportsExtendedLights: Bool, sunlightActive: Bool) -> Int? {
        supportsExtendedLights ? nil : (sunlightActive ? 7 : 8)
    }
}
