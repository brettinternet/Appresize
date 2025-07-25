import Foundation


extension CGPoint {

    public func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow(point.x - self.x, 2) + pow(point.y - self.y, 2))
    }

    public var magnitude: CGFloat {
        return distance(to: CGPoint())
    }

}


func -(a: CGPoint, b: CGPoint) -> CGPoint {
    return CGPoint(x: a.x - b.x, y: a.y - b.y)
}
