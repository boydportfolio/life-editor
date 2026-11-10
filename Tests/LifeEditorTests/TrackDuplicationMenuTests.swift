import AppKit
import Testing
import LifeCore
@testable import LifeEditor

@MainActor @Test func emptyTrackHeaderOffersDuplicateAndHonorsLock()throws {
    _=NSApplication.shared
    let store=EditorStore(),track=Track(name:"Music",kind:.audio)
    store.replace(.init(sequence:.init(tracks:[track])))
    let canvas=TimelineCanvas(store:store);canvas.frame=NSRect(x:0,y:0,width:1000,height:300)
    let window=NSWindow(contentRect:canvas.frame,styleMask:[.titled],backing:.buffered,defer:false)
    window.isReleasedWhenClosed=false;window.contentView=canvas
    defer{window.contentView=nil;window.close()}
    let location=canvas.convert(NSPoint(x:20,y:60),to:nil)
    let event=try #require(NSEvent.mouseEvent(with:.rightMouseDown,location:location,modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1))
    let menu=try #require(canvas.menu(for:event)),item=try #require(menu.items.first{$0.title=="Duplicate Track"})
    #expect(item.isEnabled)
    #expect(NSApp.sendAction(try #require(item.action),to:item.target,from:item))
    #expect(store.document.sequence.tracks.count==2)
    store.undo();#expect(store.document.sequence.tracks==[track])
    var locked=track;locked.isLocked=true;store.replace(.init(sequence:.init(tracks:[locked])))
    let lockedMenu=try #require(canvas.menu(for:event)),disabled=try #require(lockedMenu.items.first{$0.title=="Duplicate Track"})
    #expect(!disabled.isEnabled);#expect(disabled.toolTip != nil)
}
