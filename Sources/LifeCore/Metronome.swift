import Foundation

public enum Metronome {
    public static func events(grid:MusicalGrid,from:RationalTime,to:RationalTime,subdivisions:Bool)->[MusicalDivision]{
        grid.divisions(from:from,to:to,maximumCount:256).filter{subdivisions || $0.subdivisionIndex==0}
    }
    public static func samples(accent:Bool,sampleRate:Int=48000,gain:Double=0.12)->[Float]{
        guard (8000...192000).contains(sampleRate),gain.isFinite,(0...1).contains(gain) else{return []}
        let count=sampleRate/40,frequency=accent ? 1760.0:1100.0
        return (0..<count).map{index in
            let t=Double(index)/Double(sampleRate),fade=1-Double(index)/Double(count)
            return Float(gain*sin(2 * .pi*frequency*t)*fade*fade)
        }
    }
}
