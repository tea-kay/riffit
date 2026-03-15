import SwiftUI

/// Step 1 of onboarding: the user selects their creator type.
/// This determines the AI interview branching — each type gets
/// different questions focused on what matters for their brand.
struct CreatorTypeView: View {
    let onSelect: (CreatorProfile.CreatorType) -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            ScrollView {
                VStack(spacing: RS.smPlus) {
                    ForEach(CreatorTypeOption.allOptions) { option in
                        CreatorTypeCard(option: option) {
                            onSelect(option.type)
                        }
                    }
                }
                .padding(.horizontal, RS.md)
                .padding(.bottom, RS.xl)
            }
        }
        .background(Color.riffitBackground)
    }

    private var headerSection: some View {
        VStack(spacing: RS.sm) {
            Text("What kind of creator are you?")
                .font(RF.largeTitle)
                .foregroundStyle(Color.riffitTextPrimary)

            Text("This helps us tailor the experience to your goals.")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, RS.lg)
        .padding(.top, RS.xl)
        .padding(.bottom, RS.lg)
    }
}

// MARK: - Creator Type Option Data

/// Defines the display data for each creator type in the selection screen.
struct CreatorTypeOption: Identifiable {
    let id: String
    let type: CreatorProfile.CreatorType
    let title: String
    let description: String
    let icon: String  // SF Symbol name

    static let allOptions: [CreatorTypeOption] = [
        CreatorTypeOption(
            id: "personal_brand",
            type: .personalBrand,
            title: "Personal Brand",
            description: "You share your story, opinions, and expertise to build an audience around who you are.",
            icon: "person.crop.circle"
        ),
        CreatorTypeOption(
            id: "educator",
            type: .educator,
            title: "Educator",
            description: "You teach frameworks, skills, or knowledge to help your audience level up.",
            icon: "lightbulb"
        ),
        CreatorTypeOption(
            id: "entertainer",
            type: .entertainer,
            title: "Entertainer",
            description: "You create content that hooks people through humor, storytelling, or personality.",
            icon: "theatermasks"
        ),
        CreatorTypeOption(
            id: "business",
            type: .business,
            title: "Business",
            description: "You create content to attract customers and showcase your product or service.",
            icon: "building.2"
        ),
        CreatorTypeOption(
            id: "agency",
            type: .agency,
            title: "Agency",
            description: "You create content for clients and need to manage multiple brand voices.",
            icon: "person.3"
        ),
    ]
}

// MARK: - Creator Type Card

/// A tappable card showing one creator type option.
struct CreatorTypeCard: View {
    let option: CreatorTypeOption
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: RS.md) {
                // Icon in a teal-tinted container
                Image(systemName: option.icon)
                    .font(.title2)
                    .foregroundStyle(Color.riffitTeal400)
                    .frame(width: 48, height: 48)
                    .background(Color.riffitTealTint)
                    .cornerRadius(RR.button)

                VStack(alignment: .leading, spacing: RS.xs) {
                    Text(option.title)
                        .font(RF.heading)
                        .foregroundStyle(Color.riffitTextPrimary)

                    Text(option.description)
                        .font(RF.caption)
                        .foregroundStyle(Color.riffitTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.riffitTextTertiary)
            }
            .padding(RS.md)
            .background(Color.riffitSurface)
            .cornerRadius(RR.card)
            .overlay(
                RoundedRectangle(cornerRadius: RR.card)
                    .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
