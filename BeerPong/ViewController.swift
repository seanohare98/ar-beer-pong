//
//  ViewController.swift
//  BeerPong
//
//  Created by Sean O'Hare on 10/28/20.
// References:
//              - https://www.appcoda.com/arkit-physics-scenekit/
//              - https://github.com/l-priebe/Paper-Toss-AR
//              - https://github.com/farice/ARShooter/
//              - https://blog.markdaws.net/arkit-by-example-part-2-plane-detection-visualization-10f05876d53

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate{
    
    @IBOutlet weak var scoreLabel: UILabel!             // outlet referencing UILabel to display score
    @IBOutlet var sceneView: ARSCNView!                 // outlet referencing ARSCNView
    
    var planes = [ARPlaneAnchor: Plane]()               // array of tuples: (ARPlaneAnchor, Plane Obj)
    var panSurfaceNode: SCNNode?                        // SCNNode w/ Plane geometry
    var ballNode: SCNNode?                              // SCNNode referencing the next ball to be thrown
    var score = 0                                       // score (represents attempts for now...)
    var isRunningCompletedConfiguration: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Set debugging tools
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Add tap gesture recognizer
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(gestureRecognizer)
        
        
        // Add pan gesture recognizer
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panned))
        sceneView.addGestureRecognizer(panGestureRecognizer)
        
        // Initialize hidden plane node for pan gesture detection
        let geometry = SCNPlane()
        let panSurfaceNode = SCNNode(geometry: geometry)
        panSurfaceNode.isHidden = true
        panSurfaceNode.position = SCNVector3(0, 0, -0.2)
        
        // Add as child node to follow camera's POV
        sceneView.pointOfView?.addChildNode(panSurfaceNode)
        self.panSurfaceNode = panSurfaceNode
        
        // Initialize ball node and attach as child node to follow camera's POV
        let buttonBallNode = createBallNode()
        buttonBallNode.position = SCNVector3Make(0, -0.1, -0.2)
        sceneView.pointOfView?.addChildNode(buttonBallNode)
        
        // Set self as contact delegate to handle collision detection
        //        sceneView.scene.physicsWorld.contactDelegate = self
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set horizontal plane detection configuration when view first appears
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Disallow sleeping and enable default lighting
        UIApplication.shared.isIdleTimerDisabled = true
        sceneView.autoenablesDefaultLighting = true
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        // Initialize scoreboard UILabel text
        scoreLabel.text = "Attempts: " + String(score)
        
    }
    
    func createBallNode() -> SCNNode{
        // Initialize geometry and custom texture for ping pong ball
        let ball = SCNSphere(radius: 0.03)
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: "ball_texture")
        ball.materials = [material]
        
        // Initialize node with name
        let ballNode = SCNNode(geometry: ball)
        ballNode.name = "ballNodeName"
        
        // Configure physicsBody for ball node
        let physicsShape = SCNPhysicsShape(geometry: ball, options: nil)
        let physicsBody = SCNPhysicsBody(type: .kinematic, shape: physicsShape)     // kinematic by default
        physicsBody.isAffectedByGravity = true
        physicsBody.categoryBitMask = CollisionCategory.ball.rawValue
        physicsBody.collisionBitMask = CollisionCategory.cup.rawValue
        ballNode.physicsBody = physicsBody
        
        return ballNode
    }
    
    @objc func tapped(gesture: UITapGestureRecognizer) {
        // Get 2D position of tap gesture
        let touchPosition = gesture.location(in: sceneView)
        
        // Run hitTest using touchPosition
        let hitTestResult = sceneView.hitTest(touchPosition, types: .existingPlaneUsingExtent)
        
        // Check if user is still in planeDetection/objectPlacement configuration
        if !hitTestResult.isEmpty && !isRunningCompletedConfiguration{
            guard let hitResult = hitTestResult.first else { return }   // First node registered from hitTest
            
            // Hide all unused planes
            for (anchor, plane) in planes {
                if(anchor == hitResult.anchor) { continue }
                plane.opacity = 0
            }
            
            // Anchor group of 6 cups to plane based on result of hitTest
            anchorCupsToPlane(hitTestResult: hitResult)
            
            // Have scene run next configuration
            runCompletedConfiguration()
        }
    }
    
    @objc func panned(_ sender: UIPanGestureRecognizer) {
        // Check if user has entered completed configuration
        if(!isRunningCompletedConfiguration){ return}
        
        // Handle .began
        if sender.state == .began {
            // Initialize new ball node to be thrown
            let ballNode = createBallNode()
            ballNode.physicsBody?.type = .dynamic
            sceneView.scene.rootNode.addChildNode(ballNode)
            self.ballNode = ballNode
        }
        
        // Handle .ended
        guard sender.state != .ended else {
            // Set ball node position to that of the camera
            let (direction, position) = self.getUserVector()
            ballNode?.position = position
            
            // Use velocity from UIPanGestureRecognizer to calculate normal
            // Stolen from https://github.com/l-priebe/Paper-Toss-AR
            let velocity = sender.velocity(in: sceneView)
            let norm = Float(sqrt(pow(velocity.x, 2) + pow(velocity.y, 2))) / 1000
            
            // Apply outward force onto physics body
            let outwardForce = SCNVector3(direction.x * norm, direction.y * norm, direction.z * norm)
            ballNode?.physicsBody?.applyForce(outwardForce, asImpulse: true)
            
            // Apply upward force onto physics body
            let upwardForce = SCNVector3(0, norm, 0)
            ballNode?.physicsBody?.applyForce(upwardForce, asImpulse: true)
            
            // Score is currently measuring attempts so add 1 to the count per throw
            score += 1
            scoreLabel.text = "Attempts: " + String(score)
            return
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Check if anchor passed to delegate is of type ARPlaneAnchor
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Initialize plane using ARPlaneAnchor
        let plane = Plane(planeAnchor)
        
        // Append plane to array of planes
        planes[planeAnchor] = plane
        
        // Add as child
        node.addChildNode(plane)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Check if anchor passed to delegate is of type ARPlaneAnchor
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Update plane from array using ARPlaneAnchor
        if let plane = planes[planeAnchor] { plane.update(planeAnchor)}
    }
    
    //MARK: - maths stolen from https://github.com/farice/ARShooter/blob/master/ARViewer/ViewController.swift#L191
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
    
    func anchorCupsToPlane(hitTestResult: ARHitTestResult) {
        // Initialize vertex positions for 6 respective cups
        let pointsX = [-0.125, 0, 0.125, -0.065, 0.065, 0]
        let pointsZ = [-0.2, -0.2, -0.2, -0.08, -0.08, 0.04]
        
        for i in 0..<pointsX.count {
            let offsetX = pointsX[i]
            let offsetZ = pointsZ[i]
            
            // Load in custom cup object (converted from .dae to .scn for scenekit)
            guard let cupScene = SCNScene(named: "art.scnassets/cup.scn")  else { return }
            guard let cupNode = cupScene.rootNode.childNode(withName: "CUP", recursively: false) else { return }
            
            // Load diffuse map onto cup
            let imageMaterial = SCNMaterial()
            imageMaterial.diffuse.contents = UIImage(named: "cup_diffuse")
            cupNode.geometry?.materials = [imageMaterial]
            
            // Scale down by 100
            cupNode.scale = SCNVector3(0.01, 0.01, 0.01)
            
            // Place cup around ARHitTestResult using x and z offsets
            cupNode.position = SCNVector3(hitTestResult.worldTransform.columns.3.x + Float(offsetX),hitTestResult.worldTransform.columns.3.y, hitTestResult.worldTransform.columns.3.z + Float(offsetZ))
            cupNode.name = "cupNodeName"
            
            // Concave shapes provide for realistic collision detection...it's also just a concave polyhedron by design haha
            let physicsShape = SCNPhysicsShape(node: cupNode, options: [SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.concavePolyhedron])
            let physicsBody = SCNPhysicsBody(type: .static, shape: physicsShape)
            physicsBody.categoryBitMask = CollisionCategory.cup.rawValue
            physicsBody.contactTestBitMask = CollisionCategory.ball.rawValue
            cupNode.physicsBody = physicsBody
            
            // Add as child node to root node of scene
            sceneView.scene.rootNode.addChildNode(cupNode)
        }
    }
    
    // MARK: - Contact Delegate
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        // Check category bit masks of nodeA and nodeB
        if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.cup.rawValue
            || contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.cup.rawValue {
            
            if (contact.nodeA.name == "cupNodeName" || contact.nodeB.name == "cupNodeName") {
                score += 1
            }
            
            // Remove invovled nodes from parent (dissapear)
            DispatchQueue.main.async {
                contact.nodeA.removeFromParentNode()
                contact.nodeB.removeFromParentNode()
                self.scoreLabel.text = "Score: " + String(self.score)
            }
        }
    }
    
    func runCompletedConfiguration() {
        // Declare user now in completedConfiguration
        isRunningCompletedConfiguration = true
        
        // Hide all debugOptions (feature points, physics shapes, etc.)
        sceneView.debugOptions = []
        
        // Create a world tracking session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session under new configuration
        sceneView.session.run(configuration)
    }
    
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
}
//
struct CollisionCategory: OptionSet {
    let rawValue: Int
    static let ball  = CollisionCategory(rawValue: 1 << 0)
    static let cup = CollisionCategory(rawValue: 1 << 1)
}
