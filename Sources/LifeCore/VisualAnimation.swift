import Foundation

/// Position and scale in the same normalized canvas coordinates as VisualTransform.
/// Each key's interpolation describes the segment leaving that key.
public struct VisualKeyframe:Identifiable,Codable,Equatable,Sendable {
    public var id:UUID
    public var time:RationalTime
    public var x:Double
    public var y:Double
    public var scaleX:Double
    public var scaleY:Double
    public var rotationDegrees:Double?
    public var cropLeft:Double?;public var cropRight:Double?;public var cropTop:Double?;public var cropBottom:Double?
    public var interpolation:Interpolation
    public init(id:UUID=UUID(),time:RationalTime,visual:VisualTransform,interpolation:Interpolation = .linear){
        self.id=id;self.time=time;self.x=visual.x;self.y=visual.y;self.scaleX=visual.scaleX;self.scaleY=visual.scaleY;self.interpolation=interpolation
        rotationDegrees=visual.rotationDegrees;cropLeft=visual.cropLeft;cropRight=visual.cropRight;cropTop=visual.cropTop;cropBottom=visual.cropBottom
    }
    var isValid:Bool {
        let framing=[rotationDegrees,cropLeft,cropRight,cropTop,cropBottom]
        let legacy=framing.allSatisfy{$0==nil}
        let v=VisualTransform(rotationDegrees:rotationDegrees ?? 0,cropLeft:cropLeft ?? 0,cropRight:cropRight ?? 0,cropTop:cropTop ?? 0,cropBottom:cropBottom ?? 0)
        return (legacy || (framing.allSatisfy{$0 != nil} && v.isValid)) && time >= .zero && time.timescale<=1_000_000_000 && time.seconds<=86400 &&
        [x,y,scaleX,scaleY].allSatisfy(\.isFinite) && (-10...10).contains(x) && (-10...10).contains(y) &&
        (0.001...100).contains(scaleX) && (0.001...100).contains(scaleY)
    }
}

/// The original animation clock survives trims, splits and speed changes without
/// baking new endpoints into eased segments. Rotation and crop interpolate; flips stay static.
public struct VisualAnimation:Codable,Equatable,Sendable {
    public static let maximumKeys=1000
    public var keyframes:[VisualKeyframe]
    public var evaluationOffset:RationalTime
    public var timeScale:RationalTime
    public init(keyframes:[VisualKeyframe],evaluationOffset:RationalTime = .zero,timeScale:RationalTime = .init(value:1,timescale:1)){
        self.keyframes=keyframes;self.evaluationOffset=evaluationOffset;self.timeScale=timeScale
    }
    public var isValid:Bool {
        !keyframes.isEmpty && keyframes.count<=Self.maximumKeys && keyframes.allSatisfy(\.isValid) &&
        Set(keyframes.map(\.id)).count==keyframes.count && zip(keyframes,keyframes.dropFirst()).allSatisfy{$0.time<$1.time} &&
        timeScale.value>0 && timeScale.timescale<=1_000_000_000 && (0.0001...10000).contains(timeScale.seconds) &&
        evaluationOffset.timescale<=1_000_000_000 && evaluationOffset.seconds.isFinite && abs(evaluationOffset.seconds)<=86400
    }
    public func elapsedTime(at localTime:RationalTime)throws->RationalTime {
        try localTime.checkedScaled(by:timeScale.value,over:timeScale.timescale).checkedAdding(evaluationOffset)
    }
    public func localTime(for key:VisualKeyframe)throws->RationalTime {
        try key.time.checkedSubtracting(evaluationOffset).checkedScaled(by:timeScale.timescale,over:timeScale.value)
    }
    public func windowed(by delta:RationalTime)throws->Self {
        var result=self;result.evaluationOffset=try elapsedTime(at:delta);return result
    }
    public func retimed(by numerator:Int64,over denominator:Int64)throws->Self {
        var result=self;result.timeScale=try timeScale.checkedScaled(by:numerator,over:denominator);return result
    }
    public func transform(at localTime:RationalTime,base:VisualTransform)->VisualTransform {
        guard let first=keyframes.first,let last=keyframes.last else{return base}
        // Rendering uses a bounded scalar clock so valid rational inputs whose
        // intermediate denominator exceeds Int64 still render continuously.
        let clock=localTime.seconds*timeScale.seconds+evaluationOffset.seconds
        var left=first,right=first,fraction=0.0
        if clock>=last.time.seconds{left=last;right=last}
        else if clock>first.time.seconds {
            for pair in zip(keyframes,keyframes.dropFirst()) where clock<pair.1.time.seconds {
                left=pair.0;right=pair.1
                fraction=(clock-left.time.seconds)/(right.time.seconds-left.time.seconds)
                if left.interpolation == .hold{fraction=0}
                else if left.interpolation == .eased{fraction=fraction*fraction*(3-2*fraction)}
                break
            }
        }
        var result=base
        result.x=left.x+(right.x-left.x)*fraction;result.y=left.y+(right.y-left.y)*fraction
        result.scaleX=left.scaleX+(right.scaleX-left.scaleX)*fraction;result.scaleY=left.scaleY+(right.scaleY-left.scaleY)*fraction
        func mix(_ a:Double?,_ b:Double?,_ fallback:Double)->Double {
            let start=a ?? fallback;return start+((b ?? fallback)-start)*fraction
        }
        result.rotationDegrees=mix(left.rotationDegrees,right.rotationDegrees,base.rotationDegrees)
        result.cropLeft=mix(left.cropLeft,right.cropLeft,base.cropLeft)
        result.cropRight=mix(left.cropRight,right.cropRight,base.cropRight)
        result.cropTop=mix(left.cropTop,right.cropTop,base.cropTop)
        result.cropBottom=mix(left.cropBottom,right.cropBottom,base.cropBottom)
        return result
    }
    public mutating func setKey(at localTime:RationalTime,visual:VisualTransform)throws {
        var clock=try elapsedTime(at:localTime)
        if clock < .zero {
            // Extending a trimmed source to the left can expose time before the
            // original first key. Rebase the complete curve and its clock by the
            // same amount, preserving every existing segment and stable key ID.
            let shift=try RationalTime.zero.checkedSubtracting(clock)
            let shifted=try keyframes.map{key in
                var key=key;key.time=try key.time.checkedAdding(shift)
                guard key.time.seconds<=86400 else{throw DocumentError.invalidTiming}
                return key
            }
            let offset=try evaluationOffset.checkedAdding(shift)
            guard abs(offset.seconds)<=86400 else{throw DocumentError.invalidTiming}
            keyframes=shifted;evaluationOffset=offset;clock = .zero
        }
        guard clock.seconds<=86400 else{throw DocumentError.invalidTiming}
        if let index=keyframes.firstIndex(where:{$0.time==clock}){
            let old=keyframes[index]
            keyframes[index]=VisualKeyframe(id:old.id,time:clock,visual:visual,interpolation:old.interpolation)
        }else{
            guard keyframes.count<Self.maximumKeys else{throw DocumentError.invalidTiming}
            keyframes.append(.init(time:clock,visual:visual));keyframes.sort{$0.time<$1.time}
        }
    }
}

extension Clip {
    public func visualTransform(at localTime:RationalTime)->VisualTransform {
        let base=visual ?? .init()
        return visualAnimation?.transform(at:localTime,base:base) ?? base
    }
}
