import SwiftUI

private enum EvaluationReviewPalette {
    static let borderBrown = Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0)
    static let cardPeach = Color(red: 0xFE / 255.0, green: 0xEE / 255.0, blue: 0xDE / 255.0)
    static let innerCream = Color(red: 0xFF / 255.0, green: 0xFB / 255.0, blue: 0xF5 / 255.0)
    static let subtitleTerracotta = Color(red: 0xC4 / 255.0, green: 0x7A / 255.0, blue: 0x5A / 255.0)
    static let improveRed = Color(red: 0xD4 / 255.0, green: 0x63 / 255.0, blue: 0x63 / 255.0)
    static let worksWellSage = Color(red: 0xDD / 255.0, green: 0xDD / 255.0, blue: 0xB1 / 255.0)

    static let goldHighlight = Color(red: 0xFB / 255.0, green: 0xEA / 255.0, blue: 0xB6 / 255.0)
    static let goldFace = Color(red: 0xFB / 255.0, green: 0xD4 / 255.0, blue: 0x60 / 255.0)
    static let goldLip = Color(red: 0xFC / 255.0, green: 0xA6 / 255.0, blue: 0x0F / 255.0)

    static let greyBorder = Color(red: 0xB7 / 255.0, green: 0xB7 / 255.0, blue: 0xB7 / 255.0)
    static let greyHighlight = Color(red: 0xF7 / 255.0, green: 0xF7 / 255.0, blue: 0xF7 / 255.0)
    static let greyFace = Color(red: 0xEA / 255.0, green: 0xE8 / 255.0, blue: 0xE6 / 255.0)
    static let greyLip = Color(red: 0xC7 / 255.0, green: 0xC7 / 255.0, blue: 0xC7 / 255.0)
}

