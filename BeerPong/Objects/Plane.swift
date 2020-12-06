//
//  Plane.swift
//  BeerPong
//
//  Created by Sean O'Hare on 11/6/20.
//

import Foundation
import SceneKit
import ARKit

class Plane: SCNNode {
    
    var planeAnchor: ARPlaneAnchor
    var planeGeometry: SCNPlane
    var planeNode: SCNNode

    
    init(_ anchor: ARPlaneAnchor) {
        self.planeAnchor = anchor
        
        self.planeGeometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        
        let grid = UIImage(named: "plane_grid.png")
        let material = SCNMaterial()
        material.diffuse.contents = grid
        self.planeGeometry.materials = [material]
        self.planeGeometry.firstMaterial?.transparency = 0.8
        self.planeNode = SCNNode(geometry: planeGeometry)
        self.planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
        self.planeNode.castsShadow = false
    
        let shape = SCNPhysicsShape(geometry: self.planeGeometry, options: nil)
        let physicsBody = SCNPhysicsBody(type: .static, shape: shape)
        self.planeNode.physicsBody = physicsBody
        
        super.init()
        
        self.addChildNode(planeNode)

        self.position = SCNVector3(anchor.center.x, -0.002, anchor.center.z) // 2 mm below the origin of plane.
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ anchor: ARPlaneAnchor) {
        self.planeAnchor = anchor
        
        self.planeGeometry.width = CGFloat(anchor.extent.x)
        self.planeGeometry.height = CGFloat(anchor.extent.z)
        
        let shape = SCNPhysicsShape(geometry: self.planeGeometry, options: nil)
        let physicsBody = SCNPhysicsBody(type: .static, shape: shape)
        
        self.planeNode.physicsBody = physicsBody
        
        self.position = SCNVector3Make(anchor.center.x, -0.002, anchor.center.z)
    }
    
}
