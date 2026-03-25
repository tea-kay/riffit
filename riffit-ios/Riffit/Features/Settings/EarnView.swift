import SwiftUI

/// Referral program screen — share link, track earnings, view commission tiers.
struct EarnView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = EarnViewModel()

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: RS.lg) {
                    // Tagline below the nav title
                    Text("share the wave, ride the gold")
                        .font(.custom("Lora-Italic", size: 13))
                        .foregroundStyle(Color.riffitTeal400)
                        .kerning(1.0)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    referralLinkCard
                    statsRow
                    quickCounters
                    commissionTiersCard
                    finePrintCallout
                    networkEmptyState
                }
                .padding(.horizontal, RS.md)
                .padding(.top, RS.smPlus)
            }
        }
        .navigationTitle("Earn")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Earn")
                    .font(RF.title)
                    .foregroundStyle(Color.riffitTextPrimary)
            }
        }
        .onAppear {
            viewModel.seedCode(from: appState.currentUser)
        }
    }

    // MARK: - Referral Link Card

    private var referralLinkCard: some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            Text("YOUR REFERRAL LINK")
                .font(RF.meta)
                .textCase(.uppercase)
                .foregroundStyle(Color.riffitTextSecondary)

            HStack(spacing: RS.sm) {
                Text(viewModel.referralLink)
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, RS.smPlus)
                    .padding(.vertical, RS.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.riffitElevated)
                    .cornerRadius(RR.button)

                Button {
                    viewModel.copyLink()
                } label: {
                    Text(viewModel.linkCopied ? "Copied!" : "Copy")
                        .font(.custom("Lora-Bold", size: 13))
                        .foregroundStyle(Color(hex: 0x111111))
                        .padding(.horizontal, RS.md)
                        .padding(.vertical, RS.sm)
                        .background(Color.riffitPrimary)
                        .cornerRadius(RR.button)
                }
            }
        }
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.card)
        .overlay(
            RoundedRectangle(cornerRadius: RR.card)
                .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
        )
    }

    // MARK: - Stats Row (2 columns)

    private var statsRow: some View {
        HStack(spacing: RS.sm) {
            // Total earned
            statCard(
                label: "TOTAL EARNED",
                value: "$\(Int(viewModel.totalEarned))",
                valueColor: Color.riffitPrimary,
                sub: "Lifetime"
            )

            // This month
            statCard(
                label: "THIS MONTH",
                value: "$\(Int(viewModel.thisMonthEarned))",
                valueColor: Color.riffitTextPrimary,
                sub: "Pending payout"
            )
        }
    }

    private func statCard(
        label: String,
        value: String,
        valueColor: Color,
        sub: String
    ) -> some View {
        VStack(spacing: RS.xs) {
            Text(label)
                .font(RF.meta)
                .textCase(.uppercase)
                .foregroundStyle(Color.riffitTextSecondary)

            Text(value)
                .font(.custom("Lora-Bold", size: 28))
                .foregroundStyle(valueColor)

            Text(sub)
                .font(RF.meta)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.card)
        .overlay(
            RoundedRectangle(cornerRadius: RR.card)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Quick Counters (3 columns)

    private var quickCounters: some View {
        HStack(spacing: RS.sm) {
            counterCard(value: viewModel.inviteCount, label: "INVITES")
            counterCard(value: viewModel.payingCount, label: "PAYING")
            counterCard(value: viewModel.networkCount, label: "NETWORK")
        }
    }

    private func counterCard(value: Int, label: String) -> some View {
        VStack(spacing: RS.xs) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.riffitTextPrimary)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .textCase(.uppercase)
                .foregroundStyle(Color.riffitTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RS.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Commission Tiers Card

    private var commissionTiersCard: some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            Text("COMMISSION TIERS")
                .font(RF.meta)
                .textCase(.uppercase)
                .tracking(0.06 * 11)
                .foregroundStyle(Color.riffitPrimary)

            VStack(spacing: 0) {
                tierRow(
                    number: "1",
                    numberBg: Color.riffitPrimaryTint,
                    numberColor: Color.riffitPrimary,
                    title: "Direct referrals",
                    subtitle: "People you invite",
                    rates: [("50%", "1st mo"), ("10%", "ongoing")],
                    rateColor: Color.riffitPrimary
                )

                Divider()
                    .background(Color.riffitBorderSubtle)

                tierRow(
                    number: "2",
                    numberBg: Color.riffitTealTint,
                    numberColor: Color.riffitTeal400,
                    title: "Their referrals",
                    subtitle: "People your invites bring in",
                    rates: [("3%", "ongoing")],
                    rateColor: Color.riffitTeal400
                )

                Divider()
                    .background(Color.riffitBorderSubtle)

                tierRow(
                    number: "3",
                    numberBg: Color.riffitElevated,
                    numberColor: Color.riffitTextSecondary,
                    title: "3rd level",
                    subtitle: "Three layers deep",
                    rates: [("1%", "ongoing")],
                    rateColor: Color.riffitTextSecondary
                )
            }
            .background(Color.riffitSurface)
            .cornerRadius(RR.card)
            .overlay(
                RoundedRectangle(cornerRadius: RR.card)
                    .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
            )
        }
    }

    private func tierRow(
        number: String,
        numberBg: Color,
        numberColor: Color,
        title: String,
        subtitle: String,
        rates: [(String, String)],
        rateColor: Color
    ) -> some View {
        HStack(spacing: RS.smPlus) {
            // Numbered circle
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(numberColor)
                .frame(width: 32, height: 32)
                .background(numberBg)
                .clipShape(Circle())

            // Title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.riffitTextPrimary)
                Text(subtitle)
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextSecondary)
            }

            Spacer()

            // Rate columns
            HStack(spacing: RS.smPlus) {
                ForEach(Array(rates.enumerated()), id: \.offset) { _, rate in
                    VStack(spacing: 1) {
                        Text(rate.0)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(rateColor)
                        Text(rate.1)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                }
            }
        }
        .padding(RS.md)
    }

    // MARK: - Fine Print Callout

    private var finePrintCallout: some View {
        VStack(alignment: .leading, spacing: RS.xs) {
            (Text("Commissions are lifetime as long as referred users stay subscribed. L2 and L3 earnings begin on the referral's second month. ")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextSecondary)
            + Text("$100/mo cap per referred account.")
                .font(RF.caption)
                .foregroundStyle(Color.riffitPrimary))
        }
        .padding(RS.md)
        .background(Color.riffitPrimaryGhost)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitPrimaryTint, lineWidth: 0.5)
        )
    }

    // MARK: - Network Empty State

    private var networkEmptyState: some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            Text("YOUR NETWORK")
                .font(RF.meta)
                .textCase(.uppercase)
                .foregroundStyle(Color.riffitTextSecondary)

            VStack(spacing: RS.sm) {
                Text("No referrals yet")
                    .font(.custom("Lora-Bold", size: 16))
                    .foregroundStyle(Color.riffitTextPrimary)

                Text("Share your link. Watch the wave build.")
                    .font(.custom("Lora-Italic", size: 12))
                    .foregroundStyle(Color.riffitTextTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, RS.xl)
            .background(Color.riffitSurface)
            .cornerRadius(RR.card)
            .overlay(
                RoundedRectangle(cornerRadius: RR.card)
                    .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
            )
        }
    }
}
