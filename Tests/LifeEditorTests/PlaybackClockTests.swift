import AVFoundation
import Testing
import LifeCore
@testable import LifeEditor

@MainActor private func playbackClockStore()->EditorStore {
    let store=EditorStore()
    store.document.sequence.settings.frameRate=FrameRate(numerator:30000,denominator:1001)
    store.document.sequence.tracks=[Track(name:"Clock",kind:.title,clips:[Clip(duration:.init(value:10,timescale:1),title:.init(text:"Clock"))])]
    return store
}

@MainActor @Test func pausedPlaybackCallbacksCannotOverrideExactSeekOrSteps(){
    let store=playbackClockStore(),rate=store.document.sequence.settings.frameRate
    store.seek(rate.time(forFrame:30))
    // Old item positions and the new item's initial zero can arrive after
    // explicit seeks. Neither owns the transport while it is paused.
    for frame in 31...90 {
        store.step(1)
        store.updatePlaybackClock(.zero)
        store.updatePlaybackClock(CMTime(value:1001,timescale:30000))
        store.updatePlaybackClock(.invalid)
        #expect(store.playheadTime==rate.time(forFrame:Int64(frame)))
        #expect(!store.playing)
    }
    store.seek(rate.time(forFrame:45))
    store.updatePlaybackClock(CMTime(value:9,timescale:1))
    #expect(store.playheadTime==rate.time(forFrame:45))
}

@MainActor @Test func playingPlaybackCallbacksAdvanceAndStopAtSequenceEnd(){
    let store=playbackClockStore()
    store.playing=true
    store.updatePlaybackClock(CMTime(value:1001,timescale:30000))
    #expect(store.playheadTime==RationalTime(value:1001,timescale:30000))
    #expect(store.playing)
    store.updatePlaybackClock(CMTime(value:10,timescale:1))
    #expect(store.playheadTime==RationalTime(value:10,timescale:1))
    #expect(!store.playing)
    store.updatePlaybackClock(.zero)
    #expect(store.playheadTime==RationalTime(value:10,timescale:1))
}

@MainActor @Test func playingPlaybackCallbacksStillStopAtArmedRangeEnd(){
    let store=playbackClockStore()
    store.document.sequence.settings.frameRate=FrameRate()
    // A range can be armed independently of any decision being recorded.
    store.document.sequence.multicamGroups=[MulticamGroup(angleAssetIDs:[])]
    store.switchArmed=true;store.replaceSwitchRange=true
    store.switchRangeStart=1;store.switchRangeEnd=3
    store.togglePlayback()
    #expect(store.playing);#expect(store.playheadTime==RationalTime(value:1,timescale:1))
    store.updatePlaybackClock(CMTime(value:5,timescale:2))
    #expect(store.playing)
    store.updatePlaybackClock(CMTime(value:3,timescale:1))
    #expect(!store.playing);#expect(store.playheadTime==RationalTime(value:3,timescale:1))
    store.updatePlaybackClock(.zero)
    #expect(store.playheadTime==RationalTime(value:3,timescale:1))
}
