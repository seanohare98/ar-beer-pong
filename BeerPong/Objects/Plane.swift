//
//  Plane.swift
//  BeerPong
//
//  Created by Sean O'Hare on 11/6/20.
// References:
//              - https://www.appcoda.com/arkit-physics-scenekit/
//              - https://github.com/l-priebe/Paper-Toss-AR
//              - https://github.com/farice/ARShooter/
//              - https://blog.markdaws.net/arkit-by-example-part-2-plane-detection-visualization-10f05876d53

import Foundation
import SceneKit
import ARKit

class Plane: SCNNode {
    
    var planeAnchor: ARPlaneAnchor
    var planeGeometry: SCNPlane
    var planeNode: SCNNode
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(_ anchor: ARPlaneAnchor) {
        // Assign all member attributes
        self.planeAnchor = anchor
        
        // Use extent.x and extent.z to define size of plane
        self.planeGeometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        
        // Do texture mapping onto plane
        let grid = UIImage(named: "plane_grid.png")
        let material = SCNMaterial()
        material.diffuse.contents = grid
        self.planeGeometry.materials = [material]
        self.planeGeometry.firstMaterial?.transparency = 0.8
        
        self.planeNode = SCNNode(geometry: planeGeometry)
        
        // Transform from vertical to horizontal plane
        self.planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
        self.planeNode.castsShadow = false
    
        // Give plane static physics body (act as a floor, allows for dynamic cups as well)
        let shape = SCNPhysicsShape(geometry: self.planeGeometry, options: nil)
        let physicsBody = SCNPhysicsBody(type: .static, shape: shape)
        self.planeNode.physicsBody = physicsBody
        
        super.init()
        
        self.addChildNode(planeNode)

        // Set position to be 2 mm below the origin of plane (best practice)
        self.position = SCNVector3(anchor.center.x, -0.002, anchor.center.z)
    }

    func update(_ anchor: ARPlaneAnchor) {
        // Update planeAnchor
        self.planeAnchor = anchor
        
        // Update new size of plane using extent.x and extent.z
        self.planeGeometry.width = CGFloat(anchor.extent.x)
        self.planeGeometry.height = CGFloat(anchor.extent.z)
        
        // Give plane static physics body
        let shape = SCNPhysicsShape(geometry: self.planeGeometry, options: nil)
        let physicsBody = SCNPhysicsBody(type: .static, shape: shape)
        self.planeNode.physicsBody = physicsBody
        
        self.position = SCNVector3Make(anchor.center.x, -0.002, anchor.center.z)
    }
}
