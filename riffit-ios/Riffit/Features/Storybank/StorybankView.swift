import SwiftUI

/// The Storybank tab — the creator's workspace for organizing stories.
/// Each story collects assets (voice notes, video, images, text) and
/// references to inspiration videos from the Library.
struct StorybankView: View {
    @EnvironmentObject var viewModel: StorybankViewModel
    @State private var showNewStoryAlert: Bool = false
    @State private var newStoryTitle: String = ""
    @State private var showNewFolderAlert: Bool = false
    @State private var newFolderName: String = ""
    @State private var showActionSheet: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.isEmpty {
                ProgressView()
                    .tint(Color.riffitPrimary)
            } else if viewModel.isEmpty {
                emptyState
            } else {
                storyList
            }
        }
        .navigationTitle("Storybank")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Storybank")
                    .font(RF.title)
                    .foregroundStyle(Color.riffitTextPrimary)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showActionSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .riffitModal(isPresented: $showActionSheet) {
            RiffitActionModal(
                actions: [
                    .init(label: "New Story", icon: "doc.text") {
                        newStoryTitle = ""
                        showNewStoryAlert = true
                    },
                    .init(label: "New Folder", icon: "folder.badge.plus") {
                        newFolderName = ""
                        showNewFolderAlert = true
                    },
                ],
                onDismiss: {
                    showActionSheet = false
                }
            )
        }
        .riffitModal(isPresented: $showNewStoryAlert) {
            RiffitInputModal(
                title: "New Story",
                placeholder: "Story title",
                actionLabel: "Create",
                text: $newStoryTitle,
                onCancel: {
                    showNewStoryAlert = false
                },
                onAction: { title in
                    viewModel.createStory(title: title)
                    showNewStoryAlert = false
                }
            )
        }
        .riffitModal(isPresented: $showNewFolderAlert) {
            RiffitInputModal(
                title: "New Folder",
                placeholder: "Folder name",
                actionLabel: "Create",
                text: $newFolderName,
                onCancel: {
                    showNewFolderAlert = false
                },
                onAction: { name in
                    viewModel.createFolder(name: name)
                    showNewFolderAlert = false
                }
            )
        }
        .task {
            await viewModel.fetchStories()
        }
    }

    // MARK: - Story List

    private var storyList: some View {
        ScrollView {
            LazyVStack(spacing: RS.smPlus) {
                // Folders section
                if !viewModel.folders.isEmpty {
                    ForEach(viewModel.folders) { folder in
                        StoryFolderDropTarget(folder: folder, viewModel: viewModel)
                    }
                }

                // Unfiled stories
                let unfiled = viewModel.unfiledStories
                if !unfiled.isEmpty {
                    if !viewModel.folders.isEmpty {
                        Text("Unfiled")
                            .font(RF.tag)
                            .textCase(.uppercase)
                            .tracking(0.08 * 12)
                            .foregroundStyle(Color.riffitTextTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, RS.sm)
                    }

                    ForEach(unfiled) { story in
                        NavigationLink(value: story) {
                            StoryCard(story: story, countsLabel: viewModel.countsLabel(for: story.id))
                        }
                        .buttonStyle(.plain)
                        .draggable(story.id.uuidString)
                    }
                }
            }
            .padding(.horizontal, RS.md)
            .padding(.vertical, RS.smPlus)
        }
        .refreshable {
            await viewModel.fetchStories()
        }
        .navigationDestination(for: Story.self) { story in
            StoryDetailView(story: story, viewModel: viewModel)
        }
        .navigationDestination(for: StoryFolder.self) { folder in
            StoryFolderDetailView(folder: folder, viewModel: viewModel)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ZStack {
            // Full-bleed scene background
            if colorScheme == .dark {
                Color(red: 10/255.0, green: 14/255.0, blue: 26/255.0) // #0A0E1A navy
                    .ignoresSafeArea()
            } else {
                storybankGridBackground
            }

            VStack(spacing: RS.md) {
                Spacer()

                if colorScheme == .dark {
                    CampfireNightScene()
                        .frame(height: 360)
                } else {
                    SunsetBeachScene()
                        .frame(height: 360)
                }

                Text(colorScheme == .dark
                     ? "Every story needs a spark"
                     : "Your story starts here")
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)

                Text(colorScheme == .dark
                     ? "Start building your first story."
                     : "Build your first story.")
                    .font(RF.caption)
                    .foregroundStyle(colorScheme == .dark
                        ? Color(hex: 0x555555)
                        : Color.riffitTextSecondary)

                RiffitButton(title: "Start a new story", variant: .primary) {
                    newStoryTitle = ""
                    showNewStoryAlert = true
                }
                .padding(.horizontal, RS.xl2)
                .padding(.top, RS.sm)

                Spacer()
            }
        }
    }

    /// Beige grid background for light-mode empty state.
    private var storybankGridBackground: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                        with: .color(Color.riffitGridBackground))

            let vSpacing: CGFloat = 73
            var x: CGFloat = vSpacing
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(p, with: .color(Color.riffitGridLine), lineWidth: 0.35)
                x += vSpacing
            }

            let hSpacing: CGFloat = 85
            var y: CGFloat = hSpacing
            while y < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(p, with: .color(Color.riffitGridLine), lineWidth: 0.35)
                y += hSpacing
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Sunset Beach Scene (Light Mode)

