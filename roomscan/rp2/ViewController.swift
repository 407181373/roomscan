//
//  ViewController.swift
//  rp2
//
//  Created by Mark Kim on 6/16/22.
//

import ARKit
import RoomPlan
import SceneKit
import UIKit
import SpriteKit

typealias USDZCompletionHandler = () -> Void

class ViewController: UIViewController, ARSCNViewDelegate, RoomCaptureSessionDelegate, AssetNodeDelegate, InfoViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var showObjectBoxesSwitch: UISwitch!
//    var showAssetBoxesSwitch: UISwitch! = UISwitch()

    // RoomPlan: Data API
    lazy var captureSession: RoomCaptureSession = {
        let captureSession = RoomCaptureSession()
        return captureSession
    }()
    var captureSessionConfig: RoomCaptureSession.Configuration

    // asset
    lazy var assetView: UIView = {
        let assetView = createAssetView()
        return assetView
    }()
    var imageNames: [String]
    var imageButtons: [UIButton]
    var usdzNodes: [String: SCNNode]
    var assetModels: [String: AssetModel]
    var selectedAssetNode: AssetNode?
    var highlightedObjectNode: ObjectNode?
    var placedAssetNodes: [AssetNode]
    var exportButton: UIButton?
    var doneButton : UIButton?

    // picker
    var pickerData: [String]
    var selectedObjectNode: ObjectNode?
    var infoView: InfoView?
    var infoViewAnimationDuration = 0.45
    var isInfoViewActive: Bool

    // objects
    var objectNodes: [UUID: ObjectNode]

    // status
    var debugMessage: String
    var statusMessage: String
    var sessionMessage: String
//    var skView : SKView
    var roomBuilder = RoomBuilder(options: [.beautifyObjects])
