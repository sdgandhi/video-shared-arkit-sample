//
//  AliceViewController.swift
//  DesignConsult
//
//  Created by Jennifer Aprahamian on 10/20/17.
//  Copyright © 2017 Twilio. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import TwilioVideo

class AliceViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    var accessToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImN0eSI6InR3aWxpby1mcGE7dj0xIn0.eyJqdGkiOiJTSzJiZTRjNGFiOGVmNjNkOWZmZDM1MjFiZTA5Nzg1OWJhLTE1MDg3ODA2NjUiLCJpc3MiOiJTSzJiZTRjNGFiOGVmNjNkOWZmZDM1MjFiZTA5Nzg1OWJhIiwic3ViIjoiQUM5OWJhN2I2MWZiZGI2YzAzOTY5ODUwNWRlYTVmMDQ0YyIsImV4cCI6MTUwODc4NDI2NSwiZ3JhbnRzIjp7ImlkZW50aXR5IjoiQWxpY2UiLCJ2aWRlbyI6eyJyb29tIjoiRGVzaWduQ29uc3VsdCJ9fX0.qF4v1TbaTHD7tpLGz-KDbODEmU1MI3hfS1ODwEcgHjs"
    var room: TVIRoom?
    weak var consumer: TVIVideoCaptureConsumer?
    var frame: TVIVideoFrame?
    var displayLink: CADisplayLink?
    var screencast: Bool?
    
    var supportedFormats = [TVIVideoFormat]()
    var videoTrack: TVILocalVideoTrack?
    var audioTrack: TVILocalAudioTrack?
    var dataTrack: TVIRemoteDataTrack?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.preferredFramesPerSecond = 30
        sceneView.contentScaleFactor = 1
        
        // Create a new scene and set it to the view
        let scene = SCNScene()
        self.sceneView.scene = scene
        self.supportedFormats = [TVIVideoFormat()]
        
        sceneView.debugOptions =
            [ARSCNDebugOptions.showFeaturePoints] //show feature points to improve likelihood of HitResult
        
        let capturer: TVIVideoCapturer = TVIScreenCapturer.init(view: self.sceneView!)
        self.videoTrack = TVILocalVideoTrack.init(capturer: capturer)
        self.audioTrack = TVILocalAudioTrack.init()
        let localDataTrack = TVILocalDataTrack()
        let connectOptions = TVIConnectOptions(token: accessToken, block: {(_ builder: TVIConnectOptionsBuilder) -> Void in
            builder.videoTracks = [self.videoTrack!]
            builder.roomName = "DesignConsult"
            builder.dataTracks = [localDataTrack!]
        })
        // Connect to the room
        self.room = TwilioVideo.connect(with: connectOptions, delegate: self)
        
    }
    
    func placeObjectAtLocation(location: String) {
        // trim because it comes wrapped in parens right now
        let trimmed = location.dropLast().dropFirst()
        let locationPoint: CGPoint = CGPointFromString("{\(trimmed)}")
        let hitResult = self.sceneView.hitTest(locationPoint, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane])
        if hitResult.count > 0 {
            guard let hitTestResult = hitResult.first else  {
                return
            }
            //          sphere while testing, replace with furniture objects corresponding to those in designer side app
            let ball = SCNSphere(radius: 0.1)
            ball.firstMaterial?.diffuse.contents = UIColor.cyan
            ball.firstMaterial?.specular.contents = UIColor.blue
            let ballNode = SCNNode(geometry: ball)
            let worldPosition = hitTestResult.worldTransform
            ballNode.position = SCNVector3(worldPosition.columns.3.x, worldPosition.columns.3.y, worldPosition.columns.3.z)
            
            sceneView.scene.rootNode.addChildNode(ballNode)
        }
    }
    
    //    OLD -- for tap events, replacing with data track messages
    //    func registerGestureRecognizer() {
    //        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    //        sceneView.addGestureRecognizer(tap)
    //    }
    //    @objc func handleTap(gestureRecognizer: UIGestureRecognizer){
    //
    //    }
    
    func startCapture(format: TVIVideoFormat, consumer: TVIVideoCaptureConsumer) {
        self.consumer = consumer
        self.displayLink = CADisplayLink(target: self, selector: #selector(self.displayLinkDidFire))
        self.displayLink?.preferredFramesPerSecond = self.sceneView.preferredFramesPerSecond
        // Set to half of screen refresh, which should be 30fps.
        //[_displayLink set:30];
        displayLink?.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
        consumer.captureDidStart(true)
    }
    
    @objc func displayLinkDidFire() {
        let myImage = self.sceneView.snapshot
        print("\(NSStringFromCGSize(myImage().size))")
        let imageRef = myImage().cgImage!
        let pixelBuffer = self.pixelBufferFromCGImage1(fromCGImage1: imageRef)
        self.frame = TVIVideoFrame(timestamp: Int64((displayLink?.timestamp)! * 1000000), buffer: pixelBuffer, orientation: TVIVideoOrientation.up)
        self.consumer?.consumeCapturedFrame(self.frame!)
    }
    
    func pixelBufferFromCGImage1(fromCGImage1 image: CGImage) -> CVPixelBuffer {
        let frameSize = CGSize(width: image.width, height: image.height)
        let options: [AnyHashable: Any]? = [kCVPixelBufferCGImageCompatibilityKey: false, kCVPixelBufferCGBitmapContextCompatibilityKey: false]
        var pixelBuffer: CVPixelBuffer? = nil
        let status: CVReturn? = CVPixelBufferCreate(kCFAllocatorDefault, Int(frameSize.width), Int(frameSize.height), kCVPixelFormatType_32ARGB, (options! as CFDictionary), &pixelBuffer)
        if status != kCVReturnSuccess {
            return NSNull.self as! CVPixelBuffer
        }
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace: CGColorSpace? = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: data, width: Int(frameSize.width), height: Int(frameSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace!, bitmapInfo: (CGImageAlphaInfo.noneSkipLast.rawValue))
        context?.draw(image, in: CGRect(x:0, y:0, width: image.width, height: image.height))
        //CGContextRelease(context!)
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer!
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
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

// MARK: TVIRoomDelegate
extension AliceViewController : TVIRoomDelegate {
    func didConnect(to room: TVIRoom) {
        if (room.remoteParticipants.count > 0) {
            let remoteParticipant = room.remoteParticipants[0]
            remoteParticipant.delegate = self
        }
    }
    
    func room(_ room: TVIRoom, participantDidConnect participant: TVIRemoteParticipant) {
        participant.delegate = self
    }
}

// MARK: TVIRemoteParticipantDelegate
extension AliceViewController : TVIRemoteParticipantDelegate {
    // Participant has published data track
    func remoteParticipant(_ participant: TVIRemoteParticipant, publishedDataTrack publication: TVIRemoteDataTrackPublication) {
        print("remote participant published data track")
        
        if let remoteTrack = publication.remoteTrack {
            remoteTrack.delegate = self
        }
    }
    
    // Participant has unpublished data track
    func remoteParticipant(_ participant: TVIRemoteParticipant, unpublishedDataTrack publication: TVIRemoteDataTrackPublication) {
        print("unpublished data track exists")
    }
    
    // Data track has been subscribed to and messages can be observed.
    func subscribed(to dataTrack: TVIRemoteDataTrack, publication: TVIRemoteDataTrackPublication, for participant: TVIRemoteParticipant) {
        print("data track has been subscribed and messages can be observed")
        dataTrack.delegate = self
    }
    
    // Data track has been unsubsubscribed from and messages cannot be observed.
    func unsubscribed(from dataTrack: TVIRemoteDataTrack, publication: TVIRemoteDataTrackPublication, for participant: TVIRemoteParticipant) {
        print("unsubscribed from the data track")
    }
}

// MARK : TVIRemoteDataTrackDelegate
extension AliceViewController : TVIRemoteDataTrackDelegate {
    func remoteDataTrack(_ remoteDataTrack: TVIRemoteDataTrack, didReceive message: String) {
        // Do whatever you want with your received message string
        placeObjectAtLocation(location: message)
    }
    
    func remoteDataTrack(_ remoteDataTrack: TVIRemoteDataTrack, didReceive message: Data) {
        // Do whatever you want with your received message data
    }
}
