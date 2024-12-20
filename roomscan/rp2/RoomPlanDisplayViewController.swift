//
//  Untitled.swift
//  rp2
//
//  Created by 江松陶 on 2024/10/28.
//

import UIKit
import SceneKit
import SceneKit.ModelIO
import SpriteKit
import ARKit
import RoomPlan

private enum SelectionState {
    case `none`
    case surface(SCNNode)
}

class RoomPlanDisplayViewController: UIViewController
{
    var info : Dictionary<String, Any>!
    var detailUrl : URL?
    var usdzUrl : URL?
    var skView : SKView?
    var roomData : CapturedRoom?
    var show2DRoomButton : UIButton?
    var show3DRoomButton : UIButton?
    var show3DLocalRoomButton : UIButton?
    var backButton : UIButton?
    private lazy var slidingGesture = setupSlidingGesture()
    private lazy var sceneView = setupSceneView()
    private lazy var activity = setupActivity()
    private var selectionState: SelectionState = .none
    private var currentAngleY: Float = 0.0
    private var currentScene : SCNScene?
    private var isLocalResource : Bool = false
    
    func setupSceneView() -> SCNView {
        let scnView = SCNView(frame: .zero)
//        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling2X
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = true
        scnView.showsStatistics = true
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = true
        return scnView
    }
    