/// Sunset beach illustration for the Storybank empty state in light mode.
/// Sky with amber wash bands, concentric sun, ocean with reflection,
/// wave crest, sand beach, palm tree, and surfboard with Riffit badge.
struct SunsetBeachScene: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let midX = w / 2

            // Fill with warm beige to blend with grid background
            context.fill(Path(CGRect(origin: .zero, size: size)),
                        with: .color(Color.riffitGridBackground))

            // Sky: warm amber wash bands
            context.fill(Path(CGRect(x: 0, y: 40, width: w, height: 60)),
                        with: .color(Color.riffitPrimary.opacity(0.08)))
            context.fill(Path(CGRect(x: 0, y: 100, width: w, height: 50)),
                        with: .color(Color.riffitPrimaryPressed.opacity(0.10)))
            context.fill(Path(CGRect(x: 0, y: 150, width: w, height: 40)),
                        with: .color(Color(hex: 0xD94E2A).opacity(0.07)))

            // Sun: three concentric circles centered at y=175
            let sunY: CGFloat = 175
            context.fill(Path(ellipseIn: CGRect(x: midX - 52, y: sunY - 52,
                                                 width: 104, height: 104)),
                        with: .color(Color.riffitPrimary))
            context.fill(Path(ellipseIn: CGRect(x: midX - 40, y: sunY - 40,
                                                 width: 80, height: 80)),
                        with: .color(Color(hex: 0xF5C842)))
            context.fill(Path(ellipseIn: CGRect(x: midX - 28, y: sunY - 28,
                                                 width: 56, height: 56)),
                        with: .color(Color.riffitPrimary))

            // Horizon line
            context.fill(Path(CGRect(x: 0, y: 228, width: w, height: 2)),
                        with: .color(Color(hex: 0xD94E2A).opacity(0.35)))

            // Ocean: two flat bands
            context.fill(Path(CGRect(x: 0, y: 230, width: w, height: 45)),
                        with: .color(Color.riffitTeal600.opacity(0.28)))
            context.fill(Path(CGRect(x: 0, y: 275, width: w, height: 30)),
                        with: .color(Color.riffitTeal900.opacity(0.20)))

            // Sun reflection: two gold ellipses on water
            context.fill(Path(ellipseIn: CGRect(x: midX - 20, y: 240,
                                                 width: 40, height: 8)),
                        with: .color(Color.riffitPrimary.opacity(0.15)))
            context.fill(Path(ellipseIn: CGRect(x: midX - 12, y: 255,
                                                 width: 24, height: 5)),
                        with: .color(Color.riffitPrimary.opacity(0.10)))

            // Wave crest
            var wave = Path()
            wave.move(to: CGPoint(x: 20, y: 250))
            wave.addCurve(to: CGPoint(x: w - 20, y: 248),
                         control1: CGPoint(x: w * 0.3, y: 238),
                         control2: CGPoint(x: w * 0.7, y: 258))
            context.stroke(wave,
                          with: .color(Color(hex: 0xF5F2EB).opacity(0.65)),
                          lineWidth: 3.5)

            // Sand
            context.fill(Path(CGRect(x: 0, y: 305, width: w, height: 55)),
                        with: .color(Color(hex: 0xE8D5A3)))

            // Palm tree (left side)
            drawPalmTree(in: &context,
                        trunkBase: CGPoint(x: 65, y: 310),
                        trunkTop: CGPoint(x: 45, y: 130))

            // Surfboard (right side, on sand)
            drawSurfboard(in: &context, center: CGPoint(x: w - 80, y: 310))
        }
    }

    private func drawPalmTree(
        in context: inout GraphicsContext,
        trunkBase: CGPoint,
        trunkTop: CGPoint
    ) {
        // Curved trunk
        var trunk = Path()
        trunk.move(to: trunkBase)
        trunk.addCurve(to: trunkTop,
                      control1: CGPoint(x: trunkBase.x + 15, y: trunkBase.y - 60),
                      control2: CGPoint(x: trunkTop.x + 25, y: trunkTop.y + 50))
        context.stroke(trunk, with: .color(Color(hex: 0x8B6914)), lineWidth: 8)

        // 6 fronds radiating from trunk top
        let frondData: [(angle: CGFloat, len: CGFloat, color: Color)] = [
            (-60, 55, Color.riffitTeal900),
            (-30, 60, Color.riffitTeal600),
            (0, 55, Color.riffitTeal900),
            (30, 60, Color.riffitTeal600),
            (60, 50, Color.riffitTeal900),
            (100, 45, Color.riffitTeal600),
        ]
        for f in frondData {
            let rad = f.angle * .pi / 180
            let endX = trunkTop.x + cos(rad) * f.len
            let endY = trunkTop.y + sin(rad) * f.len
            let ctrlX = trunkTop.x + cos(rad) * f.len * 0.6
            let ctrlY = trunkTop.y + sin(rad) * f.len * 0.6 + 12
            var frond = Path()
            frond.move(to: trunkTop)
            frond.addQuadCurve(to: CGPoint(x: endX, y: endY),
                               control: CGPoint(x: ctrlX, y: ctrlY))
            context.stroke(frond, with: .color(f.color), lineWidth: 3)
        }
    }

    private func drawSurfboard(
        in context: inout GraphicsContext,
        center: CGPoint
    ) {
        context.drawLayer { ctx in
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: .degrees(-12))

            let bw: CGFloat = 22
            let bh: CGFloat = 70
            let boardRect = CGRect(x: -bw / 2, y: -bh / 2,
                                   width: bw, height: bh)

            // Gold fill + black outline
            ctx.fill(Path(ellipseIn: boardRect),
                    with: .color(Color.riffitPrimary))
            ctx.stroke(Path(ellipseIn: boardRect),
                      with: .color(.black), lineWidth: 1.5)

            // Teal stripe
            ctx.fill(Path(CGRect(x: -bw / 2 + 4, y: -8,
                                  width: bw - 8, height: 3)),
                    with: .color(Color.riffitTeal600))
            // Coral stripe
            ctx.fill(Path(CGRect(x: -bw / 2 + 4, y: -3,
                                  width: bw - 8, height: 3)),
                    with: .color(Color(hex: 0xD94E2A)))

            // R badge
            ctx.draw(
                Text("R")
                    .font(.custom("Georgia-BoldItalic", size: 8))
                    .foregroundColor(Color.riffitOnPrimary),
                at: CGPoint(x: 0, y: -18))

            // Fin
            var fin = Path()
            fin.move(to: CGPoint(x: 0, y: bh / 2 - 5))
            fin.addLine(to: CGPoint(x: -5, y: bh / 2 + 8))
            fin.addLine(to: CGPoint(x: 0, y: bh / 2 + 3))
            fin.closeSubpath()
            ctx.fill(fin, with: .color(.black))
        }
    }
}

