//
//  VisionPresentationViewController.swift
//  cv-assist-ios
//
//  Created by Maksim on 12/14/17.
//  Copyright © 2017 Mapbox. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import MetalKit
import AVKit
import MapboxVisionCore

private let contentInset: CGFloat = 16
private let safeAreaContentInset: CGFloat = 2
private let innerRelativeInset: CGFloat = 10

/**
    An object that is capable of presenting objects emitted with VisionManager events
*/

public final class VisionPresentationViewController: UIViewController {
    
    /**
        Set visualization mode which can be either original frame, original frame with segmentation as an overlay or original frame with detections as an overlay.
     */
    public var frameVisualizationMode: VisualizationMode = .clear {
        didSet {
            let oldTopView = view(for: oldValue)
            oldTopView.isHidden = true
            
            let newTopView = view(for: frameVisualizationMode)
            backgroundView.bringSubview(toFront: newTopView)
        }
    }
    
    /**
        Control the visibility of the Mapbox logo.
     */
    public var isLogoVisible: Bool {
        get {
            return !logoView.isHidden
        }
        set {
            logoView.isHidden = !newValue
        }
    }
    
    private var contentContainerConstraints = [NSLayoutConstraint]()
    
    private func view(for mode: VisualizationMode) -> UIView {
        switch mode {
        case .clear:
            return videoStreamView
        case .segmentation:
            return segmentationView
        case .detection:
            return detectionsView
        }
    }
  
