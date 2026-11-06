import Foundation

public enum AnimatedProperty:String,Codable,CaseIterable,Sendable {
    case titleSize,textRed,textGreen,textBlue,textAlpha,backgroundAlpha
    case drawingWidth,drawingRed,drawingGreen,drawingBlue,drawingAlpha
    case effectStrength,effectParameter
}

/// Numeric property curves use the same original-content clock as motion keys.
public struct PropertyAnimation:Identifiable,Codable,Equatable,Sendable {
    public var id:UUID
    public var property:AnimatedProperty
    public var effectID:UUID?
    public var parameter:String?
    public var points:[AutomationPoint]
    public var evaluationOffset:RationalTime
    public var timeScale:RationalTime
    public init(id:UUID=UUID(),property:AnimatedProperty,effectID:UUID?=nil,parameter:String?=nil,points:[AutomationPoint]=[],evaluationOffset:RationalTime = .zero,timeScale:RationalTime = .init(value:1,timescale:1)){
        self.id=id;self.property=property;self.effectID=effectID;self.parameter=parameter;self.points=points;self.evaluationOffset=evaluationOffset;self.timeScale=timeScale
    }
    public var identity:String{property.rawValue+"|"+(effectID?.uuidString ?? "")+"|"+(parameter ?? "")}
    public func baseValue(in clip:Clip)->Double? {
        let style=clip.title?.style ?? TitleStyle()
        switch property {
        case .titleSize:return clip.title?.fontSize
        case .textRed:return clip.title == nil ? nil:style.color.red
        case .textGreen:return clip.title == nil ? nil:style.color.green
        case .textBlue:return clip.title == nil ? nil:style.color.blue
        case .textAlpha:return clip.title == nil ? nil:style.color.alpha
        case .backgroundAlpha:return clip.title == nil ? nil:style.background.alpha
        case .drawingWidth,.drawingRed,.drawingGreen,.drawingBlue,.drawingAlpha:
            guard case .drawing(let drawing)=clip.graphic,let stroke=drawing.strokes.first else{return nil}
            switch property{case .drawingWidth:return stroke.width;case .drawingRed:return stroke.color.red;case .drawingGreen:return stroke.color.green;case .drawingBlue:return stroke.color.blue;default:return stroke.color.alpha}
        case .effectStrength:return clip.effects?.first{$0.id==effectID}?.strength
        case .effectParameter:
            guard let effect=clip.effects?.first(where:{$0.id==effectID}),let parameter else{return nil}
            return effect.parameters[parameter] ?? NativeEffectRegistry.definition(for:effect.stableID)?.parameters.first{$0.name==parameter}?.defaultValue
        }
    }
    public func range(in clip:Clip)->ClosedRange<Double>? {
        switch property {
        case .titleSize:return clip.title == nil ? nil:1...4096
        case .textRed,.textGreen,.textBlue,.textAlpha,.backgroundAlpha:return clip.title == nil ? nil:0...1
        case .drawingWidth:if case .drawing=clip.graphic{return 0.0001...0.25};return nil
        case .drawingRed,.drawingGreen,.drawingBlue,.drawingAlpha:if case .drawing=clip.graphic{return 0...1};return nil
        case .effectStrength:return clip.effects?.contains(where:{$0.id==effectID}) == true ? 0...1:nil
        case .effectParameter:
            guard let effect=clip.effects?.first(where:{$0.id==effectID}),let parameter else{return nil}
            return NativeEffectRegistry.definition(for:effect.stableID)?.parameters.first(where:{$0.name==parameter})?.range
        }
    }
    public func isValid(in clip:Clip)->Bool {
        guard let range=range(in:clip),!points.isEmpty,points.count<=1000,
              Set(points.map(\.id)).count==points.count,zip(points,points.dropFirst()).allSatisfy({$0.time<$1.time}),
              timeScale.value>0,timeScale.timescale<=1_000_000_000,(0.0001...10000).contains(timeScale.seconds),
              evaluationOffset.timescale<=1_000_000_000,abs(evaluationOffset.seconds)<=86400 else{return false}
        return points.allSatisfy{$0.value.isFinite && range.contains($0.value) && $0.time >= .zero && $0.time.timescale<=1_000_000_000 && $0.time.seconds<=86400}
    }
    public func elapsedTime(at local:RationalTime)throws->RationalTime{try local.checkedScaled(by:timeScale.value,over:timeScale.timescale).checkedAdding(evaluationOffset)}
    public func localTime(for point:AutomationPoint)throws->RationalTime{try point.time.checkedSubtracting(evaluationOffset).checkedScaled(by:timeScale.timescale,over:timeScale.value)}
    public func windowed(by delta:RationalTime)throws->Self{var result=self;result.evaluationOffset=try elapsedTime(at:delta);return result}
    public func retimed(by numerator:Int64,over denominator:Int64)throws->Self{var result=self;result.timeScale=try timeScale.checkedScaled(by:numerator,over:denominator);return result}
    public func value(at local:RationalTime)->Double {
        guard let first=points.first,let last=points.last else{return 0}
        let clock=local.seconds*timeScale.seconds+evaluationOffset.seconds
        if clock<=first.time.seconds{return first.value};if clock>=last.time.seconds{return last.value}
        for (a,b) in zip(points,points.dropFirst()) where clock<b.time.seconds {
            var f=(clock-a.time.seconds)/(b.time.seconds-a.time.seconds)
            if a.interpolation == .hold{f=0}else if a.interpolation == .eased{f=f*f*(3-2*f)}
            return a.value+(b.value-a.value)*f
        }
        return last.value
    }
    public mutating func setKey(at local:RationalTime,value:Double)throws {
        var clock=try elapsedTime(at:local)
        if clock < .zero {
            let shift=try RationalTime.zero.checkedSubtracting(clock)
            for index in points.indices{points[index].time=try points[index].time.checkedAdding(shift)}
            evaluationOffset=try evaluationOffset.checkedAdding(shift);clock = .zero
        }
        guard clock.seconds<=86400 else{throw DocumentError.invalidTiming}
        if let index=points.firstIndex(where:{$0.time==clock}){points[index].value=value}
        else{guard points.count<1000 else{throw DocumentError.invalidTiming};points.append(.init(time:clock,value:value));points.sort{$0.time<$1.time}}
    }
}

