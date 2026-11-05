import Testing
import Foundation
import LifeCore
@testable import LifeEditor

@MainActor @Test func openedProjectUsesPackageNameWithoutChangingSavedContent() throws {
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent("life-project-name-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    defer {try? FileManager.default.removeItem(at:directory)}
    let url=directory.appendingPathComponent("Rehearsal delivery.lifeedit")
    let document=ProjectDocument(name:"Untitled")
    try ProjectPackage.write(document,to:url)
    let store=EditorStore()
    store.openProject(url)
    #expect(store.error == nil)
    #expect(store.projectDisplayName == "Rehearsal delivery")
    #expect(store.document == document)
    #expect(store.save())
    #expect(try ProjectPackage.read(from:url) == document)
    store.newProject()
    #expect(store.projectDisplayName == store.document.name)
    #expect(store.projectDisplayName != "Rehearsal delivery")
}