//    let coachView : ARCoachingOverlayView! = ARCoachingOverlayView()
    private var finalResults: CapturedRoom?
    var usdUrl : URL?
    var detialUrl : URL?

    required init?(coder: NSCoder) {
        // RoomPlan: Data API
        var captureSessionConfig = RoomCaptureSession.Configuration()
        captureSessionConfig.isCoachingEnabled = true
        self.captureSessionConfig = captureSessionConfig

        // asset
        imageNames = roomAssetImageNames()
        imageButtons = [UIButton]()
        usdzNodes = [String: SCNNode]()
        assetModels = roomAssetModels()
        selectedAssetNode = nil
        highlightedObjectNode = nil
        placedAssetNodes = [AssetNode]()

        // picker
        pickerData = capturedRoomObjectCategoryStrings()
        selectedObjectNode = nil
        isInfoViewActive = false

        // objects
        objectNodes = [UUID: ObjectNode]()

        // status
        debugMessage = ""
        statusMessage = ""
        sessionMessage = ""

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        DispatchQueue.main.async {
            self.setupUSDZAssets() {
                self.setupAssetView()
            }
        }

        setupInfoView()
        setupScene()
        setupCaptureSession()
        startCaptureSession()
        addTapGestureToSceneView()
        addLongPressGestureToSceneView()
        setupButton()
    }
    
    func setupButton() {
        doneButton = UIButton(type: .custom)
        doneButton?.setTitle("done", for: .normal)
        doneButton?.setTitleColor(.blue, for: .normal)
        doneButton?.addTarget(self, action: #selector(done), for: .touchUpInside)
        self.view.addSubview(doneButton!)
        doneButton?.frame = CGRectMake(self.view.frame.size.width - 80, 60, 60, 20)
    }

    override func viewSafeAreaInsetsDidChange() {
        guard let infoView = infoView else {
            return
        }
        // this is very important; otherwise, some of the infoView subviews get cut off or don't render properly
        // e.g., labelView gets cut off or is missing; statsView gets cut off showing "..."
        var proposedViewSize = infoView.bounds.size
        proposedViewSize.height += view.safeAreaInsets.bottom
        infoView.frame = CGRectMake(0.0, 0.5 * (view.bounds.height - proposedViewSize.height), proposedViewSize.width, proposedViewSize.height)
    }
    
    @objc func done(sender : UIButton) {
        self.captureSession.stop();
    }

    private func setupInfoView() {
        let labelSize = CGSizeMake(view.bounds.width, 60)
        let pickerSize = CGSizeMake(view.bounds.width, 160)
        let statsSize = CGSizeMake(view.bounds.width, 90)
        let infoView = InfoView(pickerData: capturedRoomObjectCategoryStrings(), labelSize: labelSize, pickerSize: pickerSize, statsSize: statsSize, backgroundColor: themeBackPlaneColor, labelBackgroundColor: themeFrontPlaneColor, labelTextColor: themeTextColor)
        infoView.sizeToFit()

        var proposedViewSize = infoView.bounds.size
        proposedViewSize.height += view.safeAreaInsets.top + view.safeAreaInsets.bottom
        infoView.frame = CGRectMake(0.0, 0.5 * (view.bounds.height - proposedViewSize.height), proposedViewSize.width, proposedViewSize.height)
        infoView.layer.cornerRadius = 12
        infoView.alpha = 0.0

        infoView.delegate = self

        self.infoView = infoView
        

        view.addSubview(infoView)
    }

    @objc func didTap(with gestureRecognizer: UITapGestureRecognizer) {
        guard !isInfoViewActive else {
            print("infoView is active; cannot tap")
            return
        }

        let touchLocation = gestureRecognizer.location(in: sceneView)
        let hitResults = sceneView.hitTest(touchLocation, options: [.ignoreHiddenNodes: false, .searchMode: 1])
        if let objectNode = objectNodeWithLabel(from: hitResults) {
            guard let pointOfView = sceneView.pointOfView
            else {
                return
            }
            selectedObjectNode = objectNode
            objectNode.startEditingLabel(with: pointOfView)

            showInfoView(with: objectNode)
        }
    }

    @objc func didLongPress(with gestureRecognizer: UILongPressGestureRecognizer) {
        guard !isInfoViewActive else {
            print("infoView is active; cannot long press")
            return
        }

        let touchLocation = gestureRecognizer.location(in: sceneView)
        switch gestureRecognizer.state {
        case .possible:
            break
        case .began:
            let hitResults = sceneView.hitTest(touchLocation, options: [.ignoreHiddenNodes: false, .searchMode: 1])

            // prioritize touches on assets (before room objects)
            if let assetNode = assetNode(from: hitResults) {
                // piggybacking onto button long press logic
                // TODO: - refactor
                selectedAssetNode = assetNode
                selectedAssetNode?.delegate = self
                didLongPressButton(with: gestureRecognizer)
            } else if let objectNode = objectNodeWithLabel(from: hitResults) {
                guard let pointOfView = sceneView.pointOfView
                else {
                    return
                }
                selectedObjectNode = objectNode
                objectNode.startEditingLabel(with: pointOfView)

                showInfoView(with: objectNode)
            }
        case .changed:
            guard selectedAssetNode != nil else {
                return
            }
            didLongPressButton(with: gestureRecognizer)
            break
        case .ended:
            guard selectedAssetNode != nil else {
                return
            }
            didLongPressButton(with: gestureRecognizer)
            break
        case .cancelled:
            fallthrough
        case .failed:
            fallthrough
        @unknown default:
            guard selectedAssetNode != nil else {
                return
            }
            didLongPressButton(with: gestureRecognizer)
            break
        }
    }

    @IBAction func didTapShowObjectBoxesSwitch(_ sender: UISwitch) {
        for (_, objectNode) in objectNodes {
            objectNode.box.opacity = sender.isOn ? 1.0 : 0.0
//            objectNode.label.opacity = sender.isOn ? 1.0 : 0.0
        }
        assetView.isHidden = !sender.isOn
    }

    private func addTapGestureToSceneView() {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.didTap(with:)))
        sceneView.addGestureRecognizer(gestureRecognizer)
    }

    private func addLongPressGestureToSceneView() {
        let gestureReognizer = UILongPressGestureRecognizer(target: self, action: #selector(ViewController.didLongPress(with:)))
        sceneView.addGestureRecognizer(gestureReognizer)
    }

    private func objectNodeWithLabel(from hitResults: [SCNHitTestResult]) -> ObjectNode? {
        for result in hitResults {
            // logic: detect touches on all objects (including both boxes and labels)
            // because it's difficult to accurately touch just the labels
            let node = result.node
            if let uuidStringCandidate = node.name,
               let uuid = UUID(uuidString: uuidStringCandidate),
               let objectNode = objectNodes[uuid] {
                return objectNode
            }
        }

        return nil
    }

    private func assetNode(from hitResults: [SCNHitTestResult]) -> AssetNode? {
        for result in hitResults {
            let node = result.node
            for placedAssetNode in placedAssetNodes {
                let asset = placedAssetNode.asset
                if node.parent == asset {
                    return placedAssetNode
                }
            }
        }

        return nil
    }
}