extension Clip {
    public func evaluatedProperties(at local:RationalTime)->Clip {
        var result=self
        for animation in propertyAnimations ?? [] {
            let value=animation.value(at:local)
            switch animation.property {
            case .titleSize:result.title?.fontSize=value
            case .textRed,.textGreen,.textBlue,.textAlpha,.backgroundAlpha:
                guard result.title != nil else{continue}
                var style=result.title?.style ?? .init()
                switch animation.property {
                case .textRed:style.color.red=value
                case .textGreen:style.color.green=value
                case .textBlue:style.color.blue=value
                case .textAlpha:style.color.alpha=value
                default:style.background.alpha=value
                }
                result.title?.style=style
            case .drawingWidth,.drawingRed,.drawingGreen,.drawingBlue,.drawingAlpha:
                guard case .drawing(var drawing)=result.graphic else{continue}
                for index in drawing.strokes.indices {
                    switch animation.property {
                    case .drawingWidth:drawing.strokes[index].width=value
                    case .drawingRed:drawing.strokes[index].color.red=value
                    case .drawingGreen:drawing.strokes[index].color.green=value
                    case .drawingBlue:drawing.strokes[index].color.blue=value
                    default:drawing.strokes[index].color.alpha=value
                    }
                }
                result.graphic = .drawing(drawing)
            case .effectStrength,.effectParameter:
                guard let index=result.effects?.firstIndex(where:{$0.id==animation.effectID}) else{continue}
                if animation.property == .effectStrength{result.effects?[index].strength=value}
                else if let parameter=animation.parameter{result.effects?[index].parameters[parameter]=value}
            }
        }
        return result
    }
}
