import Foundation
import Testing
import LifeCore
@testable import LifeEditor

@Test func safeGuidesFollowTheCompositionInsideLetterboxAndPillarbox() throws {
    let landscape=try #require(SafeGuideGeometry.layout(mode:.titleAction,viewport:.init(width:800,height:600),composition:.init(width:1920,height:1080)))
    #expect(landscape.canvas==CGRect(x:0,y:75,width:800,height:450))
    #expect(landscape.outlines==[CGRect(x:40,y:97.5,width:720,height:405),CGRect(x:80,y:120,width:640,height:360)])
    let portrait=try #require(SafeGuideGeometry.layout(mode:.social,viewport:.init(width:800,height:600),composition:.init(width:1080,height:1920)))
    #expect(portrait.canvas==CGRect(x:231.25,y:0,width:337.5,height:600))
    let safe=try #require(portrait.outlines.first)
    #expect(safe==CGRect(x:258.25,y:72,width:249.75,height:396))
    #expect(portrait.canvas.contains(safe))
    #expect(portrait.canvas.maxX-safe.maxX>safe.minX-portrait.canvas.minX)
    #expect(portrait.canvas.maxY-safe.maxY>safe.minY-portrait.canvas.minY)
}

@Test func safeGuidesHandleSquareSmallEmptyAndInvalidViewports() throws {
    for side in [1.0,0.01,512] {
        let layout=try #require(SafeGuideGeometry.layout(mode:.titleAction,viewport:.init(width:side,height:side),composition:.init(width:100,height:100)))
        #expect(layout.canvas==CGRect(x:0,y:0,width:side,height:side))
        #expect(layout.outlines.count==2)
        #expect(layout.outlines.allSatisfy{layout.canvas.contains($0)})
    }
    let off=try #require(SafeGuideGeometry.layout(mode:.off,viewport:.init(width:100,height:100),composition:.init(width:100,height:100)))
    #expect(off.outlines.isEmpty)
    for invalid in [CGSize.zero,CGSize(width:-1,height:100),CGSize(width:Double.infinity,height:100),CGSize(width:100,height:Double.nan)] {
        #expect(SafeGuideGeometry.layout(mode:.social,viewport:invalid,composition:.init(width:100,height:100))==nil)
        #expect(SafeGuideGeometry.layout(mode:.social,viewport:.init(width:100,height:100),composition:invalid)==nil)
    }
}

@Test func safeGuidePreferencesRememberStyleAndHonorExistingStartupSetting() throws {
    let name="safe-guide-tests-\(UUID())",defaults=try #require(UserDefaults(suiteName:name))
    defer{defaults.removePersistentDomain(forName:name)}
    #expect(SafeGuidePreferences.initialMode(in:defaults) == .off)
    defaults.set(true,forKey:SafeGuidePreferences.defaultKey)
    #expect(SafeGuidePreferences.initialMode(in:defaults) == .titleAction)
    SafeGuidePreferences.remember(.social,in:defaults)
    #expect(SafeGuidePreferences.initialMode(in:defaults) == .social)
    SafeGuidePreferences.remember(.off,in:defaults)
    #expect(SafeGuidePreferences.preferredMode(in:defaults) == .social)
    defaults.set(false,forKey:SafeGuidePreferences.defaultKey)
    #expect(SafeGuidePreferences.initialMode(in:defaults) == .off)
    defaults.set("unknown-future-mode",forKey:SafeGuidePreferences.modeKey)
    #expect(SafeGuidePreferences.preferredMode(in:defaults) == .titleAction)
}

@MainActor @Test func changingSafeGuidesDoesNotEditTheProjectOrUndoHistory() throws {
    let store=EditorStore(),original=store.document,dirty=store.dirty,canUndo=store.canUndo
    let defaults=UserDefaults.standard,oldMode=defaults.object(forKey:SafeGuidePreferences.modeKey)
    defer {
        if let oldMode{defaults.set(oldMode,forKey:SafeGuidePreferences.modeKey)}
        else{defaults.removeObject(forKey:SafeGuidePreferences.modeKey)}
    }
    for mode in SafeGuideMode.allCases {
        store.safeGuideMode=mode
        #expect(store.document==original)
        #expect(store.dirty==dirty)
        #expect(store.canUndo==canUndo)
        #expect(store.safeAreas==(mode != .off))
    }
    store.safeAreas=false
    #expect(store.safeGuideMode == .off)
    store.safeAreas=true
    #expect(store.safeGuideMode == .social)
}
