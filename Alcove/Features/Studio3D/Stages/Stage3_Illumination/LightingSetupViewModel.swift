import Foundation
import Observation
import SwiftData

/// Value drafts keep slider and placement changes out of SwiftData until Save.
@Observable @MainActor
final class LightingSetupViewModel {
    private(set) var drafts: [LightFixture]
    private(set) var selectedIDs: Set<UUID> = []
    private(set) var isSelectingMultiple = false
    var selectedID: UUID? {
        get { selected?.id }
        set { selectedIDs = Set(newValue.map { [$0] } ?? []) }
    }
    let geometry: LightingRoomGeometry
    private var originalLayoutID: UUID?
    private var savedDrafts: [LightFixture]
    private(set) var placementKind: LightKind = .ceilingLight

    init(room: Room) {
        geometry = LightingRoomGeometry(width: room.dimensionsWidth, length: room.dimensionsLength,
                                        height: room.dimensionsHeight)
        originalLayoutID = room.workingLayout?.id
        let fixtures = room.workingLayout?.lightFixtures ?? room.baselineLayout?.lightFixtures ?? []
        drafts = fixtures
        savedDrafts = fixtures
    }

    var selected: LightFixture? { drafts.first { selectedIDs.contains($0.id) } }
    var selectedFixtures: [LightFixture] { drafts.filter { selectedIDs.contains($0.id) } }
    var selectionCount: Int { selectedFixtures.count }
    var hasUnsavedChanges: Bool { drafts != savedDrafts }
    var commonKind: LightKind? { commonValue(\.resolvedKind) }
    var commonTemperature: Int? { commonValue(\.colorTemperatureKelvin) }
    var commonBrightness: Double? { commonValue(\.lumens) }

    private func commonValue<Value: Equatable>(_ keyPath: KeyPath<LightFixture, Value>) -> Value? {
        guard let first = selected else { return nil }
        let value = first[keyPath: keyPath]
        return selectedFixtures.allSatisfy { $0[keyPath: keyPath] == value } ? value : nil
    }

    func select(_ id: UUID) {
        guard drafts.contains(where: { $0.id == id }) else { return }
        if isSelectingMultiple {
            if !selectedIDs.insert(id).inserted { selectedIDs.remove(id) }
        } else {
            selectedID = id
        }
    }

    func toggleMultipleSelection() {
        guard !drafts.isEmpty else { return }
        isSelectingMultiple.toggle()
        if !isSelectingMultiple { selectedID = selected?.id }
    }

    func selectAll() {
        isSelectingMultiple = true
        selectedIDs = Set(drafts.map(\.id))
    }

    func clearSelection() { selectedIDs.removeAll() }

    func dismissSelection() {
        isSelectingMultiple = false
        clearSelection()
    }

    func prepareForPlacement() {
        isSelectingMultiple = false
        clearSelection()
    }

    func chooseKind(_ kind: LightKind) {
        placementKind = kind
        updateSelected { fixture in
            let generatedPrefixes = ["Lighting"] + LightKind.allCases.map(\.title)
            if fixture.resolvedKind != kind || generatedPrefixes.contains(where: { fixture.name.hasPrefix($0 + " ") }) {
                fixture.name = nextName(prefix: kind.title, excluding: fixture.id)
            }
            fixture.kind = kind
            fixture.layer = kind.layer
            fixture.elevationY = kind.elevation(roomHeight: geometry.height)
        }
    }

    func place(unitX: Double, unitZ: Double) {
        place(unitX: unitX, unitZ: unitZ, layer: placementKind.layer, kind: placementKind)
    }

    func place(unitX: Double, unitZ: Double, layer: LightLayer, kind: LightKind? = nil) {
        isSelectingMultiple = false
        let point = geometry.position(unitX: unitX, unitZ: unitZ)
        if let existing = drafts.first(where: {
            abs($0.positionX - point.x) < 0.000001 && abs($0.positionZ - point.z) < 0.000001
        }) {
            selectedID = existing.id
            return
        }
        let fixture = LightFixture(name: nextName(prefix: kind?.title ?? "Lighting"), layer: layer,
                                   positionX: point.x, positionZ: point.z,
                                   elevationY: kind?.elevation(roomHeight: geometry.height) ?? (layer == .ambient ? geometry.height - 0.08 : 1.2),
                                   lumens: 1080, colorTemperatureKelvin: layer.recommendedKelvin, kind: kind)
        drafts.append(geometry.clamped(fixture))
        selectedID = fixture.id
    }

    private func nextName(prefix: String, excluding id: UUID? = nil) -> String {
        var number = 1
        let names = Set(drafts.filter { $0.id != id }.map(\.name))
        while names.contains("\(prefix) \(number)") { number += 1 }
        return "\(prefix) \(number)"
    }

    func updateSelected(_ update: (inout LightFixture) -> Void) {
        for index in drafts.indices where selectedIDs.contains(drafts[index].id) {
            var fixture = drafts[index]
            update(&fixture)
            drafts[index] = geometry.clamped(fixture)
        }
    }

    /// Dragging preserves continuous room coordinates rather than snapping to the placement grid.
    func move(_ id: UUID, x: Double, z: Double) {
        guard x.isFinite, z.isFinite, let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        var fixture = drafts[index]
        fixture.positionX = x
        fixture.positionZ = z
        drafts[index] = geometry.clamped(fixture)
    }

    func deleteSelected() {
        drafts.removeAll { selectedIDs.contains($0.id) }
        clearSelection()
        if drafts.isEmpty { isSelectingMultiple = false }
    }

    func save(in room: Room, context: ModelContext) throws {
        guard room.workingLayout?.id == originalLayoutID else { throw SaveError.layoutChanged }
        guard room.workingLayout?.isBaseline != true,
              room.workingLayout == nil || room.workingLayout !== room.baselineLayout else {
            throw SaveError.baselineIsReadOnly
        }
        let previousLayout = room.workingLayout
        let layout = previousLayout ?? room.baselineLayout?.createCopy(name: "Working Layout") ?? Layout(name: "Working Layout")
        let previousData = layout.lightFixturesData
        if previousLayout == nil {
            context.insert(layout)
            layout.room = room
            room.workingLayout = layout
        }
        do {
            layout.lightFixturesData = try JSONEncoder().encode(drafts.map { geometry.clamped($0) })
            try context.save()
            savedDrafts = drafts
            originalLayoutID = layout.id
        } catch {
            layout.lightFixturesData = previousData
            if previousLayout == nil {
                room.workingLayout = nil
                context.delete(layout)
            }
            throw error
        }
    }

    enum SaveError: LocalizedError, Equatable {
        case layoutChanged, baselineIsReadOnly
        var errorDescription: String? {
            switch self {
            case .layoutChanged: return "The working layout changed. Reopen Add Lighting to edit the current layout."
            case .baselineIsReadOnly: return "The original scan is read-only. Reset the working layout before editing lights."
            }
        }
    }
}