// MARK: - Campfire Night Scene (Dark Mode)

/// Campfire night illustration for the Storybank empty state in dark mode.
/// Deep navy sky with scattered stars and crescent moon, pine tree
/// silhouettes flanking a central campfire with layered flames.
struct CampfireNightScene: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let midX = w / 2
            let navy = Color(hex: 0x0A0E1A)

            // Background: deep navy sky
            context.fill(Path(CGRect(origin: .zero, size: size)),
                        with: .color(navy))

            // Stars: 13 small circles scattered in sky
            let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, op: Double)] = [
                (40, 30, 1.2, 0.60), (120, 55, 0.8, 0.45),
                (200, 25, 1.0, 0.70), (280, 70, 0.7, 0.35),
                (350, 40, 1.4, 0.80), (90, 100, 1.0, 0.50),
                (180, 130, 0.9, 0.55), (310, 110, 1.1, 0.60),
                (50, 160, 0.8, 0.40), (250, 170, 1.3, 0.65),
                (370, 150, 0.9, 0.50), (150, 200, 0.7, 0.35),
                (320, 200, 1.0, 0.55),
            ]
            for s in stars {
                let sx = min(s.x, w - 10)
                context.fill(
                    Path(ellipseIn: CGRect(x: sx - s.r, y: s.y - s.r,
                                           width: s.r * 2, height: s.r * 2)),
                    with: .color(.white.opacity(s.op)))
            }

            // Moon: crescent (upper right)
            let moonX = w - 70
            let moonY: CGFloat = 60
            let moonR: CGFloat = 20
            context.fill(
                Path(ellipseIn: CGRect(x: moonX - moonR, y: moonY - moonR,
                                       width: moonR * 2, height: moonR * 2)),
                with: .color(.white.opacity(0.85)))
            // Navy circle offset to carve crescent
            context.fill(
                Path(ellipseIn: CGRect(x: moonX - moonR + 8, y: moonY - moonR - 3,
                                       width: moonR * 2, height: moonR * 2)),
                with: .color(navy))

            // Ground
            let groundY: CGFloat = 290
            context.fill(
                Path(CGRect(x: 0, y: groundY, width: w,
                            height: size.height - groundY)),
                with: .color(Color(hex: 0x1A0E06)))

            // Pine trees — left silhouettes
            drawPineTree(in: &context, baseX: 55, groundY: groundY,
                        treeHeight: 130, treeWidth: 50)
            drawPineTree(in: &context, baseX: 30, groundY: groundY,
                        treeHeight: 100, treeWidth: 40)

            // Pine trees — right silhouettes
            drawPineTree(in: &context, baseX: w - 55, groundY: groundY,
                        treeHeight: 120, treeWidth: 45)
            drawPineTree(in: &context, baseX: w - 25, groundY: groundY,
                        treeHeight: 90, treeWidth: 38)

            // Firelight wash on nearby trees
            context.fill(
                Path(ellipseIn: CGRect(x: 30, y: groundY - 80,
                                       width: 60, height: 100)),
                with: .color(Color.riffitPrimaryPressed.opacity(0.08)))
            context.fill(
                Path(ellipseIn: CGRect(x: w - 90, y: groundY - 70,
                                       width: 60, height: 90)),
                with: .color(Color.riffitPrimaryPressed.opacity(0.08)))

            // Campfire glow on ground
            context.fill(
                Path(ellipseIn: CGRect(x: midX - 60, y: groundY - 5,
                                       width: 120, height: 24)),
                with: .color(Color.riffitPrimary.opacity(0.18)))
            context.fill(
                Path(ellipseIn: CGRect(x: midX - 40, y: groundY,
                                       width: 80, height: 16)),
                with: .color(Color.riffitPrimary.opacity(0.08)))

            // Logs: two crossed rounded rects
            context.drawLayer { ctx in
                ctx.translateBy(x: midX, y: groundY + 5)
                ctx.rotate(by: .degrees(15))
                ctx.fill(Path(roundedRect: CGRect(x: -20, y: -3,
                                                   width: 40, height: 6),
                             cornerRadius: 3),
                        with: .color(Color(hex: 0x3D2817)))
            }
            context.drawLayer { ctx in
                ctx.translateBy(x: midX, y: groundY + 5)
                ctx.rotate(by: .degrees(-15))
                ctx.fill(Path(roundedRect: CGRect(x: -20, y: -3,
                                                   width: 40, height: 6),
                             cornerRadius: 3),
                        with: .color(Color(hex: 0x3D2817)))
            }

            // Flames: 4 layered paths (wide coral → narrow cream)
            // 1. Coral base (widest)
            var f1 = Path()
            f1.move(to: CGPoint(x: midX - 18, y: groundY))
            f1.addCurve(to: CGPoint(x: midX, y: groundY - 45),
                       control1: CGPoint(x: midX - 20, y: groundY - 20),
                       control2: CGPoint(x: midX - 8, y: groundY - 40))
            f1.addCurve(to: CGPoint(x: midX + 18, y: groundY),
                       control1: CGPoint(x: midX + 8, y: groundY - 40),
                       control2: CGPoint(x: midX + 20, y: groundY - 20))
            f1.closeSubpath()
            context.fill(f1, with: .color(Color(hex: 0xD94E2A)))

            // 2. Amber middle
            var f2 = Path()
            f2.move(to: CGPoint(x: midX - 13, y: groundY))
            f2.addCurve(to: CGPoint(x: midX, y: groundY - 38),
                       control1: CGPoint(x: midX - 15, y: groundY - 18),
                       control2: CGPoint(x: midX - 5, y: groundY - 34))
            f2.addCurve(to: CGPoint(x: midX + 13, y: groundY),
                       control1: CGPoint(x: midX + 5, y: groundY - 34),
                       control2: CGPoint(x: midX + 15, y: groundY - 18))
            f2.closeSubpath()
            context.fill(f2, with: .color(Color.riffitPrimaryPressed))

            // 3. Gold narrow
            var f3 = Path()
            f3.move(to: CGPoint(x: midX - 8, y: groundY))
            f3.addCurve(to: CGPoint(x: midX, y: groundY - 30),
                       control1: CGPoint(x: midX - 10, y: groundY - 15),
                       control2: CGPoint(x: midX - 3, y: groundY - 28))
            f3.addCurve(to: CGPoint(x: midX + 8, y: groundY),
                       control1: CGPoint(x: midX + 3, y: groundY - 28),
                       control2: CGPoint(x: midX + 10, y: groundY - 15))
            f3.closeSubpath()
            context.fill(f3, with: .color(Color.riffitPrimary))

            // 4. Cream tip (narrowest)
            var f4 = Path()
            f4.move(to: CGPoint(x: midX - 3, y: groundY - 5))
            f4.addCurve(to: CGPoint(x: midX, y: groundY - 22),
                       control1: CGPoint(x: midX - 4, y: groundY - 12),
                       control2: CGPoint(x: midX - 1, y: groundY - 20))
            f4.addCurve(to: CGPoint(x: midX + 3, y: groundY - 5),
                       control1: CGPoint(x: midX + 1, y: groundY - 20),
                       control2: CGPoint(x: midX + 4, y: groundY - 12))
            f4.closeSubpath()
            context.fill(f4, with: .color(Color(hex: 0xF5F0D8)))
        }
    }

    private func drawPineTree(
        in context: inout GraphicsContext,
        baseX: CGFloat,
        groundY: CGFloat,
        treeHeight: CGFloat,
        treeWidth: CGFloat
    ) {
        // Trunk
        context.fill(
            Path(CGRect(x: baseX - 3, y: groundY - treeHeight * 0.4,
                         width: 6, height: treeHeight * 0.4)),
            with: .color(Color(hex: 0x1A0E06)))

        // Lower triangle (wider)
        var lower = Path()
        lower.move(to: CGPoint(x: baseX - treeWidth / 2,
                               y: groundY - treeHeight * 0.3))
        lower.addLine(to: CGPoint(x: baseX + treeWidth / 2,
                                  y: groundY - treeHeight * 0.3))
        lower.addLine(to: CGPoint(x: baseX,
                                  y: groundY - treeHeight * 0.75))
        lower.closeSubpath()
        context.fill(lower, with: .color(Color(hex: 0x0F2214)))

        // Upper triangle (narrower)
        var upper = Path()
        upper.move(to: CGPoint(x: baseX - treeWidth * 0.35,
                               y: groundY - treeHeight * 0.55))
        upper.addLine(to: CGPoint(x: baseX + treeWidth * 0.35,
                                  y: groundY - treeHeight * 0.55))
        upper.addLine(to: CGPoint(x: baseX,
                                  y: groundY - treeHeight))
        upper.closeSubpath()
        context.fill(upper, with: .color(Color(hex: 0x0A1A0E)))
    }
}

