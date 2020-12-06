//
//  ViewController.swift
//  BeerPong
//
//  Created by Sean O'Hare on 10/28/20.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate{
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBAction func onBallButton(_ sender: Any) {
        let (direction, position) = self.getUserVector()
        
        let ball = SCNSphere(radius: 0.03)
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: "ball_texture")
        ball.materials = [material]
        
        let ballNode = SCNNode(geometry: ball)
        ballNode.position = position
        
        let physicsShape = SCNPhysicsShape(geometry: ball ,options: nil)
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
        physicsBody.mass = 1
        
        let forceVector:Float = 4
        ballNode.physicsBody = physicsBody
        ballNode.physicsBody?.applyForce(SCNVector3(x: direction.x * forceVector,y: direction.y * forceVector,z: direction.z * forceVector), at: SCNVector3(0,0.2,0), asImpulse: true)

        
        sceneView.scene.rootNode.addChildNode(ballNode)
        
        // remove ball
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ballNode.removeFromParentNode()
         }
    }

    
    var planes = [ARPlaneAnchor: Plane]()
    var completed: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Set debugging tools
        sceneView.showsStatistics = true
//        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showPhysicsShapes]

        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(gestureRecognizer)
//        sceneView.scene.physicsWorld.contactDelegate = self
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        UIApplication.shared.isIdleTimerDisabled = true
        sceneView.autoenablesDefaultLighting = true
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        // Disallow sleeping while in ar
        UIApplication.shared.isIdleTimerDisabled = true
        
    }
    
    @objc func tapped(gesture: UITapGestureRecognizer) {
        // Get exact position where touch happened on screen of iPhone (2D coordinate)
        let touchPosition = gesture.location(in: sceneView)
        
        let hitTestResult = sceneView.hitTest(touchPosition, types: .existingPlaneUsingExtent)

        if !hitTestResult.isEmpty && !completed{
            guard let hitResult = hitTestResult.first else { return }
            addCups(hitTestResult: hitResult)
            enterCompletedPhase()
        
        }
    }
        
    func addCups(hitTestResult: ARHitTestResult) {
        let pointsX = [-0.125, 0, 0.125, -0.065, 0.065, 0]
        let pointsZ = [-0.2, -0.2, -0.2, -0.08, -0.08, 0.04]
        
        for i in 0..<pointsX.count {
            let offsetX = pointsX[i]
            let offsetZ = pointsZ[i]
            
            guard let cupScene = SCNScene(named: "art.scnassets/cup.scn")  else { return }
            guard let cupNode = cupScene.rootNode.childNode(withName: "CUP", recursively: false) else { return }
            
            let imageMaterial = SCNMaterial()
            imageMaterial.diffuse.contents = UIImage(named: "cup_diffuse")
            cupNode.geometry?.materials = [imageMaterial]

            cupNode.scale = SCNVector3(0.01, 0.01, 0.01)
            
            cupNode.position = SCNVector3(hitTestResult.worldTransform.columns.3.x + Float(offsetX),hitTestResult.worldTransform.columns.3.y, hitTestResult.worldTransform.columns.3.z + Float(offsetZ))
            cupNode.name = "cupNodeName" + String(i)
            
            let physicsShape = SCNPhysicsShape(node: cupNode, options: [SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.concavePolyhedron])
            let physicsBody = SCNPhysicsBody(type: .static, shape: physicsShape)
            
            cupNode.physicsBody = physicsBody
            
            sceneView.scene.rootNode.addChildNode(cupNode)
        }

        
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
           guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
            self.addPlane(node: node, anchor: planeAnchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        self.updatePlane(anchor: planeAnchor)

    }

    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        let plane = Plane(anchor)
        planes[anchor] = plane
        
        node.addChildNode(plane)
    }
    
    func updatePlane(anchor: ARPlaneAnchor) {
        if let plane = planes[anchor] {
            plane.update(anchor)
        }
    }
    
    //MARK: - maths
    func getUserVector() -> (SCNVector3, SCNVector3) { // (direction, position)
        if let frame = self.sceneView.session.currentFrame {
            // 4x4  transform matrix describing camera in world space
            let mat = SCNMatrix4(frame.camera.transform)
            // orientation of camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33)
            // location of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43)
            return (dir, pos)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
    
//    func addBallToSceneView(){
//
//       let ball = SCNSphere(radius: 0.02)
//       let material = SCNMaterial()
//       material.diffuse.contents = UIImage(named: "ball_texture")
//       ball.materials = [material]
//
//       let ballNode = SCNNode(geometry: ball)
//       ballNode.position = SCNVector3Make(0, -0.1, -0.2)
//       ballNode.name = ballNodeName
//
//       let physicsShape = SCNPhysicsShape(node: ballNode, options: nil)
//       let physicsBody = SCNPhysicsBody(type: .kinematic, shape: physicsShape)
//       physicsBody.isAffectedByGravity = false
//       ballNode.physicsBody = physicsBody
//
//       sceneView.pointOfView?.addChildNode(ballNode)
//
//      }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
    // MARK: - Contact Delegate
        
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {

         guard let aBody = contact.nodeA.physicsBody, let bBody = contact.nodeB.physicsBody else {
             return
         }
         
         let contactMask = aBody.categoryBitMask | bBody.categoryBitMask
         let goalMask = CategoryBitMask.ball | CategoryBitMask.target
         
         if contactMask == goalMask {
            
         }
     }
    
    private func enterCompletedPhase() {

        // Don't show feature points
//        sceneView.debugOptions = []
        completed = true
        sceneView.debugOptions = [ARSCNDebugOptions.showPhysicsShapes]
        
        // Create a world tracking session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
        
        // Hide detected planes
        for (_, plane) in planes {
            plane.opacity = 0
               }
     }
    
}

struct CategoryBitMask {
    static let all      =   0b11111111
    static let ball    =   0b00000100
    static let target   =   0b00001000
}
