import Foundation

public enum TrackDuplicationError: Error, LocalizedError, Equatable {
    case multicamMember

    public var errorDescription: String? {
        "Duplicate ordinary tracks outside the multicam group."
    }
}

public enum TrackDuplication {
    /// Membership is inferred from media IDs by the compiler, including master audio.
    public static func isMulticamMember(_ track: Track, in document: ProjectDocument) -> Bool {
        let mediaIDs = Set(track.clips.compactMap(\.assetID))
        return document.sequence.multicamGroups.contains { group in
            var members = Set(group.angleAssetIDs + (group.audioAssetIDs ?? []))
            if let master = group.masterAudioAssetID { members.insert(master) }
            return !mediaIDs.isDisjoint(with: members)
        }
    }

    /// Places the copy immediately above its source with an independent editing graph.
    /// Media URLs and source clocks stay shared. No media files are copied or written.
    public static func duplicating(trackID: UUID, in document: ProjectDocument) throws -> ProjectDocument {
        try document.validate()
        guard let index = document.sequence.tracks.firstIndex(where: { $0.id == trackID }) else {
            throw DocumentError.trackNotFound
        }
        let source = document.sequence.tracks[index]
        guard !source.isLocked else { throw DocumentError.lockedTrack }
        guard !isMulticamMember(source, in: document) else { throw TrackDuplicationError.multicamMember }

        let clipIDs = Dictionary(uniqueKeysWithValues: source.clips.map { ($0.id, UUID()) })
        let linkIDs = Dictionary(uniqueKeysWithValues: Set(source.clips.compactMap(\.linkID)).map { ($0, UUID()) })
        let groupIDs = Dictionary(uniqueKeysWithValues: Set(source.clips.compactMap(\.groupID)).map { ($0, UUID()) })
        var copy = source
        copy.id = UUID()
        let names = Set(document.sequence.tracks.map(\.name))
        let baseName = source.name + " Copy"
        copy.name = baseName
        var suffix = 2
        while names.contains(copy.name) {
            copy.name = baseName + " " + String(suffix)
            suffix += 1
        }
        copy.clips = source.clips.map { original in
            var clip = original
            clip.id = clipIDs[original.id]!
            clip.linkID = original.linkID.flatMap { linkIDs[$0] }
            clip.groupID = original.groupID.flatMap { groupIDs[$0] }
            clip.volume.points = freshPoints(original.volume.points)
            clip.opacity.points = freshPoints(original.opacity.points)
            if var animation = original.visualAnimation {
                for key in animation.keyframes.indices { animation.keyframes[key].id = UUID() }
                clip.visualAnimation = animation
            }
            if var title = original.title, var timing = title.wordTiming {
                for word in timing.words.indices { timing.words[word].id = UUID() }
                title.wordTiming = timing
                clip.title = title
            }
            if case .drawing(var drawing) = original.graphic {
                for stroke in drawing.strokes.indices { drawing.strokes[stroke].id = UUID() }
                clip.graphic = .drawing(drawing)
            }
            var effectIDs: [UUID: UUID] = [:]
            clip.effects = original.effects?.map { effect in
                var copied = effect
                copied.id = UUID()
                // Existing documents can contain repeated effect IDs. Curves target
                // the first matching effect, so retain that binding without a trap.
                if effectIDs[effect.id] == nil { effectIDs[effect.id] = copied.id }
                return copied
            }
            clip.propertyAnimations = original.propertyAnimations?.map { animation in
                var copied = animation
                copied.id = UUID()
                copied.points = freshPoints(animation.points)
                copied.effectID = animation.effectID.map { effectIDs[$0] ?? $0 }
                return copied
            }
            return clip
        }

        var result = document
        result.sequence.tracks.insert(copy, at: index + 1)
        let transitions = (document.sequence.transitions ?? []).compactMap { original -> VideoTransition? in
            guard original.trackID == source.id,
                  let left = clipIDs[original.leftClipID], let right = clipIDs[original.rightClipID] else { return nil }
            var transition = original
            transition.id = UUID()
            transition.trackID = copy.id
            transition.leftClipID = left
            transition.rightClipID = right
            return transition
        }
        if !transitions.isEmpty { result.sequence.transitions = (result.sequence.transitions ?? []) + transitions }
        let markers = document.sequence.markers.compactMap { original -> Marker? in
            guard let sourceClipID = original.clipID, let clipID = clipIDs[sourceClipID] else { return nil }
            var marker = original
            marker.id = UUID()
            marker.clipID = clipID
            return marker
        }
        result.sequence.markers.append(contentsOf: markers)
        try result.validate()
        return result
    }

    private static func freshPoints(_ points: [AutomationPoint]) -> [AutomationPoint] {
        points.map { point in
            var copy = point
            copy.id = UUID()
            return copy
        }
    }
}
