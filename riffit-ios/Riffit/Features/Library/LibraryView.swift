import SwiftUI

/// The main screen — folders at the top, unfiled ideas below.
/// Drag an idea onto a folder to organize it.
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showAddSheet: Bool = false
    @State private var showNewFolderAlert: Bool = false
    @State private var showActionSheet: Bool = false
    @State private var newFolderName: String = ""

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
                mainContent
            }
        }
        .navigationTitle("Ideas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Ideas")
                    .riffitPageTitle()
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
        .sheet(isPresented: $showAddSheet) {
            AddInspirationView(viewModel: viewModel)
        }
        .riffitModal(isPresented: $showActionSheet) {
            RiffitActionModal(
                actions: [
                    .init(label: "New Idea", icon: "lightbulb") {
                        showAddSheet = true
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
            await viewModel.fetchVideos()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: .smPlus) {
                // Folders section
                if !viewModel.folders.isEmpty {
                    foldersSection
                }

                // Unfiled ideas
                let unfiled = viewModel.unfiledVideos
                if !unfiled.isEmpty {
                    if !viewModel.folders.isEmpty {
                        sectionHeader("Unfiled")
                    }

                    ForEach(unfiled) { video in
                        NavigationLink(value: video) {
                            IdeaRow(video: video, tags: viewModel.tags(for: video.id))
                        }
                        .buttonStyle(.plain)
                        .draggable(video.id.uuidString)
                    }
                }
            }
            .padding(.horizontal, .md)
            .padding(.vertical, .smPlus)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .navigationDestination(for: InspirationVideo.self) { video in
            InspirationDetailView(video: video, viewModel: viewModel)
        }
        .navigationDestination(for: IdeaFolder.self) { folder in
            FolderDetailView(folder: folder, viewModel: viewModel)
        }
    }

    // MARK: - Folders Section

    private var foldersSection: some View {
        ForEach(viewModel.folders) { folder in
            FolderDropTarget(folder: folder, viewModel: viewModel)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .riffitLabel()
            .foregroundStyle(Color.riffitTextTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, .sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ZStack {
            // Grid background — adaptive: beige in light, dark in dark
            gridBackground

            VStack(spacing: .md) {
                Spacer()

                // Wave barrel illustration
                WaveBarrelIllustration()
                    .frame(width: 180, height: 180)

                Text("Nothing here yet")
                    .font(.riffitHeading)
                    .foregroundStyle(Color.riffitTextPrimary)

                Text("Catch a reel. Drop it here.")
                    .font(.riffitCaption)
                    .foregroundStyle(Color.riffitTextSecondary)

                RiffitButton(title: "Drop your first reel", variant: .primary) {
                    showAddSheet = true
                }
                .padding(.horizontal, .xl2)
                .padding(.top, .sm)

                Spacer()
            }
        }
    }

    /// Beige grid background for empty states.
    /// Does NOT ignore safe area — nav bar keeps its own background.
    private var gridBackground: some View {
        Canvas { context, size in
            // Fill with grid background color
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.riffitGridBackground)
            )

            // Vertical grid lines — 73pt spacing
            let verticalSpacing: CGFloat = 73
            var x: CGFloat = verticalSpacing
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Color.riffitGridLine), lineWidth: 0.4)
                x += verticalSpacing
            }

            // Horizontal grid lines — 85pt spacing
            let horizontalSpacing: CGFloat = 85
            var y: CGFloat = horizontalSpacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.riffitGridLine), lineWidth: 0.4)
                y += horizontalSpacing
            }
        }
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    let folder: IdeaFolder
    let count: Int

    var body: some View {
        HStack(spacing: .smPlus) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(Color.riffitPrimary)

            Text(folder.name)
                .riffitHeading()
                .foregroundStyle(Color.riffitTextPrimary)

            Spacer()

            Text("\(count)")
                .riffitCaption()
                .foregroundStyle(Color.riffitTextTertiary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .padding(.md)
        .background(Color.riffitSurface)
        .cornerRadius(.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .cardRadius)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - Folder Drop Target

/// Wraps a FolderRow with drop-target behavior and a highlight when
/// an idea is dragged over it. Folders themselves are never draggable.
struct FolderDropTarget: View {
    let folder: IdeaFolder
    @ObservedObject var viewModel: LibraryViewModel
    @State private var isTargeted: Bool = false

    var body: some View {
        NavigationLink(value: folder) {
            FolderRow(
                folder: folder,
                count: viewModel.videos(in: folder).count
            )
            // Highlight border when a drag hovers over this folder
            .overlay(
                RoundedRectangle(cornerRadius: .cardRadius)
                    .stroke(Color.riffitPrimary, lineWidth: isTargeted ? 2 : 0)
            )
            .scaleEffect(isTargeted ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isTargeted)
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first,
                  let videoId = UUID(uuidString: idString),
                  // Only accept video IDs, not folder IDs
                  viewModel.videos.contains(where: { $0.id == videoId })
            else { return false }
            viewModel.moveVideo(videoId, to: folder.id)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}

// MARK: - Idea Row

/// Note is the headline, tags show below it, URL is the footer.
struct IdeaRow: View {
    let video: InspirationVideo
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: .sm) {
            // Note — the primary identifier
            if let note = video.userNote, !note.isEmpty {
                Text(note)
                    .riffitHeading()
                    .foregroundStyle(Color.riffitTextPrimary)
                    .lineLimit(2)
            } else {
                Text("No note")
                    .riffitHeading()
                    .foregroundStyle(Color.riffitTextTertiary)
                    .italic()
            }

            // Tags row
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.riffitTag)
                            .foregroundStyle(Color.riffitPrimary)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .background(Color.riffitPrimaryTint)
                            .clipShape(Capsule())
                    }
                }
            }

            // IG link
            HStack(spacing: 6) {
                Image(systemName: "camera")
                    .font(.caption2)
                    .foregroundStyle(Color.riffitTeal400)

                Text(shortURL)
                    .riffitCaption()
                    .foregroundStyle(Color.riffitTextTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.md)
        .background(Color.riffitSurface)
        .cornerRadius(.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .cardRadius)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    private var shortURL: String {
        guard let url = URL(string: video.url) else { return video.url }
        let path = url.path
        if path.count > 1 {
            return String(path.dropFirst())
        }
        return url.host ?? video.url
    }
}

// MARK: - Wave Barrel Illustration

/// Concentric teal rings with a sunset core — the wave barrel.
/// Ring order adapts to color scheme:
///   Light: #1A8A96 → #0F6B75 → #0A4A52 → gold → amber → coral
///   Dark:  #0A4A52 → #0F6B75 → #1A8A96 → gold → amber → coral
struct WaveBarrelIllustration: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2

            // Teal ring order flips between light and dark mode
            let tealColors: [Color] = colorScheme == .dark
                ? [.riffitTeal900, .riffitTeal600, .riffitTeal400]  // dark outer → light inner
                : [.riffitTeal400, .riffitTeal600, .riffitTeal900]  // light outer → dark inner

            let tealRadii: [CGFloat] = [1.0, 0.82, 0.64]

            for (i, color) in tealColors.enumerated() {
                let r = maxRadius * tealRadii[i]
                let rect = CGRect(
                    x: center.x - r, y: center.y - r,
                    width: r * 2, height: r * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }

            // Sunset core (same in both modes: gold → amber → coral)
            let sunsetRings: [(color: Color, radiusFraction: CGFloat)] = [
                (.riffitPrimary, 0.46),
                (.riffitPrimaryPressed, 0.30),
                (Color.riffitDanger, 0.16),
            ]

            for ring in sunsetRings {
                let r = maxRadius * ring.radiusFraction
                let rect = CGRect(
                    x: center.x - r, y: center.y - r,
                    width: r * 2, height: r * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(ring.color))
            }

            // White foam arc at the top of the barrel
            let foamRadius = maxRadius * 0.95
            var foamPath = Path()
            foamPath.addArc(
                center: center,
                radius: foamRadius,
                startAngle: .degrees(-160),
                endAngle: .degrees(-20),
                clockwise: false
            )
            context.stroke(foamPath, with: .color(.white.opacity(0.7)), lineWidth: 2.5)

            // Two water lines below the barrel
            let lineY1 = center.y + maxRadius + 12
            let lineY2 = center.y + maxRadius + 22

            for lineY in [lineY1, lineY2] {
                var linePath = Path()
                linePath.move(to: CGPoint(x: center.x - 30, y: lineY))
                linePath.addQuadCurve(
                    to: CGPoint(x: center.x + 30, y: lineY),
                    control: CGPoint(x: center.x, y: lineY - 5)
                )
                context.stroke(linePath, with: .color(Color.riffitTeal600.opacity(0.5)), lineWidth: 1.5)
            }
        }
    }
}

// MARK: - InspirationVideo Hashable (for NavigationLink)

extension InspirationVideo: Hashable {
    static func == (lhs: InspirationVideo, rhs: InspirationVideo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
