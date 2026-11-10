import Foundation
import LifeCore

extension EditorStore {
    func trackDuplicationUnavailableReason(_ id: UUID) -> String? {
        guard placementProposal == nil else { return "Apply or cancel the placement preview first." }
        guard !(playing && switchArmed) else { return "Stop the switching pass before duplicating tracks." }
        guard let track = document.sequence.tracks.first(where: { $0.id == id }) else { return "Track unavailable." }
        guard !track.isLocked else { return "Unlock the track to duplicate it." }
        guard !TrackDuplication.isMulticamMember(track, in: document) else {
            return TrackDuplicationError.multicamMember.localizedDescription
        }
        return nil
    }

    func canDuplicateTrack(_ id: UUID) -> Bool {
        trackDuplicationUnavailableReason(id) == nil
    }

    @discardableResult func duplicateTrack(_ id: UUID) -> Bool {
        if let reason = trackDuplicationUnavailableReason(id) {
            error = reason
            return false
        }
        do {
            let candidate = try TrackDuplication.duplicating(trackID: id, in: document)
            let previousIDs = Set(document.sequence.tracks.map(\.id))
            replace(candidate)
            guard document == candidate,
                  let track = document.sequence.tracks.first(where: { !previousIDs.contains($0.id) }) else { return false }
            selectedTransition = nil
            selection = track.clips.first?.id
            selectedIDs = Set(track.clips.map(\.id))
            panel = .clip
            return true
        } catch {
            self.error = Self.message(error)
            return false
        }
    }
}
