import Foundation
import Testing
@testable import LifeCore

@Test func trackDuplicationPreservesTimingAndIndependentNestedIdentities() throws {
    let link = UUID(), group = UUID(), effect = NativeEffectRegistry.make("life.adjust.saturation")
    var timing = TitleWordTiming(text: "Copy timing")
    timing.words[0].start = .zero
    timing.words[0].end = .init(value: 1, timescale: 1)
    let point = AutomationPoint(time: .zero, value: 0.75, interpolation: .hold)
    let curve = PropertyAnimation(property: .effectStrength, effectID: effect.id,
                                  points: [point], evaluationOffset: .init(value: 1, timescale: 2),
                                  timeScale: .init(value: 2, timescale: 1))
    let first = Clip(name: "First", start: .zero, duration: .init(value: 2, timescale: 1),
                     linkID: link, volume: .init(points: [point]), opacity: .init(points: [point]),
                     title: .init(text: timing.sourceText, wordTiming: timing), effects: [effect], groupID: group,
                     visualAnimation: .init(keyframes: [.init(time: .zero, visual: .init(x: 0.3))]),
                     propertyAnimations: [curve])
    let second = Clip(name: "Second", start: first.end, duration: first.duration, linkID: link,
                      title: .init(text: "Second"), groupID: group)
    let outside = Clip(name: "Outside", duration: first.duration, linkID: link,
                       title: .init(text: "Outside"), groupID: group)
    let source = Track(name: "Captions", kind: .caption, clips: [first, second], isHidden: true)
    let transition = VideoTransition(kind: .crossDissolve, trackID: source.id, leftClipID: first.id,
                                    rightClipID: second.id, duration: .init(value: 1, timescale: 1))
    let marker = Marker(time: .init(value: 1, timescale: 1), name: "Word", clipID: first.id)
    let globalMarker = Marker(time: .zero, name: "Sequence")
    let original = ProjectDocument(sequence: .init(tracks: [source, .init(name: "Other", kind: .title, clips: [outside])],
                                                  markers: [marker, globalMarker], transitions: [transition]))
    let duplicated = try TrackDuplication.duplicating(trackID: source.id, in: original)
    let copied = duplicated.sequence.tracks[1]
    let clip = copied.clips[0]
    #expect(duplicated.sequence.tracks[0] == source)
    #expect(duplicated.sequence.tracks[2] == original.sequence.tracks[1])
    #expect(copied.id != source.id && copied.name == "Captions Copy" && copied.isHidden)
    #expect(Set(copied.clips.map(\.id)).isDisjoint(with: Set(source.clips.map(\.id))))
    #expect(copied.clips[0].linkID == copied.clips[1].linkID && copied.clips[0].linkID != link)
    #expect(copied.clips[0].groupID == copied.clips[1].groupID && copied.clips[0].groupID != group)
    #expect(clip.start == first.start && clip.duration == first.duration && clip.sourceStart == first.sourceStart)
    #expect(clip.volume.value(at: .zero) == first.volume.value(at: .zero))
    #expect(clip.volume.points[0].id != point.id && clip.opacity.points[0].id != point.id)
    #expect(clip.visualAnimation?.keyframes[0].id != first.visualAnimation?.keyframes[0].id)
    #expect(clip.visualTransform(at: .zero) == first.visualTransform(at: .zero))
    #expect(clip.title?.wordTiming?.words[0].id != timing.words[0].id)
    #expect(clip.title?.wordTiming?.activeWord(at: .zero, text: timing.sourceText)?.text == "Copy")
    #expect(clip.propertyAnimations?[0].id != curve.id)
    #expect(clip.propertyAnimations?[0].points[0].id != point.id)
    #expect(clip.propertyAnimations?[0].effectID == clip.effects?[0].id)
    #expect(clip.effects?[0].id != effect.id)
    #expect(clip.propertyAnimations?[0].evaluationOffset == curve.evaluationOffset)
    #expect(clip.propertyAnimations?[0].timeScale == curve.timeScale)
    #expect(clip.evaluatedProperties(at: .zero).effects?[0].strength == first.evaluatedProperties(at: .zero).effects?[0].strength)
    let copiedTransition = try #require(duplicated.sequence.transitions?.last)
    #expect(copiedTransition.id != transition.id && copiedTransition.trackID == copied.id)
    #expect(copiedTransition.leftClipID == clip.id && copiedTransition.rightClipID == copied.clips[1].id)
    #expect(TransitionResolver.resolve(copiedTransition, in: duplicated) != nil)
    #expect(duplicated.sequence.markers.count == 3)
    #expect(duplicated.sequence.markers[2].clipID == clip.id && duplicated.sequence.markers[2].id != marker.id)
    #expect(try ProjectDocument.decode(duplicated.encoded()) == duplicated)
}

