//
//  ViewController.swift
//  BeerPong
//
//  Created by Sean O'Hare on 10/28/20.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    
    var planes = [ARPlaneAnchor: Plane]()
    var visibleGrid: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Set debugging tools
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]

        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(gestureRecognizer)
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        UIApplication.shared.isIdleTimerDisabled = true
        sceneView.autoenablesDefaultLighting = true
        
        // Run the view's session
        sceneView.session.run(configuration)
        

    }
    
    @objc func tapped(gesture: UITapGestureRecognizer) {
        // Get exact position where touch happened on screen of iPhone (2D coordinate)
        let touchPosition = gesture.location(in: sceneView)
        
        let hitTestResult = sceneView.hitTest(touchPosition, types: .existingPlaneUsingExtent)

        if !hitTestResult.isEmpty {
            guard let hitResult = hitTestResult.first else {
                return
            }

            addCups(hitTestResult: hitResult)
        }
    }
    
    
    func addCups(hitTestResult: ARHitTestResult) {

        let cup = SCNCylinder(radius: 0.05, height: 0.2)
        let cupNode = SCNNode()
        let cupMaterial = SCNMaterial()
        cupMaterial.diffuse.contents = UIColor.red
        cupNode.geometry = cup
        cupNode.geometry?.materials = [cupMaterial]
        cupNode.position = SCNVector3(hitTestResult.worldTransform.columns.3.x,hitTestResult.worldTransform.columns.3.y, hitTestResult.worldTransform.columns.3.z)
    
          sceneView.scene.rootNode.addChildNode(cupNode)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
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

    func removePlane(anchor: ARPlaneAnchor) {
        if let plane = planes.removeValue(forKey: anchor) {
            plane.removeFromParentNode()
        }
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
