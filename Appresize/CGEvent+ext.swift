import Foundation
import Cocoa


extension CGEvent {

    var mouseDelta: Delta {
        let dx = CGFloat(getDoubleValueField(.mouseEventDeltaX))
        let dy = CGFloat(getDoubleValueField(.mouseEventDeltaY))
        return Delta(dx: dx, dy: dy)
    }

}
