import Foundation

/// A token is an exact whitespace-delimited range of the original title.
/// Ranges use UTF-16 for Core Text and always begin/end on grapheme boundaries.
public struct TimedTitleWord:Identifiable,Codable,Equatable,Sendable {
    public var id:UUID
    public var text:String
    public var utf16Location:Int
    public var utf16Length:Int
    public var start:RationalTime?
    public var end:RationalTime?
    public init(id:UUID=UUID(),text:String,utf16Location:Int,utf16Length:Int,start:RationalTime?=nil,end:RationalTime?=nil){
        self.id=id;self.text=text;self.utf16Location=utf16Location;self.utf16Length=utf16Length;self.start=start;self.end=end
    }
}

/// Explicit word intervals in the original title clock. Untimed or partially
/// timed tokens remain plain text; no timing is inferred from cue duration.
public struct TitleWordTiming:Codable,Equatable,Sendable {
    public static let maximumWords=500
    public var sourceText:String
    public var words:[TimedTitleWord]
    public var highlightColor:RGBAColor
    public var evaluationOffset:RationalTime
    public var timeScale:RationalTime
    public init(text:String,highlightColor:RGBAColor = .init(red:1,green:0.85,blue:0.15),evaluationOffset:RationalTime = .zero,timeScale:RationalTime = .init(value:1,timescale:1)){
        sourceText=text;words=Self.tokens(in:text);self.highlightColor=highlightColor;self.evaluationOffset=evaluationOffset;self.timeScale=timeScale
    }
    public static func tokens(in text:String)->[TimedTitleWord]{ranges(in:text).map{.init(text:$0.text,utf16Location:$0.location,utf16Length:$0.length)}}
    private static func ranges(in text:String)->[(text:String,location:Int,length:Int)]{
        var result:[(text:String,location:Int,length:Int)]=[],start:String.Index?
        func append(_ end:String.Index){
            guard let beginning=start else{return}
            let range=NSRange(beginning..<end,in:text)
            result.append((String(text[beginning..<end]),range.location,range.length));start=nil
        }
        for index in text.indices{
            if text[index].isWhitespace{append(index)}else if start==nil{start=index}
        }
        append(text.endIndex);return result
    }
    public func isValid(for text:String)->Bool{
        guard sourceText==text,!words.isEmpty,words.count<=Self.maximumWords,
              highlightColor.isValid,timeScale.value>0,timeScale.timescale<=1_000_000_000,(0.0001...10000).contains(timeScale.seconds),
              evaluationOffset.timescale<=1_000_000_000,abs(evaluationOffset.seconds)<=86400,
              Set(words.map(\.id)).count==words.count else{return false}
        let expected=Self.ranges(in:text)
        guard expected.count==words.count else{return false}
        var previousEnd:RationalTime?
        func valid(_ value:RationalTime)->Bool{value >= .zero && value.timescale<=1_000_000_000 && value.seconds<=86400}
        for (word,token) in zip(words,expected){
            guard word.text==token.text,word.utf16Location==token.location,word.utf16Length==token.length else{return false}
            if let start=word.start,!valid(start){return false}
            if let end=word.end,!valid(end){return false}
            if let start=word.start,let end=word.end{
                guard start<end,previousEnd.map({$0<=start}) ?? true else{return false}
                previousEnd=end
            }
        }
        return true
    }
    public func elapsedTime(at localTime:RationalTime)throws->RationalTime{
        try localTime.checkedScaled(by:timeScale.value,over:timeScale.timescale).checkedAdding(evaluationOffset)
    }
    public func localTime(for originalTime:RationalTime)throws->RationalTime{
        try originalTime.checkedSubtracting(evaluationOffset).checkedScaled(by:timeScale.timescale,over:timeScale.value)
    }
    public func windowed(by delta:RationalTime)throws->Self{
        var result=self;result.evaluationOffset=try elapsedTime(at:delta);return result
    }
    public func retimed(by numerator:Int64,over denominator:Int64)throws->Self{
        var result=self;result.timeScale=try timeScale.checkedScaled(by:numerator,over:denominator);return result
    }
    public func activeWord(at localTime:RationalTime,text:String)->TimedTitleWord?{
        guard isValid(for:text),let elapsed=try? elapsedTime(at:localTime) else{return nil}
        return words.first{word in guard let start=word.start,let end=word.end else{return false};return start<=elapsed && elapsed<end}
    }
}

extension TitleContent {
    /// Text edits explicitly discard timing for the previous exact text ranges.
    public func replacingText(_ text:String)->Self{
        var result=self
        if result.text != text{result.text=text;result.wordTiming=nil}
        return result
    }
}