// MARK: - Story Card

/// A card showing a story in the Storybank list.
struct StoryCard: View {
    let story: Story
    let countsLabel: String

    @AppStorage("riffit_full_name") private var fullName: String = "Timothy"
    @AppStorage("riffit_username") private var username: String = ""
    @AppStorage("riffit_profile_image") private var profileImageBase64: String = ""

    /// Profile image decoded from base64, nil if empty or invalid
    private var profileImage: UIImage? {
        guard !profileImageBase64.isEmpty,
              let data = Data(base64Encoded: profileImageBase64)
        else { return nil }
        return UIImage(data: data)
    }

    /// First initial of display name for avatar fallback
    private var avatarInitial: String {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUsername.isEmpty, let first = trimmedUsername.first {
            return String(first).uppercased()
        }
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmedName.first else { return "?" }
        return String(first).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            // Title + status badge
            HStack {
                Text(story.title)
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .lineLimit(2)

                Spacer()

                StoryStatusBadge(status: story.status)
            }

            // Asset/reference counts
            Text(countsLabel)
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextSecondary)

            // Timestamp + author avatar
            HStack {
                Text(story.updatedAt.relativeTimestamp)
                    .font(RF.meta)
                    .foregroundStyle(Color.riffitTextTertiary)

                Spacer()

                // Author avatar — 20×20 circle
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                } else {
                    Text(avatarInitial)
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundStyle(Color.riffitTeal400)
                        .frame(width: 28, height: 28)
                        .background(Color.riffitTealTint)
                        .clipShape(Circle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.card)
        .overlay(
            RoundedRectangle(cornerRadius: RR.card)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - Story Status Badge

/// Capsule badge showing draft/ready status.
struct StoryStatusBadge: View {
    let status: Story.Status

    var body: some View {
        Text(status.label)
            .font(RF.tag)
            .foregroundStyle(foregroundColor)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch status {
        case .draft:
            return Color.riffitTextSecondary
        case .ready:
            return Color.riffitPrimary
        case .archived:
            return Color.riffitTextTertiary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .draft:
            return Color.riffitSurface
        case .ready:
            return Color.riffitPrimaryTint
        case .archived:
            return Color.riffitSurface
        }
    }
}

extension Story.Status {
    var label: String {
        switch self {
        case .draft: return "Draft"
        case .ready: return "Ready"
        case .archived: return "Archived"
        }
    }
}

// MARK: - Story Folder Row

/// Displays a folder in the Storybank list.
struct StoryFolderRow: View {
    let folder: StoryFolder
    let count: Int

    var body: some View {
        HStack(spacing: RS.smPlus) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(Color.riffitPrimary)

            Text(folder.name)
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            Spacer()

            Text("\(count)")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)

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
}

// MARK: - Story Folder Drop Target

/// Wraps a StoryFolderRow with drop-target behavior so stories
/// can be dragged onto a folder to organize them.
struct StoryFolderDropTarget: View {
    let folder: StoryFolder
    @ObservedObject var viewModel: StorybankViewModel
    @State private var isTargeted: Bool = false

    var body: some View {
        NavigationLink(value: folder) {
            StoryFolderRow(
                folder: folder,
                count: viewModel.stories(in: folder).count
            )
            .overlay(
                RoundedRectangle(cornerRadius: RR.card)
                    .stroke(Color.riffitPrimary, lineWidth: isTargeted ? 2 : 0)
            )
            .scaleEffect(isTargeted ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isTargeted)
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first,
                  let storyId = UUID(uuidString: idString),
                  viewModel.stories.contains(where: { $0.id == storyId })
            else { return false }
            viewModel.moveStory(storyId, to: folder.id)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}

// MARK: - Story Folder Detail View

/// Shows the stories inside a folder. Supports renaming, deleting
/// the folder, and removing stories from it.
struct StoryFolderDetailView: View {
    let folder: StoryFolder
    @ObservedObject var viewModel: StorybankViewModel

    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    @State private var showDeleteConfirm: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            let folderStories = viewModel.stories(in: folder)

            if folderStories.isEmpty {
                VStack(spacing: RS.sm) {
                    Text("No stories in this folder")
                        .font(RF.bodyMd)
                        .foregroundStyle(Color.riffitTextTertiary)

                    Text("Drag stories here to organize them.")
                        .font(RF.caption)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, RS.lg)
            } else {
                ScrollView {
                    LazyVStack(spacing: RS.smPlus) {
                        ForEach(folderStories) { story in
                            NavigationLink(value: story) {
                                StoryCard(story: story, countsLabel: viewModel.countsLabel(for: story.id))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    viewModel.moveStory(story.id, to: nil)
                                } label: {
                                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                                }
                            }
                            .draggable(story.id.uuidString)
                        }
                    }
                    .padding(.horizontal, RS.md)
                    .padding(.vertical, RS.smPlus)
                }
                .navigationDestination(for: Story.self) { story in
                    StoryDetailView(story: story, viewModel: viewModel)
                }
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        renameText = folder.name
                        showRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .riffitModal(isPresented: $showRenameAlert) {
            RiffitInputModal(
                title: "Rename Folder",
                placeholder: "Folder name",
                actionLabel: "Save",
                text: $renameText,
                onCancel: {
                    showRenameAlert = false
                },
                onAction: { name in
                    viewModel.renameFolder(folder, to: name)
                    showRenameAlert = false
                }
            )
        }
        .riffitModal(isPresented: $showDeleteConfirm) {
            RiffitConfirmModal(
                title: "Delete Folder?",
                message: "Stories inside will be moved to Unfiled.",
                actionLabel: "Delete",
                onCancel: {
                    showDeleteConfirm = false
                },
                onAction: {
                    viewModel.deleteFolder(folder)
                    showDeleteConfirm = false
                    dismiss()
                }
            )
        }
    }
}
