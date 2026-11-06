import Testing
@testable import LifeCore

@Test func monitorClickEventsFollowAnchorsSwingAndSignature(){
    let grid=MusicalGrid(bpm:120,beatsPerBar:3,subdivision:2,anchors:[.init(time:.zero,beatIndex:0),.init(time:.init(value:2,timescale:1),beatIndex:3)],swing:0.5)
    let beats=Metronome.events(grid:grid,from:.zero,to:.init(value:2,timescale:1),subdivisions:false)
    #expect(beats.count==4)
    #expect(beats.map(\.time)==[.zero,.init(value:2,timescale:3),.init(value:4,timescale:3),.init(value:2,timescale:1)])
    #expect(beats.first?.isBar==true && beats.last?.isBar==true)
    let divisions=Metronome.events(grid:grid,from:.zero,to:.init(value:2,timescale:1),subdivisions:true)
    #expect(divisions.count==7)
    #expect(divisions[1].time > RationalTime(value:1,timescale:3))
    let sound=Metronome.samples(accent:true)
    #expect(sound.count==1200)
    #expect(sound.first==0 && abs(sound.last ?? 1)<0.00001)
    #expect(sound.allSatisfy{$0.isFinite && abs($0)<=0.12})
    #expect(Metronome.samples(accent:false,gain:Double.nan).isEmpty)
}
