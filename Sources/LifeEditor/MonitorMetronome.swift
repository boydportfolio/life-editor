import AVFoundation
import Darwin
import LifeCore

/// Output-only monitoring. No click samples enter a project, mix, or export.
@MainActor final class MonitorMetronome {
    private let engine=AVAudioEngine()
    private let player=AVAudioPlayerNode()
    private let format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:2)!
    private var scheduled=Set<RationalTime>()
    private var lastPosition:RationalTime?
    private var lastGrid:MusicalGrid?
    private var lastSubdivisions=false
    private var buffers:[Bool:AVAudioPCMBuffer]=[:]
    init(){engine.attach(player);engine.connect(player,to:engine.mainMixerNode,format:format)}
    func stop(){player.stop();engine.pause();scheduled=[];lastPosition=nil}
    func update(position:RationalTime,grid:MusicalGrid,subdivisions:Bool,gain:Double)throws{
        if lastGrid != grid || lastSubdivisions != subdivisions || lastPosition.map({position<$0 || position.seconds-$0.seconds>0.3}) == true{stop()}
        lastGrid=grid;lastSubdivisions=subdivisions;lastPosition=position
        player.volume=Float(max(0,min(1,gain)))
        if !engine.isRunning{engine.prepare();try engine.start()}
        if !player.isPlaying{player.play()}
        let horizon=min(RationalTime(value:86400,timescale:1),position+RationalTime(value:1,timescale:5))
        let host=mach_absolute_time()
        for event in Metronome.events(grid:grid,from:position,to:horizon,subdivisions:subdivisions) where !scheduled.contains(event.time){
            let delay=max(0,event.time.seconds-position.seconds)
            player.scheduleBuffer(buffer(accent:event.isBar),at:AVAudioTime(hostTime:host+AVAudioTime.hostTime(forSeconds:delay)),options:[])
            scheduled.insert(event.time)
        }
        scheduled=Set(scheduled.filter{$0.seconds>=position.seconds-1})
    }
    private func buffer(accent:Bool)->AVAudioPCMBuffer {
        if let buffer=buffers[accent]{return buffer}
        let samples=Metronome.samples(accent:accent,gain:1)
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(samples.count))!
        buffer.frameLength=AVAudioFrameCount(samples.count)
        for channel in 0..<2{for index in samples.indices{buffer.floatChannelData![channel][index]=samples[index]}}
        buffers[accent]=buffer;return buffer
    }
}
