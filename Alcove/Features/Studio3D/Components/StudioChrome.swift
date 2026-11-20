import SwiftUI

struct StudioHeaderTitle: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.custom("Cleanow", size: 32, relativeTo: .title))
            .foregroundStyle(Color.alcoveInk)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
    }
}

struct StudioStageProgress: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let stage: StageType
    let room: Room
    let accessibilityTitle: String
    var onSelectStage: ((StageType) -> Void)? = nil

    private enum StepStatus {
        case done(Int)
        case active(Int)
        case upcoming(Int)

        var accessibilityState: String {
            switch self {
            case .done: return "completed"
            case .active: return "current"
            case .upcoming: return "upcoming"
            }
        }
    }

    private func status(for candidate: StageType, number: Int) -> StepStatus {
        if stage == candidate {
            return .active(number)
        } else if room.isCompleted(candidate) || room.isUnlocked(candidate) {
            return .done(number)
        } else {
            return .upcoming(number)
        }
    }

    private var steps: [(title: String, status: StepStatus, stage: StageType?)] {
        [
            ("Scan", .done(1), nil),
            ("Check", status(for: .audit, number: 2), .audit),
            ("Rearrange", status(for: .rearrangement, number: 3), .rearrangement),
            ("Lighting", status(for: .illumination, number: 4), .illumination),
            ("Result", status(for: .harmony, number: 5), .harmony)
        ]
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text(accessibilityTitle)
                .font(.custom("Cleanow", size: 22, relativeTo: .headline))
                .foregroundStyle(Color.alcoveInk)
        } else {
            let currentSteps = steps
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(currentSteps.enumerated()), id: \.offset) { index, step in
                    let stepLabel = VStack(spacing: 6) {
                        ZStack {
                            switch step.status {
                            case .done(let number):
                                Circle().fill(Color.alcoveProgressDone)
                                Circle().stroke(Color.alcoveInk, lineWidth: 2)
                                Text("\(number)")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Color.alcoveInk)
                            case .active(let number):
                                Circle().fill(Color.alcovePrimaryFill)
                                Circle().stroke(Color.alcoveInk, lineWidth: 2)
                                Text("\(number)")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Color.alcoveInk)
                            case .upcoming(let number):
                                Circle().fill(Color.alcoveProgressInactive)
                                Circle().stroke(Color.alcoveMutedInk.opacity(0.45), lineWidth: 1.5)
                                Text("\(number)")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Color.alcoveMutedInk.opacity(0.65))
                            }
                        }
                        .frame(width: 40, height: 40)

                        Text(step.title)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle({
                                switch step.status {
                                case .done, .active: return Color.alcoveInk
                                case .upcoming: return Color.alcoveMutedInk.opacity(0.65)
                                }
                            }())
                    }
                    .frame(width: 66)
                    .contentShape(Rectangle())

                    if case .done = step.status, let targetStage = step.stage, let onSelectStage {
                        Button {
                            onSelectStage(targetStage)
                        } label: {
                            stepLabel
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Go to \(step.title) stage")
                    } else {
                        stepLabel
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(step.title), \(step.status.accessibilityState)")
                    }

                    if index < currentSteps.count - 1 {
                        let lineDone: Bool = {
                            if case .done = step.status { return true }
                            return false
                        }()
                        Capsule()
                            .fill(lineDone ? Color.alcoveProgressDone : Color.alcoveMutedInk.opacity(0.3))
                            .frame(maxWidth: 72)
                            .frame(height: 2)
                            .padding(.top, 19)
                    }
                }
            }
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
    }
}

