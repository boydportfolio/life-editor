import Testing
import LifeCore
@testable import LifeEditor

@Test func filterFavoritesKeepRegistryOrderAndRoundTripUnknownIDs(){
    let definitions=NativeEffectRegistry.definitions
    let first=definitions[0].stableID,last=definitions.last!.stableID
    var favorites=EffectFavorites(last+",future.filter,"+first+","+last)
    let ordered=favorites.ordered(definitions)
    #expect(ordered.prefix(2).map(\.stableID)==[first,last])
    #expect(favorites.ordered(definitions,onlyFavorites:true).map(\.stableID)==[first,last])
    #expect(EffectFavorites(favorites.rawValue)==favorites)
    favorites.toggle(first)
    #expect(favorites.ordered(definitions,onlyFavorites:true).map(\.stableID)==[last])
    #expect(favorites.contains("future.filter"))
    favorites.toggle(last)
    #expect(favorites.ordered(definitions,onlyFavorites:true).isEmpty)
    #expect(favorites.ordered(definitions)==definitions)
}