    func setupSlidingGesture() -> UIPanGestureRecognizer {
        let slidingGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(sender:)))
        slidingGesture.minimumNumberOfTouches = 1
        slidingGesture.maximumNumberOfTouches = 2
        slidingGesture.isEnabled = false
        return slidingGesture
    }
    
    func setupActivity() -> UIActivityIndicatorView {
        let activity = UIActivityIndicatorView()
        activity.style = .medium
        activity.translatesAutoresizingMaskIntoConstraints = false
        return activity
    }
    
    func setupSceneIfNeeded() {
        if isSceneSetup { return }
        view.addSubview(sceneView)
        setupLayouts()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapInScene(sender:)))
        sceneView.addGestureRecognizer(tapGesture)
        sceneView.addGestureRecognizer(slidingGesture)
    }
    
    func startActivity() {
        guard !view.subviews.contains(where: { $0 == activity }) else { return }
        view.addSubview(activity)
        NSLayoutConstraint.activate([
            activity.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
        activity.startAnimating()
    }

    func stopActivity() {
        activity.stopAnimating()
        activity.removeFromSuperview()
    }

    private var isSceneSetup: Bool {
        view.subviews.contains(sceneView)
    }
    
    init?(info: Dictionary<String, Any>) {
        self.info = info
        self.detailUrl = self.info["detial"] as? URL
        self.usdzUrl = self.info["usd"] as? URL
        self.roomData = self.info["roomData"] as? CapturedRoom
        super.init(nibName: nil, bundle: nil)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        self.view.backgroundColor = .lightGray
        skView = SKView()
        self.view.addSubview(skView!)
        skView?.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)
        skView?.center = self.view.center
        skView?.isHidden = true
        if let room = roomData {
            skView?.presentScene(FloorPlanScene(capturedRoom: room))
        }
        if let url = usdzUrl {
            addModel(path: url)
        }
        setupSceneIfNeeded()
        sceneView.isHidden = true
        setupButton()
    }
    
    func setupButton() {
        show2DRoomButton = UIButton(type: .custom)
        show2DRoomButton?.setTitle("2D Show", for: .normal)
        show2DRoomButton?.setTitleColor(.blue, for: .normal)
        show2DRoomButton?.addTarget(self, action: #selector(roomClickWith2D), for: .touchUpInside)
        show2DRoomButton?.frame = CGRectMake(0, 0, 160, 60)
        show2DRoomButton?.center = CGPoint(x: self.view.center.x, y: self.view.center.y - 40)
        
        show3DRoomButton = UIButton(type: .custom)
        show3DRoomButton?.setTitle("3D Show", for: .normal)
        show3DRoomButton?.setTitleColor(.blue, for: .normal)
        show3DRoomButton?.addTarget(self, action: #selector(roomClickWith3D), for: .touchUpInside)
        show3DRoomButton?.frame = CGRectMake(0, 0, 160, 60)
        show3DRoomButton?.center = CGPoint(x: self.view.center.x, y: self.view.center.y + 40)
        
        show3DLocalRoomButton = UIButton(type: .custom)
        show3DLocalRoomButton?.setTitle("3D local Show", for: .normal)
        show3DLocalRoomButton?.setTitleColor(.blue, for: .normal)
        show3DLocalRoomButton?.addTarget(self, action: #selector(roomClickWith3DLocal), for: .touchUpInside)
        show3DLocalRoomButton?.frame = CGRectMake(0, 0, 160, 60)
        show3DLocalRoomButton?.center = CGPoint(x: self.view.center.x, y: self.view.center.y + 120)
        
        backButton = UIButton(type: .custom)
        backButton?.setTitle("back", for: .normal)
        backButton?.setTitleColor(.blue, for: .normal)
        backButton?.frame = CGRectMake(30, 60, 80, 40)
        backButton?.addTarget(self, action: #selector(back), for: .touchUpInside)
        self.view.addSubview(show2DRoomButton!)
        self.view.addSubview(show3DRoomButton!)
        self.view.addSubview(show3DLocalRoomButton!)
        self.view.addSubview(backButton!)
        
    }
    
    func addModel(path: URL) {
        startActivity()
        Task {
            
            let asset = MDLAsset(url: path)
            let scene = SCNScene(mdlAsset: asset)
            currentScene = scene
            await MainActor.run { [weak self] in
                guard let self = self else { return }

                scene.rootNode.markAsSpaceNode()
                self.decorateScene(scene)

                switch self.sceneView.scene {
                    case let .some(existingScene):
                        existingScene.rootNode.addChildNode(scene.rootNode)
                    case .none:
                        // Create an empty scene and append our model to it as a child node.

                        // Also prepare a camera node (which will be controlled by SCNCameraController / SCNView's defaultCameraController),
                        // if we do not set this up and let SceneKit add a default camera node, we can't move the camera via defaultCameraController

                        let rootScene = SCNScene()
                        let cameraNode = SCNNode()
                        cameraNode.camera = SCNCamera()
                        cameraNode.position = SCNVector3(x: 0, y: 0, z: 10)
                        rootScene.rootNode.addChildNode(cameraNode)
                        rootScene.rootNode.addChildNode(scene.rootNode)
                        self.sceneView.scene = rootScene
                        self.animateSceneLoad()
                }
                self.stopActivity()
            }
        }
    }
    
    func updateScene(path: URL , local : Bool) {
        if (self.isLocalResource != local) {
            startActivity()
            currentScene?.rootNode.removeFromParentNode()
            let asset = MDLAsset(url: path)
            let scene = SCNScene(mdlAsset: asset)
            scene.rootNode.markAsSpaceNode()
            self.decorateScene(scene)
            currentScene = scene
            self.sceneView.scene?.rootNode.addChildNode(scene.rootNode)
            self.stopActivity()
            self.isLocalResource = local
        }
    }
    
    func decorateScene(_ scene: SCNScene) {
        let rootNode = scene.rootNode
        rootNode.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            switch node.type {
                case .door:
                geometry.firstMaterial?.diffuse.contents = UIColor.orange.withAlphaComponent(0.3)
                case .floor:
                    print("Position before rotation:", node.position, "pivot: ", node.pivot)
                geometry.firstMaterial?.diffuse.contents = UIColor.gray.withAlphaComponent(1.0)
                case .furniture:
                    geometry.firstMaterial?.diffuse.contents = UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 0.8)
                case .wall:
                geometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(1.0)
                case .window:
                    geometry.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.3)
                case .bed:
                    geometry.firstMaterial?.diffuse.contents = UIColor.yellow.withAlphaComponent(0.6)
                case .table:
                    geometry.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.6)
                case .chair:
                    geometry.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.6)
                case .sofa:
                    geometry.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.6)
                case .opening:
                    break
                case .none:
                    break
            }
        }
    }
    
    func animateSceneLoad() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1
        let cameraController = sceneView.defaultCameraController
        let rotation = (Float.pi / 4) * 50
        cameraController.rotateBy(x: rotation, y: -rotation)
        SCNTransaction.commit()
    }
    
    func setupLayouts() {
        sceneView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    func showToast(message: String, duration: TimeInterval = 2.0) {
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.font = .systemFont(ofSize: 14.0)
        toastLabel.textColor = .white
        toastLabel.numberOfLines = 0
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textAlignment = .center
        toastLabel.layer.cornerRadius = 5.0
        toastLabel.clipsToBounds = true
     
        let toastContentView = UIView()
        toastContentView.backgroundColor = .systemBackground
        toastContentView.addSubview(toastLabel)
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastLabel.centerXAnchor.constraint(equalTo: toastContentView.centerXAnchor).isActive = true
        toastLabel.centerYAnchor.constraint(equalTo: toastContentView.centerYAnchor).isActive = true
     
        if let window = UIApplication.shared.windows.first {
            toastContentView.frame = window.bounds
     
            window.addSubview(toastContentView)
            toastContentView.alpha = 0.0
     
            UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseIn, animations: {
                toastContentView.alpha = 1.0
            }, completion: { _ in
                UIView.animate(withDuration: 0.5, delay: duration, options: .curveEaseOut, animations: {
                    toastContentView.alpha = 0.0
                }, completion: { _ in
                    toastContentView.removeFromSuperview()
                })
            })
        }
    }

    
    @objc func roomClickWith2D() {
        skView?.isHidden = false
        sceneView.isHidden = true
        show2DRoomButton?.isHidden = true
        show3DRoomButton?.isHidden = true
        show3DLocalRoomButton?.isHidden = true
        backButton?.isHidden = false
    }
    
    @objc func roomClickWith3D() {
        skView?.isHidden = true
        sceneView.isHidden = false
        show2DRoomButton?.isHidden = true
        show3DRoomButton?.isHidden = true
        show3DLocalRoomButton?.isHidden = true
        backButton?.isHidden = false
        if let url = usdzUrl {
            updateScene(path: url, local: false)
        }
    }
    
    @objc func roomClickWith3DLocal() {
        skView?.isHidden = true
        sceneView.isHidden = false
        show2DRoomButton?.isHidden = true
        show3DRoomButton?.isHidden = true
        show3DLocalRoomButton?.isHidden = true
        backButton?.isHidden = false
        if let url = Bundle.main.url(forResource: "Room", withExtension: "usdz") {
            updateScene(path: url, local: true)
        }
    }
    
    @objc func back() {
        skView?.isHidden = true
        sceneView.isHidden = true
        show2DRoomButton?.isHidden = false
        show3DRoomButton?.isHidden = false
        show3DLocalRoomButton?.isHidden = false
        backButton?.isHidden = true
    }
    
    @objc func handlePanGesture(sender: UIPanGestureRecognizer) {
        guard case let SelectionState.surface(selectedNode) = selectionState else { return }

        let translation = sender.translation(in: sender.view)
        var newAngleY = (Float)(translation.x)*(Float)(Double.pi)/180.0
        newAngleY += currentAngleY

        selectedNode.eulerAngles.y = newAngleY

        if sender.state == .ended {
            currentAngleY = newAngleY
        }
    }

    @objc func handleTapInScene(sender: UITapGestureRecognizer) {
        let location = sender.location(in: sceneView)
        let node = sceneView.hitTest(
            location,
            options: [.boundingBoxOnly: false, .searchMode: SCNHitTestSearchMode.all.rawValue]
        ).map(\.node)
            .first(where: { $0.type != nil })

        guard let selectedNode = node else {
            return
        }

        let previousSelectionState = selectionState
        let isFloorSelected = selectedNode.type == .floor
        switch previousSelectionState {
            case .none:
                selectionState = .surface(selectedNode)
                slidingGesture.isEnabled = isFloorSelected
                sceneView.allowsCameraControl = !isFloorSelected
                selectedNode.geometry?.firstMaterial?.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.6)
            let toast : String = "宽:" + String(selectedNode.boundingBox.max.x - selectedNode.boundingBox.min.x) + "高:" + String(selectedNode.boundingBox.max.y - selectedNode.boundingBox.min.y) + "长:" + String(selectedNode.boundingBox.max.z - selectedNode.boundingBox.min.z)
            showAlert(title: selectedNode.name, message: toast) { UIAlertAction in
                self.selectionState = .none
                let node = selectedNode
                let geometry = node.geometry
                   switch node.type {
                    case .door:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.orange.withAlphaComponent(0.3)
                    case .floor:
                        print("Position before rotation:", node.position, "pivot: ", node.pivot)
                       geometry!.firstMaterial?.diffuse.contents = UIColor.lightGray.withAlphaComponent(1.0)
                    case .furniture:
                       geometry?.firstMaterial?.diffuse.contents = UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 0.8)
                    case .wall:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(1.0)
                    case .window:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.3)
                    case .bed:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.yellow.withAlphaComponent(0.6)
                    case .table:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.6)
                    case .chair:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.6)
                    case .sofa:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.6)
                        case .opening:
                            break
                        case .none:
                            break
                }
                self.slidingGesture.isEnabled = false
                self.sceneView.allowsCameraControl = true
            }
            case .surface(let node):
                selectionState = .none
                let node = selectedNode
                let geometry = node.geometry
                   switch node.type {
                    case .door:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.orange.withAlphaComponent(0.3)
                    case .floor:
                        print("Position before rotation:", node.position, "pivot: ", node.pivot)
                       geometry!.firstMaterial?.diffuse.contents = UIColor.lightGray.withAlphaComponent(1.0)
                    case .furniture:
                       geometry?.firstMaterial?.diffuse.contents = UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 0.8)
                    case .wall:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(1.0)
                    case .window:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.3)
                    case .bed:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.yellow.withAlphaComponent(0.6)
                    case .table:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.6)
                    case .chair:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.6)
                    case .sofa:
                       geometry?.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.6)
                        case .opening:
                            break
                        case .none:
                            break
                }
                slidingGesture.isEnabled = false
                sceneView.allowsCameraControl = true
        }
    }

}