struct StudioStageButton: View {
    enum Role { case previous, next, add }
    let title: String
    let role: Role
    var systemImage: String? = nil
    var fillsWidth = false
    var showsNavigationChevron = true
    var fontSize: CGFloat? = nil
    var minimumHeight: CGFloat = 44
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if role == .previous { Image(systemName: "chevron.left") }
                if role == .add { Image(systemName: systemImage ?? "plus.circle") }
                else if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.custom("Cleanow", size: fontSize ?? (role == .next ? 17 : 16), relativeTo: .subheadline))
                    .contentTransition(.opacity)
                if role == .next && showsNavigationChevron { Image(systemName: "chevron.right") }
            }
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(Color.alcoveInk)
            .padding(.horizontal, role == .next ? 20 : 16)
            .frame(minWidth: 44, minHeight: minimumHeight)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .background {
                ZStack {
                    Capsule().fill(Color.alcoveInk)
                    ZStack {
                        VStack(spacing: 0) {
                            role == .next ? Color.alcovePrimaryHighlight : Color.alcoveSecondaryHighlight
                            role == .next ? Color.alcovePrimaryShadow : Color.alcoveSecondaryShadow
                        }
                        Capsule().fill(role == .next ? Color.alcovePrimaryFill : Color.alcoveSurfaceElevated)
                            .padding(.top, 2).padding(.bottom, 3.5)
                    }
                    .clipShape(Capsule()).padding(role == .next ? 2.5 : 2)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

enum ResultWorkspaceMode: Equatable {
    case overview
    case lighting
    case rearrange
}

struct StudioTactileCircleBackground: View {
    var active = false
    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        ZStack {
            shape.fill(Color.alcoveInk)
            ZStack {
                shape
                    .fill(active ? Color.alcoveControlActiveShadow : Color.alcoveSecondaryShadow)
                shape
                    .fill(active ? Color.alcoveControlActiveFill : Color.alcoveSurfaceElevated)
                    .offset(y: -3.5)
            }
            .clipShape(shape)
            .padding(2.5)
        }
    }
}

struct StudioResultIconButton: View {
    let systemImage: String?
    let labelText: String?
    let active: Bool
    let accessibilityLabel: String
    let action: () -> Void

    init(
        systemImage: String,
        active: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.labelText = nil
        self.active = active
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    init(
        labelText: String,
        active: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.systemImage = nil
        self.labelText = labelText
        self.active = active
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                } else if let labelText {
                    Text(labelText)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                }
            }
            .foregroundStyle(Color.alcoveInk)
            .frame(width: 49, height: 45)
            .background { StudioTactileCircleBackground(active: active) }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct StudioCameraMenuContent: View {
    let selected: ViewportPreset
    let onSelect: (ViewportPreset) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(ViewportPreset.allCases.filter { $0 != .dollhouse }) { preset in
                row(preset)
            }
            Rectangle().fill(Color.alcoveInk).frame(height: 1.5).padding(.horizontal, 14).padding(.vertical, 6)
            row(.dollhouse)

        }
        .padding(.vertical, 12).frame(width: 230)
        .foregroundStyle(Color.alcoveInk)
        .background(Color.alcoveSurface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.alcoveInk, lineWidth: 2.5))
    }
    private func row(_ preset: ViewportPreset) -> some View {
        Button { onSelect(preset) } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                    .opacity(selected == preset && preset != .dollhouse ? 1 : 0).frame(width: 16)
                Image(systemName: preset.systemImage).font(.system(size: 15, weight: .semibold)).frame(width: 22)
                Text(preset == .dollhouse ? "Reset Angle" : preset.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 16).frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Identical screen-centered title and action spacing across all studio stages.
struct StudioHeaderLayout<Previous: View, Actions: View>: View {
    let title: String
    var titleHidden = false
    @ViewBuilder let previous: () -> Previous
    @ViewBuilder let actions: () -> Actions
    var body: some View {
        ZStack {
            StudioHeaderTitle(title: title)
                .padding(.horizontal, 180)
                .opacity(titleHidden ? 0 : 1)
                .allowsHitTesting(!titleHidden)
                .accessibilityHidden(titleHidden)
            HStack {
                previous()
                Spacer(minLength: 0)
                actions()
            }
        }
        .frame(height: 45)
    }
}
