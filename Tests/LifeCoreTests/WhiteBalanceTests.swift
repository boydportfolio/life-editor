import Foundation
import Testing
import LifeCore

@Test func whiteBalanceNeutralIdentityAndLinearNeutralization()throws{
    for gray in [0.1,0.4,0.8,1.0]{
        let parameters=try #require(WhiteBalance.parameters(neutral:.init(red:gray,green:gray,blue:gray)))
        #expect(WhiteBalance.channels.allSatisfy{parameters[$0]==1})
    }
    let color=RGBAColor(red:0.7,green:0.5,blue:0.4),parameters=try #require(WhiteBalance.parameters(neutral:color))
    let corrected=zip(WhiteBalance.channels,[color.red,color.green,color.blue]).map{parameters[$0.0]!*WhiteBalance.linear($0.1)}
    #expect(abs(corrected[0]-corrected[1])<0.000000001)
    #expect(abs(corrected[1]-corrected[2])<0.000000001)
    let originalLuminance=WhiteBalance.linear(color.red)*0.2126+WhiteBalance.linear(color.green)*0.7152+WhiteBalance.linear(color.blue)*0.0722
    #expect(abs(corrected[0]-originalLuminance)<0.000000001)
}

@Test func whiteBalanceRejectsTransparentDarkInvalidAndExtremeSamples(){
    for sample in [RGBAColor.clear,.black,.init(red:0.02,green:0.02,blue:0.02),.init(red:0.5,green:0.5,blue:0.5,alpha:0.4),.init(red:.nan,green:0.5,blue:0.5),.init(red:1.1,green:0.5,blue:0.5),.init(red:0.9,green:0.05,blue:0.05)]{
        #expect(WhiteBalance.parameters(neutral:sample)==nil)
    }
}

@Test func whiteBalanceRepeatedPickingComposesEffectiveStrengthAndPersists()throws{
    let old=EffectInstance(stableID:WhiteBalance.stableID,parameters:["red":0.8,"green":1.1,"blue":1.2],strength:0.5)
    let neutral=RGBAColor(red:0.5,green:0.5,blue:0.5)
    let combined=try #require(WhiteBalance.parameters(neutral:neutral,correcting:old))
    #expect(abs(combined["red"]!-0.9)<0.000000001)
    #expect(abs(combined["green"]!-1.05)<0.000000001)
    #expect(abs(combined["blue"]!-1.1)<0.000000001)
    let effect=NativeEffectRegistry.make(WhiteBalance.stableID)
    #expect(effect.parameters==["red":1,"green":1,"blue":1])
    let clip=Clip(duration:.init(value:1,timescale:1),title:.init(text:"Balance"),effects:[EffectInstance(stableID:WhiteBalance.stableID,parameters:combined)])
    let document=ProjectDocument(sequence:Sequence(tracks:[Track(name:"Title",kind:.title,clips:[clip])]))
    #expect(try ProjectDocument.decode(JSONEncoder().encode(document))==document)
}
