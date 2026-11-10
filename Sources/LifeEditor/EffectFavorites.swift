import Foundation
import LifeCore

/// Keep registry order inside each section, and retain saved IDs from newer builds.
struct EffectFavorites:Equatable {
    private(set) var ids:Set<String>
    init(_ raw:String){ids=Set(raw.split(separator:",").map(String.init))}
    var rawValue:String{ids.sorted().joined(separator:",")}
    func contains(_ id:String)->Bool{ids.contains(id)}
    mutating func toggle(_ id:String){if ids.contains(id){ids.remove(id)}else{ids.insert(id)}}
    func ordered(_ definitions:[EffectDefinition],onlyFavorites:Bool=false)->[EffectDefinition]{
        let visible=definitions.filter{!onlyFavorites || contains($0.stableID)}
        return visible.filter{contains($0.stableID)}+visible.filter{!contains($0.stableID)}
    }
}
