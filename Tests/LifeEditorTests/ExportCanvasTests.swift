import Testing
@testable import LifeEditor

@Test func exportCanvasPreservesProjectAndOffersEvenSocialSizes(){
    #expect(ExportCanvas.project.dimensions(shortEdge:1080)==nil)
    for size in [720,1080,2160] {
        let portrait=ExportCanvas.portrait.dimensions(shortEdge:size)!
        let landscape=ExportCanvas.landscape.dimensions(shortEdge:size)!
        let square=ExportCanvas.square.dimensions(shortEdge:size)!
        let feed=ExportCanvas.feed.dimensions(shortEdge:size)!
        #expect(portrait.width==size && portrait.height==landscape.width)
        #expect(landscape.height==size && square.width==size && square.height==size)
        #expect(feed.width==size && feed.height==size*5/4/2*2)
        #expect([portrait,landscape,square,feed].allSatisfy{$0.width%2==0 && $0.height%2==0})
    }
}