@Test func trackDuplicationKeepsMediaAndDrawingAndNamesIndependent() throws {
    let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/track-duplicate-original.wav"), kind: .audio,
                           duration: .init(value: 4, timescale: 1))
    let sound = Clip(assetID: asset.id, duration: asset.duration, audio: .init(pan: 0.25))
    let source = Track(name: "Music", kind: .audio, clips: [sound], isMuted: true, isSoloed: true)
    let original = ProjectDocument(sequence: .init(tracks: [source, .init(name: "Music Copy", kind: .audio)]), assets: [asset])
    let duplicate = try TrackDuplication.duplicating(trackID: source.id, in: original)
    let copied = duplicate.sequence.tracks[1]
    #expect(copied.name == "Music Copy 2" && copied.isMuted && copied.isSoloed)
    #expect(copied.clips[0].assetID == asset.id && copied.clips[0].audio == sound.audio)
    #expect(duplicate.assets == original.assets)

    let stroke = DrawingStroke(points: [.init(x: 0.1, y: 0.1), .init(x: 0.5, y: 0.5)])
    let drawing = Clip(duration: .init(value: 2, timescale: 1), graphic: .drawing(.init(strokes: [stroke])))
    let drawingTrack = Track(name: "Drawing", kind: .drawing, clips: [drawing])
    let drawingCopy = try TrackDuplication.duplicating(trackID: drawingTrack.id,
                                                     in: .init(sequence: .init(tracks: [drawingTrack])))
    guard case .drawing(let copiedDrawing) = drawingCopy.sequence.tracks[1].clips[0].graphic else {
        Issue.record("Missing duplicated drawing")
        return
    }
    #expect(copiedDrawing.strokes[0].id != stroke.id)
    #expect(copiedDrawing.strokes[0].points == stroke.points)
}

@Test func trackDuplicationSupportsEmptyTracksAndRejectsLocksMissingAndMulticamMembers() throws {
    let empty = Track(name: "Empty", kind: .audio)
    let original = ProjectDocument(sequence: .init(tracks: [empty]))
    let duplicate = try TrackDuplication.duplicating(trackID: empty.id, in: original)
    #expect(duplicate.sequence.tracks.count == 2 && duplicate.sequence.tracks[1].clips.isEmpty)
    #expect(duplicate.sequence.tracks[1].id != empty.id)
    #expect(throws: DocumentError.trackNotFound) {
        try TrackDuplication.duplicating(trackID: UUID(), in: original)
    }
    var locked = original
    locked.sequence.tracks[0].isLocked = true
    #expect(throws: DocumentError.lockedTrack) {
        try TrackDuplication.duplicating(trackID: empty.id, in: locked)
    }
    let camera = MediaAsset(url: URL(fileURLWithPath: "/tmp/camera.mov"), kind: .video, duration: .init(value: 4, timescale: 1))
    let audio = MediaAsset(url: URL(fileURLWithPath: "/tmp/master.wav"), kind: .audio, duration: camera.duration)
    let cameraTrack = Track(name: "Camera", kind: .video, clips: [.init(assetID: camera.id, duration: camera.duration)])
    let masterTrack = Track(name: "Master", kind: .audio, clips: [.init(assetID: audio.id, duration: audio.duration)])
    let multicam = ProjectDocument(sequence: .init(tracks: [cameraTrack, masterTrack], multicamGroups: [
        .init(angleAssetIDs: [camera.id], masterAudioAssetID: audio.id)
    ]), assets: [camera, audio])
    for track in multicam.sequence.tracks {
        #expect(TrackDuplication.isMulticamMember(track, in: multicam))
        #expect(throws: TrackDuplicationError.multicamMember) {
            try TrackDuplication.duplicating(trackID: track.id, in: multicam)
        }
    }
}

@Test func trackDuplicationPreservesUnknownEffectsAndRepeatedLegacyEffectIDs() throws {
    let effect = EffectInstance(stableID: "vendor.unavailable", parameters: ["custom": 7], strength: 0.4, seed: 123)
    let clip = Clip(duration: .init(value: 1, timescale: 1), title: .init(text: "Legacy"), effects: [effect, effect])
    let track = Track(name: "Legacy", kind: .title, clips: [clip])
    let original = ProjectDocument(sequence: .init(tracks: [track]))
    let duplicated = try TrackDuplication.duplicating(trackID: track.id, in: original)
    let effects = try #require(duplicated.sequence.tracks[1].clips[0].effects)
    #expect(effects.count == 2 && effects[0].id != effects[1].id)
    #expect(effects.allSatisfy { $0.id != effect.id && $0.stableID == effect.stableID && $0.parameters == effect.parameters && $0.seed == effect.seed })
    #expect(duplicated.sequence.tracks[0] == track)
    #expect(try ProjectDocument.decode(duplicated.encoded()) == duplicated)
}