/// Advisory stage evaluation dialog presenting Otter's review styled to match Alcove's Figma card system.
public struct StageEvaluationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let result: StageEvaluationResult
    let stage: StageType
    let onProceedAnyway: () -> Void
    let onKeepRefining: () -> Void
    let onReevaluate: (() -> Void)?

    public init(
        result: StageEvaluationResult,
        stage: StageType,
        onProceedAnyway: @escaping () -> Void,
        onKeepRefining: @escaping () -> Void,
        onReevaluate: (() -> Void)? = nil
    ) {
        self.result = result
        self.stage = stage
        self.onProceedAnyway = onProceedAnyway
        self.onKeepRefining = onKeepRefining
        self.onReevaluate = onReevaluate
    }

    private var statusSubtitle: String {
        if stage == .audit {
            return "Baseline Room Audit Captured"
        }
        return result.canAdvance ? "Ready for Next Stage" : "A Few Things Need Your Attention"
    }

    private var primaryActionTitle: String {
        if stage == .harmony {
            return "View in AR Walkthrough"
        } else if stage == .audit {
            return "Proceed to Rearrangement"
        } else {
            return result.canAdvance ? "Advance to Next Stage" : "Proceed Anyway (Advisory Override)"
        }
    }

    private var secondaryActionTitle: String {
        stage == .audit ? "Keep Inspecting Baseline" : "Keep Refining Layout"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Centered header title
            HStack {
                Spacer()

                Text(stage == .audit ? "Room Audit Review" : "Layout Review")
                    .font(.custom("Cleanow", size: 22, relativeTo: .title3))
                    .foregroundStyle(EvaluationReviewPalette.borderBrown)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // Main Evaluation Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title.isEmpty ? "Layout Evaluation Complete!" : result.title)
                            .font(.custom("Cleanow", size: 24, relativeTo: .title2))
                            .foregroundStyle(EvaluationReviewPalette.borderBrown)

                        Text(statusSubtitle)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(EvaluationReviewPalette.subtitleTerracotta)
                    }

                    // Otter's Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Otter's Note")
                            .font(.custom("Cleanow", size: 17, relativeTo: .headline))
                            .foregroundStyle(EvaluationReviewPalette.borderBrown)

                        Group {
                            if let attributed = try? AttributedString(
                                markdown: result.dialogue,
                                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                            ) {
                                Text(attributed)
                            } else {
                                Text(result.dialogue)
                            }
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(EvaluationReviewPalette.borderBrown)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(EvaluationReviewPalette.innerCream)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(EvaluationReviewPalette.borderBrown, lineWidth: 2)
                        )
                    }

                    // Areas to Improve (if any bottlenecks detected)
                    if !result.bottlenecks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Areas to Improve")
                                .font(.custom("Cleanow", size: 17, relativeTo: .headline))
                                .foregroundStyle(EvaluationReviewPalette.borderBrown)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(result.bottlenecks) { bottleneck in
                                    let isCritical = bottleneck.severity == .critical
                                    let cardFill: Color = switch bottleneck.severity {
                                    case .critical: EvaluationReviewPalette.improveRed
                                    case .warning: EvaluationReviewPalette.goldHighlight
                                    case .notice: EvaluationReviewPalette.innerCream
                                    }
                                    let primaryInk: Color = isCritical ? .white : EvaluationReviewPalette.borderBrown
                                    let secondaryInk: Color = isCritical ? .white.opacity(0.95) : EvaluationReviewPalette.borderBrown.opacity(0.88)
                                    let iconName: String = switch bottleneck.severity {
                                    case .critical: "exclamationmark.triangle.fill"
                                    case .warning: "exclamationmark.circle.fill"
                                    case .notice: "info.circle.fill"
                                    }

                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: iconName)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(primaryInk)
                                            .padding(.top, 2)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(bottleneck.title)
                                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                .foregroundStyle(primaryInk)
                                            Text(bottleneck.detail)
                                                .font(.system(.caption, design: .rounded, weight: .medium))
                                                .foregroundStyle(secondaryInk)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(cardFill)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(EvaluationReviewPalette.borderBrown, lineWidth: 2)
                                    )
                                }
                            }
                        }
                    }

                    // Design Tips
                    if !result.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Design Tips")
                                .font(.custom("Cleanow", size: 17, relativeTo: .headline))
                                .foregroundStyle(EvaluationReviewPalette.borderBrown)

                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(result.recommendations, id: \.self) { rec in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(EvaluationReviewPalette.borderBrown)
                                            .padding(.top, 2)

                                        Group {
                                            if let attributed = try? AttributedString(
                                                markdown: rec,
                                                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                                            ) {
                                                Text(attributed)
                                            } else {
                                                Text(rec)
                                            }
                                        }
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                        .foregroundStyle(EvaluationReviewPalette.borderBrown)
                                        .lineSpacing(2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(EvaluationReviewPalette.innerCream)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(EvaluationReviewPalette.borderBrown, lineWidth: 2)
                            )
                        }
                    }

                    // What Works Well
                    if !result.praise.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What Works Well")
                                .font(.custom("Cleanow", size: 17, relativeTo: .headline))
                                .foregroundStyle(EvaluationReviewPalette.borderBrown)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(result.praise, id: \.self) { point in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(EvaluationReviewPalette.borderBrown)
                                            .padding(.top, 1)

                                        Text(point)
                                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                                            .foregroundStyle(EvaluationReviewPalette.borderBrown)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(EvaluationReviewPalette.worksWellSage)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(EvaluationReviewPalette.borderBrown, lineWidth: 2)
                            )
                        }
                    }

                    // Bottom Tactile Action Buttons
                    VStack(spacing: 8) {
                        Button {
                            onProceedAnyway()
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Text(primaryActionTitle)
                                    .font(.custom("Cleanow", size: 17, relativeTo: .subheadline))
                                Image(systemName: stage == .harmony ? "arkit" : "chevron.right")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                            }
                            .foregroundStyle(result.canAdvance ? EvaluationReviewPalette.borderBrown : EvaluationReviewPalette.greyBorder)
                            .padding(.horizontal, 26)
                            .frame(minHeight: 46)
                            .background {
                                tactilePillBackground(isEnabledStyle: result.canAdvance)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            onKeepRefining()
                            dismiss()
                        } label: {
                            Text(secondaryActionTitle)
                                .font(.custom("Cleanow", size: 16, relativeTo: .subheadline))
                                .foregroundStyle(EvaluationReviewPalette.greyBorder)
                                .frame(minHeight: 44)
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(EvaluationReviewPalette.cardPeach)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(EvaluationReviewPalette.borderBrown, lineWidth: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private func tactilePillBackground(isEnabledStyle: Bool) -> some View {
        let border = isEnabledStyle ? EvaluationReviewPalette.borderBrown : EvaluationReviewPalette.greyBorder
        let topHighlight = isEnabledStyle ? EvaluationReviewPalette.goldHighlight : EvaluationReviewPalette.greyHighlight
        let face = isEnabledStyle ? EvaluationReviewPalette.goldFace : EvaluationReviewPalette.greyFace
        let bottomLip = isEnabledStyle ? EvaluationReviewPalette.goldLip : EvaluationReviewPalette.greyLip

        ZStack {
            Capsule()
                .fill(border)

            ZStack {
                VStack(spacing: 0) {
                    topHighlight
                    bottomLip
                }

                Capsule()
                    .fill(face)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
            }
            .clipShape(Capsule())
            .padding(2.5)
        }
    }
}
