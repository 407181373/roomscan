//
//  FloorPlanSurface.swift
//  RoomPlan 2D
//
//  Created by Dennis van Oosten on 12/03/2023.
//

import SpriteKit
import RoomPlan

class FloorPlanSurface: SKNode {
    
    private let capturedSurface: CapturedRoom.Surface
    
    // MARK: - Computed properties
    
    private var halfLength: CGFloat {
        return CGFloat(capturedSurface.dimensions.x) * scalingFactor / 2
    }
    
    private var pointA: CGPoint {
        return CGPoint(x: -halfLength, y: 0)
    }
    
    private var pointB: CGPoint {
        return CGPoint(x: halfLength, y: 0)
    }
    
    private var pointC: CGPoint {
        return pointB.rotateAround(point: pointA, by: 0.25 * .pi)
    }
    
    // MARK: - Init
    
    init(capturedSurface: CapturedRoom.Surface) {
        self.capturedSurface = capturedSurface
        
        super.init()
        
        // Set the surface's position using the transform matrix
        let surfacePositionX = -CGFloat(capturedSurface.transform.position.x) * scalingFactor
        let surfacePositionY = CGFloat(capturedSurface.transform.position.z) * scalingFactor
        self.position = CGPoint(x: surfacePositionX, y: surfacePositionY)
        
        // Set the surface's zRotation using the transform matrix
        self.zRotation = -CGFloat(capturedSurface.transform.eulerAngles.z - capturedSurface.transform.eulerAngles.y)
        
        // Draw the right surface
        switch capturedSurface.category {
        case .door:
            drawDoor()
        case .opening:
            drawOpening()
        case .wall:
            drawWall()
        case .window:
            drawWindow()
        case .floor:
            print("no need to draw")
        @unknown default:
            drawWall()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Draw

    private func drawDoor() {
        let hideWallPath = createPath(from: pointA, to: pointB)
        let doorPath = createPath(from: pointA, to: pointC)

        // Hide the wall underneath the door
        let hideWallShape = createShapeNode(from: hideWallPath)
        hideWallShape.strokeColor = floorPlanBackgroundColor
        hideWallShape.lineWidth = hideSurfaceWith
        hideWallShape.zPosition = hideSurfaceZPosition
        
        // The door itself
        let doorShape = createShapeNode(from: doorPath)
        doorShape.lineCap = .square
        doorShape.zPosition = doorZPosition
        
        // The door's arc
        let doorArcPath = CGMutablePath()
        doorArcPath.addArc(
            center: pointA,
            radius: halfLength * 2,
            startAngle: 0.25 * .pi,
            endAngle: 0,
            clockwise: true
        )
        
        // Create a dashed path
        let dashPattern: [CGFloat] = [24.0, 8.0]
        let dashedArcPath = doorArcPath.copy(dashingWithPhase: 1, lengths: dashPattern)

        let doorArcShape = createShapeNode(from: dashedArcPath)
        doorArcShape.lineWidth = doorArcWidth
        doorArcShape.zPosition = doorArcZPosition
        
        addChild(hideWallShape)
        addChild(doorShape)
        addChild(doorArcShape)
        addChild(drawTextNode(text: "门:", color: .red ,yOffset: 15))
    }
    
    private func drawOpening() {
        let openingPath = createPath(from: pointA, to: pointB)
        
        // Hide the wall underneath the opening
        let hideWallShape = createShapeNode(from: openingPath)
        hideWallShape.strokeColor = floorPlanBackgroundColor
        hideWallShape.lineWidth = hideSurfaceWith
        hideWallShape.zPosition = hideSurfaceZPosition
        
        addChild(hideWallShape)
        addChild(drawTextNode(text: "阳台:", color: .purple , yOffset:5))
    }
    
    private func drawWall() {
        let wallPath = createPath(from: pointA, to: pointB)
        let wallShape = createShapeNode(from: wallPath)
        wallShape.lineCap = .square

        addChild(wallShape)
        addChild(drawTextNode(text: "墙:", color: .black , yOffset: 30))
    }
    
    private func drawWindow() {
        let windowPath = createPath(from: pointA, to: pointB)
        
        // Hide the wall underneath the window
        let hideWallShape = createShapeNode(from: windowPath)
        hideWallShape.strokeColor = floorPlanBackgroundColor
        hideWallShape.lineWidth = hideSurfaceWith
        hideWallShape.zPosition = hideSurfaceZPosition
        
        // The window itself
        let windowShape = createShapeNode(from: windowPath)
        windowShape.lineWidth = windowWidth
        windowShape.zPosition = windowZPosition
        
        addChild(hideWallShape)
        addChild(windowShape)
        addChild(drawTextNode(text: "窗:", color: .blue , yOffset: 5))
    }
    
    private func drawTextNode(text : String , color : UIColor , yOffset : CGFloat)  -> SKLabelNode{
        let str = String(format: "%.2f", self.capturedSurface.dimensions.x) + "X" +  String(format: "%.2f", self.capturedSurface.dimensions.y) + "X" + String(format: "%.2f", self.capturedSurface.dimensions.z)
        let labelNode = SKLabelNode(text:text + str)
        labelNode.fontSize = 20
        labelNode.fontName = "ArialMT"
        labelNode.fontColor = color
        labelNode.zPosition = objectTextZPosition
        labelNode.position = CGPointMake((pointB.x + pointA.x)/2.0, (pointB.y + pointA.y)/2.0 + yOffset)
        let angle = atan2(pointB.x - pointA.x, pointA.y - pointA.y)
        
//        let t_pi = pi;
        labelNode.zRotation = angle - .pi/2.0;
        
        
        return labelNode
    }
    
    // MARK: - Helper functions
    
    private func createPath(from pointA: CGPoint, to pointB: CGPoint) -> CGMutablePath {
        let path = CGMutablePath()
        path.move(to: pointA)
        path.addLine(to: pointB)
        
        return path
    }
    
    private func createShapeNode(from path: CGPath) -> SKShapeNode {
        let shapeNode = SKShapeNode(path: path)
        shapeNode.strokeColor = floorPlanSurfaceColor
        shapeNode.lineWidth = surfaceWith
        
        return shapeNode
    }
    
}