// MARK: - Scene Management

extension ViewController {
    func setupScene() {
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
    }

    func updateStatusLabel() {
        // for testing, prioritize debug strings
        guard debugMessage == "" else {
            statusLabel.text = debugMessage
            return
        }

        // next, prioritize status messages
        guard statusMessage == "" else {
            statusLabel.text = statusMessage
            return
        }

        // next, prioritize session messages
        guard sessionMessage == "" else {
            statusLabel.text = sessionMessage
            return
        }
    }
}

// MARK: - RoomPlan: Data API

extension ViewController {
    private func setupCaptureSession() {
        captureSession.delegate = self
    }

    private func startCaptureSession() {
        captureSession.run(configuration: captureSessionConfig)
    }

    private func stopCaptureSession() {
        captureSession.stop()
    }
}

// MARK: - RoomCaptureSessionDelegate

extension ViewController {
    private func logRoomObjects(_ room: CapturedRoom) {
        print("LOGGING ROOM OBJECTS")
        print(" -------------------- ")
        for object in room.objects {
            let uuidString = object.identifier.uuidString
            let categoryString = rp2.text(for: object.category)
            let position = object.transform.translation()
            let dimensions = object.dimensions
            print("object: identifier: \(uuidString), category: \(categoryString), position: \(position), dimensions: \(dimensions)")
        }
        print(" -------------------- ")
    }

    private func updateObjectNodes(with room: CapturedRoom) {
        var objectNodeKeys = Set(self.objectNodes.keys)

        for object in room.objects {
            let uuid = object.identifier

            let dimensions = object.dimensions
            let transform = object.transform
            let category = object.category
            let model = ObjectModel(dimensions: dimensions, transform: transform, category: category)

            if let objectNode = self.objectNodes[uuid] {
                objectNodeKeys.remove(uuid)
                objectNode.update(with: model)
            } else {
                let objectNode = ObjectNode(model: model, uuid: uuid)
                objectNode.box.opacity = self.showObjectBoxesSwitch.isOn ? 1.0 : 0.0

                self.objectNodes[uuid] = objectNode
                self.sceneView.scene.rootNode.addChildNode(objectNode.box)
                self.sceneView.scene.rootNode.addChildNode(objectNode.label)
            }
        }

        // remove any object nodes that are no longer in room
        for uuid in objectNodeKeys {
            if let objectNode = self.objectNodes[uuid] {
                objectNode.cleanup()
                self.objectNodes[uuid] = nil
            }
        }
    }

    private func addObjectNodes(with room: CapturedRoom) {
        for object in room.objects {
            let uuid = object.identifier

            let dimensions = object.dimensions
            let transform = object.transform
            let category = object.category
            let model = ObjectModel(dimensions: dimensions, transform: transform, category: category)

            guard self.objectNodes[uuid] == nil else {
                print("error: there's already an object with uuid: \(uuid.uuidString)")
                return
            }
            let objectNode = ObjectNode(model: model, uuid: uuid)
            objectNode.box.opacity = self.showObjectBoxesSwitch.isOn ? 1.0 : 0.0

            self.objectNodes[uuid] = objectNode
            self.sceneView.scene.rootNode.addChildNode(objectNode.box)
            self.sceneView.scene.rootNode.addChildNode(objectNode.label)
        }
    }

    private func removeObjectNodes(with room: CapturedRoom) {
        for object in room.objects {
            let uuid = object.identifier
            if let objectNode = self.objectNodes[uuid] {
                objectNode.cleanup()
                self.objectNodes[uuid] = nil
            }
        }
    }

    private func changeObjectNodes(with room: CapturedRoom) {
        for object in room.objects {
            let uuid = object.identifier

            let dimensions = object.dimensions
            let transform = object.transform
            let category = object.category
            let model = ObjectModel(dimensions: dimensions, transform: transform, category: category)

            guard let objectNode = self.objectNodes[uuid] else {
                print("error: there should be an object to change")
                return
            }
            objectNode.update(with: model)
        }
    }

