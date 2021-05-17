//
//  ViewController.swift
//  StyleCam
//
//  Created by Om Duggineni on 2/22/21.
//

import UIKit
import AVFoundation
import CoreMedia
import CoreImage
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate
{
    let parentStack = UIStackView()
    let imageView = UIImageView()
    var model : VNCoreMLModel?
    
    required init?(coder: NSCoder){
        super.init(coder: coder)
        
        let config = MLModelConfiguration()
        config.computeUnits = .all
        
        do{
            let s = try Abstract2(configuration: config).model
            model = try VNCoreMLModel(for: s)
        }catch{
            return
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        setupUI()
        configureSession()
    }
    
    func setupUI(){
        view.addSubview(parentStack)
        parentStack.axis = NSLayoutConstraint.Axis.vertical
        parentStack.distribution = UIStackView.Distribution.fill
        parentStack.addArrangedSubview(imageView)
        imageView.contentMode = UIView.ContentMode.scaleAspectFit
    }
    
    
    func configureSession(){
        let captureSession = AVCaptureSession()
        //captureSession.sessionPreset = AVCaptureSession.Preset.medium
        
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified).devices
        
        do {
            if let captureDevice = availableDevices.first {
                captureSession.addInput(try AVCaptureDeviceInput(device: captureDevice))
            }
        } catch {
            print(error.localizedDescription)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.omduggineni.stylecamera.style_transfer_ops_queue"))
        if captureSession.canAddOutput(videoOutput){
            captureSession.addOutput(videoOutput)
        }
        
        guard let connection = videoOutput.connection(with: .video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let request = VNCoreMLRequest(model: model!) { (finishedRequest, error) in
            DispatchQueue.main.async(execute: {
                guard let results = finishedRequest.results as? [VNPixelBufferObservation] else {return}
                guard let result = results.first else {return}
                
                self.imageView.image = UIImage(ciImage: CIImage(cvPixelBuffer: result.pixelBuffer))
            })
        }
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let topMargin = topLayoutGuide.length
        parentStack.frame = CGRect(x: 0, y: topMargin, width: view.frame.width, height: view.frame.height - topMargin).insetBy(dx: 5, dy: 5)
    }
}