    private lazy var segmentationDrawer: SegmentationDrawer? = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            assertionFailure("SegmentationDrawer: Can't create MTLDevice")
            return nil
        }
        return SegmentationDrawer(device: device)
    }()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
    }
    
    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        setupContentView()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupContentView()
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.setupContentView()
        })
    }
    
    private func setupContentView() {
        NSLayoutConstraint.deactivate(contentContainerConstraints)
        
        var leadingInset: CGFloat = contentInset
        var trailingInset: CGFloat = contentInset
        
        if view.safeAreaInsets.right > 0 {
            // iPhone X in landscape
            let uiOrientation = UIApplication.shared.statusBarOrientation
            if uiOrientation == .landscapeRight {
                // notch is on the left
                leadingInset = view.safeAreaInsets.left
            } else if uiOrientation == .landscapeLeft {
                // notch is on the right
                trailingInset = view.safeAreaInsets.right
            }
        }
        
        let topInset = view.safeAreaInsets.top > 0 ? safeAreaContentInset + view.safeAreaInsets.top : contentInset
        let bottomInset = contentInset
        
        contentContainerConstraints = [
            contentView.topAnchor.constraint(equalTo: view.topAnchor, constant: topInset),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -bottomInset),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingInset),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -trailingInset),
        ]
        
        NSLayoutConstraint.activate(contentContainerConstraints)
    }
    
    private func setupLayout() {
        setupBackgroundView()
        
        setupContentLayout()
        
        view.addSubview(logoView)
        NSLayoutConstraint.activate([
            view.safeAreaLayoutGuide.bottomAnchor.constraintEqualToSystemSpacingBelow(logoView.bottomAnchor, multiplier: 1),
            view.safeAreaLayoutGuide.rightAnchor.constraintEqualToSystemSpacingAfter(logoView.rightAnchor, multiplier: 1),
        ])
    }
    
    private func setupBackgroundView() {
        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        backgroundView.addSubview(videoStreamView)
        NSLayoutConstraint.activate([
            videoStreamView.topAnchor.constraint(equalTo: view.topAnchor),
            videoStreamView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            videoStreamView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoStreamView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        backgroundView.addSubview(segmentationView)
        NSLayoutConstraint.activate([
            segmentationView.topAnchor.constraint(equalTo: view.topAnchor),
            segmentationView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            segmentationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            segmentationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        backgroundView.addSubview(detectionsView)
        NSLayoutConstraint.activate([
            detectionsView.topAnchor.constraint(equalTo: view.topAnchor),
            detectionsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            detectionsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            detectionsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    
    private func setupContentLayout() {
        view.addSubview(contentView)
        
        contentView.addSubview(measurementStack)
        NSLayoutConstraint.activate([
            measurementStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            measurementStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        ])
    }
    
    private func fpsLabel(text: String? = nil) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont(name: "Menlo", size: 10)
        label.text = text
        return label
    }
    
    private func fpsStack(views: [UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = innerRelativeInset
        stack.distribution = .equalCentering
        return stack
    }

    private let videoStreamView: VideoStreamView = {
        let view = VideoStreamView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let segmentationView: MTKView = {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.autoResizeDrawable = false
        view.contentMode = .scaleAspectFill
        view.isHidden = true
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        return view
    }()
    
    private let detectionsView: DetectionsView = {
        let view = DetectionsView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }()
    
    private let logoView: UIView = {
        let view = UIImageView(image: VisionImages.logo.image)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0.5
        return view
    }()
    
    private lazy var segmentationFPSLabel: UILabel = fpsLabel()
    private lazy var detectionFPSLabel: UILabel = fpsLabel()
    private lazy var mergedSegDetectFPSLabel: UILabel = fpsLabel()
    private lazy var roadConfidenceFPSLabel: UILabel = fpsLabel()
    private lazy var coreUpdateFPSLabel: UILabel = fpsLabel()
    
    private lazy var measurementStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            fpsStack(views: [fpsLabel(text: "Segmentation:"), segmentationFPSLabel]),
            fpsStack(views: [fpsLabel(text: "Detection:"), detectionFPSLabel]),
            fpsStack(views: [fpsLabel(text: "Merged S+D:"), mergedSegDetectFPSLabel]),
            fpsStack(views: [fpsLabel(text: "Road conf:"), roadConfidenceFPSLabel]),
            fpsStack(views: [fpsLabel(text: "Core update:"), coreUpdateFPSLabel]),
        ])
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.distribution = .equalCentering
        stack.spacing = innerRelativeInset
        stack.isHidden = true
        
        let backgroundView = UIView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        stack.insertSubview(backgroundView, at: 0)
        
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: stack.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
        ])
        
        return stack
    }()
}

extension VisionPresentationViewController {
    public func present(sampleBuffer: CMSampleBuffer) {
        guard frameVisualizationMode == .clear else { return }
        
        DispatchQueue.main.async {
            guard self.viewIfLoaded?.window != nil else { return }
            self.videoStreamView.enqueue(sampleBuffer)
        }
    }
    
    public func present(fps: FPSValue?) {
        measurementStack.isHidden = fps == nil
        guard let fps = fps else { return }
        segmentationFPSLabel.text = String(format: "%.2f", fps.segmentation)
        detectionFPSLabel.text = String(format: "%.2f", fps.detection)
        mergedSegDetectFPSLabel.text = String(format: "%.2f", fps.mergedSegmentationDetection)
        roadConfidenceFPSLabel.text = String(format: "%.2f", fps.roadConfidence)
        coreUpdateFPSLabel.text = String(format: "%.2f", fps.coreUpdate)
    }

    public func present(segmentation: SegmentationMask) {
        guard frameVisualizationMode == .segmentation else { return }
        
        if segmentationView.delegate == nil {
            segmentationView.delegate = segmentationDrawer
        }
    
        segmentationView.isHidden = false
        
        let sourceImage = segmentation.sourceImage
        segmentationView.drawableSize = CGSize(width: CGFloat(sourceImage.width), height: CGFloat(sourceImage.height))
        segmentationDrawer?.set(segmentation)
        segmentationView.draw()
    }
    
    public func present(detections: Detections) {
        guard
            frameVisualizationMode == .detection,
            let image = detections.sourceImage.getUIImage()
        else { return }
        
        let sourceImage = detections.sourceImage
        let imageSize = CGSize(width: sourceImage.width, height: sourceImage.height)
        
        let values = detections.items.map { detection -> BasicDetection in
            let rect = detection.boundingBox.convertForAspectRatioFill(from: imageSize, to: detectionsView.bounds.size)
            return BasicDetection(boundingBox: rect, objectType: detection.objectType)
        }
        
        detectionsView.isHidden = false
        detectionsView.present(detections: values, at: image)
    }
}

private extension CGRect {
    func convertForAspectRatioFill(from: CGSize, to: CGSize) -> CGRect {
        let leftTop = origin.convertForAspectRatioFill(from: from, to: to)
        let rightBottom = CGPoint(x: maxX, y: maxY).convertForAspectRatioFill(from: from, to: to)
        return CGRect(x: leftTop.x, y: leftTop.y, width: rightBottom.x - leftTop.x, height: rightBottom.y - leftTop.y)
    }
}