    /// session has live snapshot / wholesale update
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        DispatchQueue.main.async {
            print("captureSession(_:didUpdate:)")
            //self.logRoomObjects(room)
            self.updateObjectNodes(with: room)
        }
    }

    /// session has newly added surfaces and objects
    func captureSession(_ session: RoomCaptureSession, didAdd room: CapturedRoom) {
        DispatchQueue.main.async {
            print("captureSession(_:didAdd:)")
            //self.logRoomObjects(room)
            self.addObjectNodes(with: room)
        }
    }

    /// session has changed dimensions and transform properties of surfaces and objects
    func captureSession(_ session: RoomCaptureSession, didChange room: CapturedRoom) {
        DispatchQueue.main.async {
            print("captureSession(_:didChange:)")
            //self.logRoomObjects(room)
            self.changeObjectNodes(with: room)
        }
    }

    /// session has recently removed surfaces and objects
    func captureSession(_ session: RoomCaptureSession, didRemove room: CapturedRoom) {
        DispatchQueue.main.async {
            print("captureSession(_:didRemove:)")
            //self.logRoomObjects(room)
            self.removeObjectNodes(with: room)
        }
    }

    /// session has user guidance instructions
    func captureSession(_ session: RoomCaptureSession, didProvide instruction: RoomCaptureSession.Instruction) {
        switch instruction {
        case .moveCloseToWall:
            sessionMessage = "请靠近墙壁"
        case .moveAwayFromWall:
            sessionMessage = "请别靠那么近"
        case .slowDown:
            sessionMessage = "请降低相机移动速度"
        case .turnOnLight:
            sessionMessage = "光线太暗请保持光线充足"
        case .normal:
            //sessionMessage = "Session: Normal"
            sessionMessage = "请缓慢移动手机并确保扫描房间内所有的墙壁"
        case .lowTexture:
            sessionMessage = "未检测到空间内任何墙壁,请在一个密闭空间内测试"
        @unknown default:
            sessionMessage = ""
        }
    }

    /// session starts with a configuration
    func captureSession(_ session: RoomCaptureSession, didStartWith configuration: RoomCaptureSession.Configuration) {
        sceneView.session = session.arSession
//        self.coachView.session = sceneView.session;
//        self.view.addSubview(self.coachView);
//        self.coachView.frame = sceneView.bounds;
    }

    /// session ends with either CapturedRoom or error
    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        if let errorMessage = error?.localizedDescription {
            debugPrint("Captured room data with error: \(errorMessage)")
            sessionMessage = "构建失败,请重启demo: \(errorMessage)"
            return
        }
        Task {
            do {
                finalResults = try await roomBuilder.capturedRoom(from: data)
                exportResults()
            } catch {
                print("\(error)")
            }
            
        }
        
    }
}

// MARK: - ARSCNViewDelegate

extension ViewController {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {}

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {}

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {}
}

// MARK: - Render Management (SCNSceneRendererDelegate)

extension ViewController {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.updateStatusLabel()

            for (_, objectNode) in self.objectNodes {
                objectNode.updateAt(time: time)
            }
        }
    }
}

// MARK: - InfoViewDelegate

extension ViewController {
    func infoViewDidTapCloseButton(_ infoView: InfoView, with title: String?) {
        guard let selectedObjectNode = selectedObjectNode,
              let title = title
        else {
            print("selectedObjectNode is nil")
            return
        }
        selectedObjectNode.updateLabelText(title)
        hideInfoView()
    }
    
    func exportResults() {

        let destinationFolderURL = FileManager.default.temporaryDirectory.appending(path: "Export")
        let destinationURL = destinationFolderURL.appending(path: "Room.usdz")
        let capturedRoomURL = destinationFolderURL.appending(path: "Room.json")
        do {
            try FileManager.default.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true)
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(finalResults)
            try jsonData.write(to: capturedRoomURL)
            try finalResults?.export(to: destinationURL, exportOptions: .mesh)
            usdUrl = destinationURL
            detialUrl = capturedRoomURL;
            let roomInfo : Dictionary = ["detial":detialUrl!,"usd":usdUrl!,"roomData":finalResults!] as [String : Any];
            if let roomViewController = RoomPlanDisplayViewController(info: roomInfo) {
                roomViewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen;
                self.present(roomViewController, animated: true)
            }
            
        } catch {
            usdUrl = nil
            detialUrl = nil
            print("Error = \(error)")
        }
    }
}
