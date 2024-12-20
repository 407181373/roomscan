//
//  FloorPlanObject.swift
//  RoomPlan 2D
//
//  Created by Dennis van Oosten on 12/03/2023.
//

import SpriteKit
import RoomPlan

class FloorPlanObject: SKNode {
    
    private let capturedObject: CapturedRoom.Object
    internal var objectName : String = ""
    private var needToLabel : Bool = false
    
    // MARK: - Init
    
    init(capturedObject: CapturedRoom.Object) {
        self.capturedObject = capturedObject
        
        super.init()
        
        // Set the object's position using the transform matrix
        let objectPositionX = -CGFloat(capturedObject.transform.position.x) * scalingFactor
        let objectPositionY = CGFloat(capturedObject.transform.position.z) * scalingFactor
        self.position = CGPoint(x: objectPositionX, y: objectPositionY)
        
        // Set the object's zRotation using the transform matrix
        self.zRotation = -CGFloat(capturedObject.transform.eulerAngles.z - capturedObject.transform.eulerAngles.y)
        
        objectName = capturedObject.category.description;
        let maps = ["Sofa","Bed","Chair","Table","Storage"]
        needToLabel = maps.contains(objectName)
        
        drawObject()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Draw
    
    private func drawObject() {
        // Calculate the object's dimensions
        let objectWidth = CGFloat(capturedObject.dimensions.x) * scalingFactor
        let objectHeight = CGFloat(capturedObject.dimensions.z) * scalingFactor
        
        // Create the object's rectangle
        let objectRect = CGRect(
            x: -objectWidth / 2,
            y: -objectHeight / 2,
            width: objectWidth,
            height: objectHeight
        )
        
        
        
        // A shape to fill the object
        let objectShape = SKShapeNode(rect: objectRect)
        objectShape.strokeColor = .clear
        objectShape.fillColor = floorPlanSurfaceColor
        if(needToLabel) {
            objectShape.alpha = 0.5
        } else {
            objectShape.alpha = 0.1
        }
        objectShape.zPosition = objectZPosition
        
        // And another shape for the outline
        let objectOutlineShape = SKShapeNode(rect: objectRect)
        objectOutlineShape.strokeColor = floorPlanSurfaceColor
        objectOutlineShape.lineWidth = objectOutlineWidth
        objectOutlineShape.lineJoin = .miter
        objectOutlineShape.zPosition = objectOutlineZPosition
                
        // Add both shapes to the node
        addChild(objectShape)
        addChild(objectOutlineShape)
        if(needToLabel) {
            let map = ["Sofa":UIColor.green,"Bed":UIColor.purple,"Chair":UIColor.red,"Table":UIColor.white,"Storage":UIColor.gray]
            let color = (map[objectName] != nil) ? map[objectName] : UIColor.black
            addChild(drawTextNode(text: objectName, color: color!, yOffset: 0))
        }
    }
    
    private func drawTextNode(text : String , color : UIColor , yOffset : CGFloat)  -> SKLabelNode{
        let str = String(format: "\n%.2f", self.capturedObject.dimensions.x) + "X" +  String(format: "%.2f", self.capturedObject.dimensions.y) + "X" + String(format: "%.2f", self.capturedObject.dimensions.z)
        let labelNode = SKLabelNode(text:text + str)
        labelNode.fontSize = 16
        labelNode.numberOfLines = 2
        labelNode.fontName = "ArialMT"
        labelNode.fontColor = color
        labelNode.verticalAlignmentMode = .center
        labelNode.horizontalAlignmentMode = .center
        labelNode.zPosition = objectTextZPosition
//        labelNode.position = CGPoint(0,0);
//        labelNode.zRotation = zRotation
        
//        let t_pi = pi;
//        labelNode.zRotation = angle - .pi/2.0;
        
        
        return labelNode
    }
    
}
