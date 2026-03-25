import Foundation

/// A user's collaboration record on a shared Story.
/// Maps to the `story_collaborators` table in Supabase.
/// Each record represents one user's access to one story,
/// including their role (what they can do) and status (pending/accepted/declined).
struct StoryCollaborator: Identifiable, Codable, Hashable {
    let id: UUID
    let storyId: UUID
    let userId: UUID
    var role: CollaboratorRole
    let invitedBy: UUID?
    var status: CollaboratorStatus
    let createdAt: Date
    var acceptedAt: Date?
    /// When the collaborator last opened this story — drives the unread dot indicator.
    /// If any story_notes.created_at > lastViewedAt, the story has unread notes.
    var lastViewedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case userId = "user_id"
        case role
        case invitedBy = "invited_by"
        case status
        case createdAt = "created_at"
        case acceptedAt = "accepted_at"
        case lastViewedAt = "last_viewed_at"
    }

    init(
        id: UUID = UUID(),
        storyId: UUID,
        userId: UUID,
        role: CollaboratorRole = .collaborator,
        invitedBy: UUID? = nil,
        status: CollaboratorStatus = .pending,
        createdAt: Date = Date(),
        acceptedAt: Date? = nil,
        lastViewedAt: Date? = nil
    ) {
        self.id = id
        self.storyId = storyId
        self.userId = userId
        self.role = role
        self.invitedBy = invitedBy
        self.status = status
        self.createdAt = createdAt
        self.acceptedAt = acceptedAt
        self.lastViewedAt = lastViewedAt
    }
}

// MARK: - CollaboratorRole

/// What a collaborator can do on a shared story.
/// Free/Pro tiers only use `owner` and `collaborator`.
/// Studio+ tiers unlock `editor`, `viewer`, and `commenter` for granular control.
/// See the permission matrix in specs:/STORY_COLLABORATION.md for full details.
enum CollaboratorRole: String, Codable, CaseIterable {
    case owner
    case editor
    case viewer
    case commenter
    /// Simplified role for Free/Pro tiers — can view, download, and leave notes,
    /// but cannot modify assets, sections, or references.
    case collaborator

    /// Human-readable label for display in role pills.
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .editor: return "Editor"
        case .viewer: return "Viewer"
        case .commenter: return "Commenter"
        case .collaborator: return "Collaborator"
        }
    }

    // MARK: - Permission checks based on the spec's permission matrix

    var canViewAssets: Bool { true }

    var canDownloadAssets: Bool {
        switch self {
        case .owner, .editor, .viewer, .collaborator: return true
        case .commenter: return false
        }
    }

    var canModifyAssets: Bool {
        switch self {
        case .owner, .editor: return true
        case .viewer, .commenter, .collaborator: return false
        }
    }

    var canModifySections: Bool { canModifyAssets }

    var canModifyReferences: Bool { canModifyAssets }

    var canLeaveNotes: Bool {
        switch self {
        case .owner, .editor, .commenter, .collaborator: return true
        case .viewer: return false
        }
    }

    var canEditOwnNotes: Bool { canLeaveNotes }

    var canDeleteOthersNotes: Bool {
        self == .owner
    }

    var canInviteCollaborators: Bool {
        self == .owner
    }

    var canRemoveCollaborators: Bool {
        self == .owner
    }

    var canChangeRoles: Bool {
        self == .owner
    }

    var canRenameStory: Bool {
        switch self {
        case .owner, .editor: return true
        case .viewer, .commenter, .collaborator: return false
        }
    }

    var canDeleteStory: Bool {
        self == .owner
    }

    var canDuplicateStory: Bool {
        switch self {
        case .owner, .editor: return true
        case .viewer, .commenter, .collaborator: return false
        }
    }
}

// MARK: - CollaboratorStatus

/// The state of a collaboration invitation.
enum CollaboratorStatus: String, Codable, CaseIterable {
    case pending
    case accepted
    case declined
}
