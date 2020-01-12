//
//  ViewController.swift
//  sbhacks
//
//  Created by Hengyu Liu on 1/10/20.
//  Copyright © 2020 Hengyu Liu. All rights reserved.
//

import UIKit
import Firebase
import AVFoundation
import CoreVideo
import Mapbox
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
	
	private var currentDetector: String = "On-Device Face Detection"
	private var isUsingFrontCamera = true
	private lazy var captureSession = AVCaptureSession()
	private lazy var vision = Vision.vision()
	private var lastFrame: CMSampleBuffer?
	private lazy var modelManager = ModelManager.modelManager()
	private var sessionQueue = DispatchQueue(label: "detectFaceQueue")
	private var inAlarm = false
	
	private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
	
	var firstTimeCloseEyes: DispatchTime?
	var player: AVAudioPlayer?

	@IBOutlet weak var mapView: UIView!
	
	@IBOutlet weak var leadingCons: NSLayoutConstraint!
	@IBOutlet weak var topCons: NSLayoutConstraint!
	@IBOutlet weak var trailingCons: NSLayoutConstraint!
	@IBOutlet weak var bottomCons: NSLayoutConstraint!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		setUpCaptureSessionOutput()
		setUpCaptureSessionInput()
		
		speechRecognizer.delegate = self
		
		SFSpeechRecognizer.requestAuthorization { _ in
        }
		
		let origin = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.9131752, longitude: -77.0324047), name: "Mapbox")
		let destination = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365), name: "White House")
		let options = NavigationRouteOptions(waypoints: [origin, destination])
		Directions.shared.calculate(options) { (waypoints, routes, error) in
			guard let route = routes?.first else { return }
			let navigationService = MapboxNavigationService(route: route, simulating: .always)
			let navigationOptions = NavigationOptions(navigationService: navigationService)
			let viewController = NavigationViewController(for: route, options: navigationOptions)
			self.addChild(viewController)
			self.mapView.addSubview(viewController.view)
			viewController.view.topAnchor.constraint(equalTo: self.mapView.topAnchor, constant: 30).isActive = true
			viewController.view.leadingAnchor.constraint(equalTo: self.mapView.leadingAnchor, constant: 30).isActive = true
			viewController.view.trailingAnchor.constraint(equalTo: self.mapView.trailingAnchor, constant: 30).isActive = true
			viewController.view.bottomAnchor.constraint(equalTo: self.mapView.bottomAnchor, constant: 30).isActive = true
			self.mapView.clipsToBounds = true
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		startSession()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		
		stopSession()
	}
	
	private func startSession() {
		sessionQueue.async {
			self.captureSession.startRunning()
		}
	}
	
	private func stopSession() {
		sessionQueue.async {
			self.captureSession.stopRunning()
		}
	}
	
	private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
		if #available(iOS 10.0, *) {
			let discoverySession = AVCaptureDevice.DiscoverySession(
				deviceTypes: [.builtInWideAngleCamera],
				mediaType: .video,
				position: .unspecified
			)
			return discoverySession.devices.first { $0.position == position }
		}
		return nil
	}
	
	func startRecording() {
		
		print("lhy result start recording")
        
        if recognitionTask != nil {  //1
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()  //2
        do {
			try audioSession.setCategory(.record)
			try audioSession.setMode(.measurement)
			try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()  //3
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        } //5
        
        recognitionRequest.shouldReportPartialResults = true  //6
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in  //7
            
            var isFinal = false  //8
            
            if result != nil {
                
				if let string = result?.bestTranscription.formattedString {
					if string.contains("yes") {
						DispatchQueue.main.async {
							self.audioEngine.stop()
							inputNode.removeTap(onBus: 0)
							self.recognitionRequest?.endAudio()
							
							self.recognitionRequest = nil
							self.recognitionTask = nil
						}
						
						print("lhy yes")
						
						self.inAlarm = false
						
						UIView.animate(withDuration: 1) {
							self.view.backgroundColor = .green
							self.firstTimeCloseEyes = nil
							self.topCons.constant = 3
							self.bottomCons.constant = 3
							self.view.layoutIfNeeded()
							self.mapView.layoutIfNeeded()
						}
					} else if string.contains("no") {
						DispatchQueue.main.async {
							self.audioEngine.stop()
							inputNode.removeTap(onBus: 0)
							self.recognitionRequest?.endAudio()
							
							self.recognitionRequest = nil
							self.recognitionTask = nil
						}
						
						
						print("lhy no")
						try! AVAudioSession.sharedInstance().setCategory(.playback)
						try! AVAudioSession.sharedInstance().setMode(.default)
						try! AVAudioSession.sharedInstance().setActive(true, options: [])
						
						let utterance = AVSpeechUtterance(string: "Please stop and have some rest.")
						utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
						utterance.rate = 0.4

						let synthesizer = AVSpeechSynthesizer()
						synthesizer.speak(utterance)
					}
				}
                isFinal = (result?.isFinal)!
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
				self.recognitionRequest?.endAudio()
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)  //11
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()  //12
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
    }

	private func setUpCaptureSessionOutput() {
		sessionQueue.async {
			self.captureSession.beginConfiguration()
			// When performing latency tests to determine ideal capture settings,
			// run the app in 'release' mode to get accurate performance metrics
			self.captureSession.sessionPreset = AVCaptureSession.Preset.medium
			
			let output = AVCaptureVideoDataOutput()
			output.videoSettings = [
				(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA,
			]
			let outputQueue = DispatchQueue(label: "videoDataOutputQueue")
			output.setSampleBufferDelegate(self, queue: outputQueue)
			guard self.captureSession.canAddOutput(output) else {
				print("Failed to add capture session output.")
				return
			}
			self.captureSession.addOutput(output)
			self.captureSession.commitConfiguration()
		}
	}
	
	private func setUpCaptureSessionInput() {
		sessionQueue.async {
			let cameraPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
			guard let device = self.captureDevice(forPosition: cameraPosition) else {
				print("Failed to get capture device for camera position: \(cameraPosition)")
				return
			}
			do {
				self.captureSession.beginConfiguration()
				let currentInputs = self.captureSession.inputs
				for input in currentInputs {
					self.captureSession.removeInput(input)
				}
				
				let input = try AVCaptureDeviceInput(device: device)
				guard self.captureSession.canAddInput(input) else {
					print("Failed to add capture session input.")
					return
				}
				self.captureSession.addInput(input)
				self.captureSession.commitConfiguration()
			} catch {
				print("Failed to create capture device input: \(error.localizedDescription)")
			}
		}
	}
	
	@IBAction func backButtonATriggered(_ sender: Any) {
		
		self.audioEngine.stop()
		self.recognitionRequest?.endAudio()
		
		self.recognitionRequest = nil
		self.recognitionTask = nil
		
		print("lhy no")
		try! AVAudioSession.sharedInstance().setCategory(.playback)
		try! AVAudioSession.sharedInstance().setMode(.default)
		try! AVAudioSession.sharedInstance().setActive(true, options: [])
		
		inAlarm = false
		UIView.animate(withDuration: 1) {
			self.view.backgroundColor = .green
			self.firstTimeCloseEyes = nil
			self.topCons.constant = 3
			self.bottomCons.constant = 3
			self.view.layoutIfNeeded()
			self.mapView.layoutIfNeeded()
		}
	}
	
	func triggerAlarm() {
		guard inAlarm == false else { return }
		inAlarm = true
		let fileURL: URL = URL(fileURLWithPath: "/Library/Ringtones/Sonar.m4r")
		do {
			try AVAudioSession.sharedInstance().setCategory(.playback)
			try AVAudioSession.sharedInstance().setMode(.default)
			try AVAudioSession.sharedInstance().setActive(true, options: [])
			player = try AVAudioPlayer(contentsOf: fileURL)
			player!.prepareToPlay()
			player!.play()
		} catch {
			debugPrint("\(error)")
		}
		UIView.animate(withDuration: 0.3) {
			self.view.backgroundColor = .red
			self.topCons.constant = -self.view.frame.height
			self.bottomCons.constant = self.view.frame.height
			self.view.layoutIfNeeded()
			self.mapView.layoutIfNeeded()
		}
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
			
			guard self.inAlarm else { return }
			
			let utterance = AVSpeechUtterance(string: "Hi Tom, are you still awake?")
			utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
			utterance.rate = 0.4

			let synthesizer = AVSpeechSynthesizer()
			synthesizer.speak(utterance)
		}
		
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 6) {
			guard self.inAlarm else { return }
			
			self.startRecording()
		}
		
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 12) {
			guard self.inAlarm else { return }
			
			DispatchQueue.main.async {
				self.audioEngine.stop()
				self.recognitionRequest?.endAudio()
				
				self.recognitionRequest = nil
				self.recognitionTask = nil
			}
			
			try! AVAudioSession.sharedInstance().setCategory(.playback)
			try! AVAudioSession.sharedInstance().setMode(.default)
			try! AVAudioSession.sharedInstance().setActive(true, options: [])
			
			let utterance = AVSpeechUtterance(string: "Please stop and have some rest.")
			utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
			utterance.rate = 0.5

			let synthesizer = AVSpeechSynthesizer()
			synthesizer.speak(utterance)
		}
		
	}
	
	private func detectFacesOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
		let options = VisionFaceDetectorOptions()
		
		// When performing latency tests to determine ideal detection settings,
		// run the app in 'release' mode to get accurate performance metrics
		options.landmarkMode = .none
		options.contourMode = .all
		options.classificationMode = .all
		
		options.performanceMode = .fast
		let faceDetector = vision.faceDetector(options: options)
		
		var detectedFaces: [VisionFace]? = nil
		do {
			detectedFaces = try faceDetector.results(in: image)
		} catch let error {
			print("Failed to detect faces with error: \(error.localizedDescription).")
		}
		guard let faces = detectedFaces, !faces.isEmpty else {
			print("On-Device face detector returned no results.")
			firstTimeCloseEyes = nil
			return
		}
		
		for face in faces {
			let pro = face.leftEyeOpenProbability + face.rightEyeOpenProbability
			if pro < 0.7 {
				if let time = firstTimeCloseEyes {
					print("closed eyes for \(Double(DispatchTime.now().uptimeNanoseconds - time.uptimeNanoseconds) * 0.000000001)")
					if (Double(DispatchTime.now().uptimeNanoseconds - time.uptimeNanoseconds) * 0.000000001) > 0.8 {
						firstTimeCloseEyes = nil
						DispatchQueue.main.async {
							self.triggerAlarm()
						}
					}
				} else {
					print("first time closed eyes")
					firstTimeCloseEyes = DispatchTime.now()
				}
			} else {
				print("open eyes")
				firstTimeCloseEyes = nil
			}
		}
	}
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
	
	func captureOutput(
		_ output: AVCaptureOutput,
		didOutput sampleBuffer: CMSampleBuffer,
		from connection: AVCaptureConnection
	) {
		guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
			print("Failed to get image buffer from sample buffer.")
			return
		}
		lastFrame = sampleBuffer
		let visionImage = VisionImage(buffer: sampleBuffer)
		let metadata = VisionImageMetadata()
		let orientation = UIUtilities.imageOrientation(
			fromDevicePosition: isUsingFrontCamera ? .front : .back
		)
		
		let visionOrientation = UIUtilities.visionImageOrientation(from: orientation)
		metadata.orientation = visionOrientation
		visionImage.metadata = metadata
		let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
		let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
		detectFacesOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
	}
}


private enum Constant {
	static let alertControllerTitle = "Vision Detectors"
	static let alertControllerMessage = "Select a detector"
	static let cancelActionTitleText = "Cancel"
	static let videoDataOutputQueueLabel = "com.google.firebaseml.visiondetector.VideoDataOutputQueue"
	static let sessionQueueLabel = "com.google.firebaseml.visiondetector.SessionQueue"
	static let noResultsMessage = "No Results"
	static let remoteAutoMLModelName = "remote_automl_model"
	static let localModelManifestFileName = "automl_labeler_manifest"
	static let autoMLManifestFileType = "json"
	static let labelConfidenceThreshold: Float = 0.75
	static let smallDotRadius: CGFloat = 4.0
	static let originalScale: CGFloat = 1.0
	static let padding: CGFloat = 10.0
	static let resultsLabelHeight: CGFloat = 200.0
	static let resultsLabelLines = 5
}

