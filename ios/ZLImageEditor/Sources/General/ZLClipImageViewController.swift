//
//  ZLClipImageViewController.swift
//  ZLImageEditor
//
//  Created by long on 2020/8/27.
//
//  Copyright (c) 2020 Long Zhang <495181165@qq.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

extension ZLClipImageViewController {
    enum ClipPanEdge {
        case none
        case top
        case bottom
        case left
        case right
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
}

class ZLClipImageViewController: UIViewController {
    static let bottomToolViewH: CGFloat = 90
    
    static let clipRatioItemSize  = CGSize(width: 60, height: 70)
    
    var animateDismiss = true
    
    /// Animation starting frame when first enter
    var presentAnimateFrame: CGRect?
    
    /// Animation image
    var presentAnimateImage: UIImage?
    
    /// Animation starting frame when cancel clip
    var cancelClipAnimateFrame: CGRect = .zero
    
    var viewDidAppearCount = 0
    
    let originalImage: UIImage
    
    let clipRatios: [ZLImageClipRatio]
    
    var editImage: UIImage
    
    var editRect: CGRect
    
    var scrollView: UIScrollView!
    
    var containerView: UIView!
    
    var imageView: UIImageView!
    
    var shadowView: ZLClipShadowView!
    
    var overlayView: ZLClipOverlayView!
    
    var gridPanGes: UIPanGestureRecognizer!
    
    var bottomToolView: UIView!
    
    var bottomShadowLayer: CAGradientLayer!
    
    var bottomToolLineView: UIView!
    
    lazy var cancelBtn = ZLEnlargeButton(type: .custom)
    
    lazy var revertBtn = ZLEnlargeButton(type: .custom)
    
    lazy var doneBtn = ZLEnlargeButton(type: .custom)
    
    lazy var rotateBtn = ZLEnlargeButton(type: .custom)
    
    var clipRatioColView: UICollectionView!
    
    var shouldLayout = true
    
    var panEdge: ZLClipImageViewController.ClipPanEdge = .none
    
    var beginPanPoint: CGPoint = .zero
    
    var clipBoxFrame: CGRect = .zero
    
    var clipOriginFrame: CGRect = .zero
    
    var isRotating = false
    
    var angle: CGFloat = 0
    
    var selectedRatio: ZLImageClipRatio {
        didSet {
            overlayView.isCircle = selectedRatio.isCircle
        }
    }
    
    var thumbnailImage: UIImage?
    
    lazy var maxClipFrame = calculateMaxClipFrame()
    
    var minClipSize = CGSize(width: 45, height: 45)
    
    var resetTimer: Timer?
    
    var dismissAnimateFromRect: CGRect = .zero
    
    var dismissAnimateImage: UIImage?
    
    // Angle, edit rect, clip ratio
    var clipDoneBlock: ((CGFloat, CGRect, ZLImageClipRatio) -> Void)?
    
    var cancelClipBlock: (() -> Void)?
    
    override var prefersStatusBarHidden: Bool { true }
    
    override var prefersHomeIndicatorAutoHidden: Bool { true}
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    
    deinit {
        zl_debugPrint("ZLClipImageViewController deinit")
        self.cleanTimer()
    }
    
    init(image: UIImage, status: ZLClipStatus) {
        originalImage = image
        clipRatios = ZLImageEditorConfiguration.default().clipRatios
        self.editRect = status.editRect
        self.angle = status.angle
        if angle == -90 {
            editImage = image.zl.rotate(orientation: .left)
        } else if self.angle == -180 {
            editImage = image.zl.rotate(orientation: .down)
        } else if self.angle == -270 {
            editImage = image.zl.rotate(orientation: .right)
        } else {
            editImage = image
        }
        var firstEnter = false
        if let ratio = status.ratio {
            selectedRatio = ratio
        } else {
            firstEnter = true
            selectedRatio = ZLImageEditorConfiguration.default().clipRatios.first!
        }
        super.init(nibName: nil, bundle: nil)
        if firstEnter {
            calculateClipRect()
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        generateThumbnailImage()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        viewDidAppearCount += 1
        if presentingViewController is ZLEditImageViewController {
            transitioningDelegate = self
        }
        
        guard viewDidAppearCount == 1 else {
            return
        }
        
        if let frame = presentAnimateFrame, let image = presentAnimateImage {
            let animateImageView = UIImageView(image: image)
            animateImageView.contentMode = .scaleAspectFill
            animateImageView.clipsToBounds = true
            animateImageView.frame = frame
            view.addSubview(animateImageView)
            
            cancelClipAnimateFrame = clipBoxFrame
            UIView.animate(withDuration: 0.25, animations: {
                animateImageView.frame = self.clipBoxFrame
                self.bottomToolView.alpha = 1
                self.rotateBtn.alpha = 1
            }) { _ in
                UIView.animate(withDuration: 0.1, animations: {
                    self.scrollView.alpha = 1
                    self.overlayView.alpha = 1
                }) { _ in
                    animateImageView.removeFromSuperview()
                }
            }
        } else {
            bottomToolView.alpha = 1
            rotateBtn.alpha = 1
            scrollView.alpha = 1
            overlayView.alpha = 1
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard shouldLayout else {
            return
        }
        shouldLayout = false
        
        scrollView.frame = view.bounds
        shadowView.frame = view.bounds
        
        layoutInitialImage()
        
        bottomToolView.frame = CGRect(x: 0, y: view.bounds.height - ZLClipImageViewController.bottomToolViewH, width: view.bounds.width, height: ZLClipImageViewController.bottomToolViewH)
        bottomShadowLayer.frame = bottomToolView.bounds
        
        bottomToolLineView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 1 / UIScreen.main.scale)
        let toolBtnH: CGFloat = 25
        let toolBtnY = (ZLClipImageViewController.bottomToolViewH - toolBtnH) / 2 - 10
        cancelBtn.frame = CGRect(x: 30, y: toolBtnY, width: toolBtnH, height: toolBtnH)
        let revertBtnW = localLanguageTextValue(.revert).zl.boundingRect(font: ZLImageEditorLayout.bottomToolTitleFont, limitSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: toolBtnH)).width + 20
        revertBtn.frame = CGRect(x: (view.bounds.width - revertBtnW) / 2, y: toolBtnY, width: revertBtnW, height: toolBtnH)
        doneBtn.frame = CGRect(x: view.bounds.width - 30 - toolBtnH, y: toolBtnY, width: toolBtnH, height: toolBtnH)
        
        let ratioColViewY = bottomToolView.frame.minY - ZLClipImageViewController.clipRatioItemSize.height - 5
        rotateBtn.frame = CGRect(x: 30, y: ratioColViewY + (ZLClipImageViewController.clipRatioItemSize.height - 25) / 2, width: 25, height: 25)
        let ratioColViewX = rotateBtn.frame.maxX + 15
        clipRatioColView.frame = CGRect(x: ratioColViewX, y: ratioColViewY, width: view.bounds.width - ratioColViewX, height: 70)
        
        if clipRatios.count > 1, let index = clipRatios.firstIndex(where: { $0 == self.selectedRatio }) {
            clipRatioColView.scrollToItem(at: IndexPath(row: index, section: 0), at: .centeredHorizontally, animated: false)
        }
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        shouldLayout = true
        maxClipFrame = calculateMaxClipFrame()
    }
    
    func setupUI() {
        view.backgroundColor = .black
        
        scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        scrollView.delegate = self
        view.addSubview(scrollView)
        
        containerView = UIView()
        scrollView.addSubview(containerView)
        
        imageView = UIImageView(image: editImage)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        containerView.addSubview(imageView)
        
        shadowView = ZLClipShadowView()
        shadowView.isUserInteractionEnabled = false
        shadowView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.addSubview(shadowView)
        
        overlayView = ZLClipOverlayView()
        overlayView.isUserInteractionEnabled = false
        overlayView.isCircle = selectedRatio.isCircle
        view.addSubview(overlayView)
        
        bottomToolView = UIView()
        view.addSubview(bottomToolView)
        
        let color1 = UIColor.black.withAlphaComponent(0.15).cgColor
        let color2 = UIColor.black.withAlphaComponent(0.35).cgColor
        
        bottomShadowLayer = CAGradientLayer()
        bottomShadowLayer.colors = [color1, color2]
        bottomShadowLayer.locations = [0, 1]
        bottomToolView.layer.addSublayer(bottomShadowLayer)
        
        bottomToolLineView = UIView()
        bottomToolLineView.backgroundColor = .zl.rgba(240, 240, 240)
        bottomToolView.addSubview(bottomToolLineView)
        
        cancelBtn.setImage(.zl.getImage("zl_close"), for: .normal)
        cancelBtn.adjustsImageWhenHighlighted = false
        cancelBtn.enlargeInset = 20
        cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        bottomToolView.addSubview(cancelBtn)
        
        revertBtn.setTitleColor(.white, for: .normal)
        revertBtn.setTitle(localLanguageTextValue(.revert), for: .normal)
        revertBtn.enlargeInset = 20
        revertBtn.titleLabel?.font = ZLImageEditorLayout.bottomToolTitleFont
        revertBtn.addTarget(self, action: #selector(revertBtnClick), for: .touchUpInside)
        bottomToolView.addSubview(revertBtn)
        
        doneBtn.setImage(.zl.getImage("zl_right"), for: .normal)
        doneBtn.adjustsImageWhenHighlighted = false
        doneBtn.enlargeInset = 20
        doneBtn.addTarget(self, action: #selector(doneBtnClick), for: .touchUpInside)
        bottomToolView.addSubview(doneBtn)
        
        rotateBtn.setImage(.zl.getImage("zl_rotateimage"), for: .normal)
        rotateBtn.adjustsImageWhenHighlighted = false
        rotateBtn.enlargeInset = 20
        rotateBtn.addTarget(self, action: #selector(rotateBtnClick), for: .touchUpInside)
        view.addSubview(rotateBtn)
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = ZLClipImageViewController.clipRatioItemSize
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        clipRatioColView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        clipRatioColView.delegate = self
        clipRatioColView.dataSource = self
        clipRatioColView.backgroundColor = .clear
        clipRatioColView.isHidden = clipRatios.count <= 1
        clipRatioColView.showsHorizontalScrollIndicator = false
        view.addSubview(clipRatioColView)
        ZLImageClipRatioCell.zl.register(clipRatioColView)
        
        gridPanGes = UIPanGestureRecognizer(target: self, action: #selector(gridGesPanAction(_:)))
        gridPanGes.delegate = self
        view.addGestureRecognizer(gridPanGes)
        scrollView.panGestureRecognizer.require(toFail: gridPanGes)
        
        scrollView.alpha = 0
        overlayView.alpha = 0
        bottomToolView.alpha = 0
        rotateBtn.alpha = 0
    }
    
    func generateThumbnailImage() {
        let size: CGSize
        let ratio = (editImage.size.width / editImage.size.height)
        let fixLength: CGFloat = 100
        if ratio >= 1 {
            size = CGSize(width: fixLength * ratio, height: fixLength)
        } else {
            size = CGSize(width: fixLength, height: fixLength / ratio)
        }
        thumbnailImage = editImage.zl.resize(size)
    }
    
    /// 计算做大裁剪范围
    func calculateMaxClipFrame() -> CGRect {
        var insets = deviceSafeAreaInsets()
        insets.top += 20
        var rect = CGRect.zero
        rect.origin.x = 15
        rect.origin.y = insets.top
        rect.size.width = UIScreen.main.bounds.width - 15 * 2
        rect.size.height = UIScreen.main.bounds.height - insets.top - ZLClipImageViewController.bottomToolViewH - ZLClipImageViewController.clipRatioItemSize.height - 25
        return rect
    }
    
    func calculateClipRect() {
        if selectedRatio.whRatio == 0 {
            editRect = CGRect(origin: .zero, size: editImage.size)
        } else {
            let imageSize = editImage.size
            let imageWHRatio = imageSize.width / imageSize.height
            
            var w: CGFloat = 0, h: CGFloat = 0
            if selectedRatio.whRatio >= imageWHRatio {
                w = imageSize.width
                h = w / selectedRatio.whRatio
            } else {
                h = imageSize.height
                w = h * selectedRatio.whRatio
            }
            
            editRect = CGRect(x: (imageSize.width - w) / 2, y: (imageSize.height - h) / 2, width: w, height: h)
        }
    }
    
    func layoutInitialImage() {
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 1
        scrollView.zoomScale = 1
        
        let editSize = editRect.size
        scrollView.contentSize = editSize
        let maxClipRect = maxClipFrame
        
        containerView.frame = CGRect(origin: .zero, size: editImage.size)
        imageView.frame = containerView.bounds
        
        // editRect比例，计算editRect所占frame
        let editScale = min(maxClipRect.width / editSize.width, maxClipRect.height / editSize.height)
        let scaledSize = CGSize(width: floor(editSize.width * editScale), height: floor(editSize.height * editScale))
        
        var frame = CGRect.zero
        frame.size = scaledSize
        frame.origin.x = maxClipRect.minX + floor((maxClipRect.width - frame.width) / 2)
        frame.origin.y = maxClipRect.minY + floor((maxClipRect.height - frame.height) / 2)
        
        // 按照edit image进行计算最小缩放比例
        let originalScale = min(maxClipRect.width / editImage.size.width, maxClipRect.height / editImage.size.height)
        // 将 edit rect 相对 originalScale 进行缩放，缩放到图片未放大时候的clip rect
        let scaleEditSize = CGSize(width: editRect.width * originalScale, height: editRect.height * originalScale)
        // 计算缩放后的clip rect相对maxClipRect的比例
        let clipRectZoomScale = min(maxClipRect.width / scaleEditSize.width, maxClipRect.height / scaleEditSize.height)
        
        scrollView.minimumZoomScale = originalScale
        scrollView.maximumZoomScale = 10
        // 设置当前zoom scale
        let zoomScale = clipRectZoomScale * originalScale
        scrollView.zoomScale = zoomScale
        scrollView.contentSize = CGSize(width: editImage.size.width * zoomScale, height: editImage.size.height * zoomScale)
        
        changeClipBoxFrame(newFrame: frame)
        
        if (frame.size.width < scaledSize.width - CGFloat.ulpOfOne) || (frame.size.height < scaledSize.height - CGFloat.ulpOfOne) {
            var offset = CGPoint.zero
            offset.x = -floor((scrollView.frame.width - scaledSize.width) / 2)
            offset.y = -floor((scrollView.frame.height - scaledSize.height) / 2)
            scrollView.contentOffset = offset
        }
        
        // edit rect 相对 image size 的 偏移量
        let diffX = editRect.origin.x / editImage.size.width * scrollView.contentSize.width
        let diffY = editRect.origin.y / editImage.size.height * scrollView.contentSize.height
        scrollView.contentOffset = CGPoint(x: -scrollView.contentInset.left + diffX, y: -scrollView.contentInset.top + diffY)
    }
    
    func changeClipBoxFrame(newFrame: CGRect) {
        guard clipBoxFrame != newFrame else {
            return
        }
        if newFrame.width < CGFloat.ulpOfOne || newFrame.height < CGFloat.ulpOfOne {
            return
        }
        var frame = newFrame
        let originX = ceil(maxClipFrame.minX)
        let diffX = frame.minX - originX
        frame.origin.x = max(frame.minX, originX)
//        frame.origin.x = floor(max(frame.minX, originX))
        if diffX < -CGFloat.ulpOfOne {
            frame.size.width += diffX
        }
        let originY = ceil(maxClipFrame.minY)
        let diffY = frame.minY - originY
        frame.origin.y = max(frame.minY, originY)
//        frame.origin.y = floor(max(frame.minY, originY))
        if diffY < -CGFloat.ulpOfOne {
            frame.size.height += diffY
        }
        let maxW = maxClipFrame.width + maxClipFrame.minX - frame.minX
        frame.size.width = max(minClipSize.width, min(frame.width, maxW))
//        frame.size.width = floor(max(self.minClipSize.width, min(frame.width, maxW)))
        
        let maxH = maxClipFrame.height + maxClipFrame.minY - frame.minY
        frame.size.height = max(minClipSize.height, min(frame.height, maxH))
//        frame.size.height = floor(max(self.minClipSize.height, min(frame.height, maxH)))
        
        clipBoxFrame = frame
        shadowView.clearRect = frame
        overlayView.frame = frame.insetBy(dx: -ZLClipOverlayView.cornerLineWidth, dy: -ZLClipOverlayView.cornerLineWidth)
        
        scrollView.contentInset = UIEdgeInsets(top: frame.minY, left: frame.minX, bottom: scrollView.frame.maxY - frame.maxY, right: scrollView.frame.maxX - frame.maxX)
        
        let scale = max(frame.height / editImage.size.height, frame.width / editImage.size.width)
        scrollView.minimumZoomScale = scale
        
//        var size = self.scrollView.contentSize
//        size.width = floor(size.width)
//        size.height = floor(size.height)
//        self.scrollView.contentSize = size
        
        scrollView.zoomScale = scrollView.zoomScale
    }
    
    @objc func cancelBtnClick() {
        dismissAnimateFromRect = cancelClipAnimateFrame
        dismissAnimateImage = presentAnimateImage
        cancelClipBlock?()
        dismiss(animated: animateDismiss, completion: nil)
    }
    
    @objc func revertBtnClick() {
        angle = 0
        editImage = originalImage
        calculateClipRect()
        imageView.image = editImage
        layoutInitialImage()
        
        generateThumbnailImage()
        clipRatioColView.reloadData()
    }
    
    @objc func doneBtnClick() {
        let image = clipImage()
        dismissAnimateFromRect = clipBoxFrame
        dismissAnimateImage = image.clipImage
        clipDoneBlock?(angle, image.editRect, selectedRatio)
        dismiss(animated: animateDismiss, completion: nil)
    }
    
    @objc func rotateBtnClick() {
        guard !isRotating else {
            return
        }
        angle -= 90
        if angle == -360 {
            angle = 0
        }
        
        isRotating = true
        
        let animateImageView = UIImageView(image: editImage)
        animateImageView.contentMode = .scaleAspectFit
        animateImageView.clipsToBounds = true
        let originFrame = view.convert(containerView.frame, from: scrollView)
        animateImageView.frame = originFrame
        view.addSubview(animateImageView)
        
        if selectedRatio.whRatio == 0 || selectedRatio.whRatio == 1 {
            // 自由比例和1:1比例，进行edit rect转换
            
            // 将edit rect转换为相对edit image的rect
            let rect = convertClipRectToEditImageRect()
            // 旋转图片
            editImage = editImage.zl.rotate(orientation: .left)
            // 将rect进行旋转，转换到相对于旋转后的edit image的rect
            editRect = CGRect(x: rect.minY, y: editImage.size.height - rect.minX - rect.width, width: rect.height, height: rect.width)
        } else {
            // 其他比例的裁剪框，旋转后都重置edit rect
            
            // 旋转图片
            editImage = editImage.zl.rotate(orientation: .left)
            calculateClipRect()
        }
        
        imageView.image = editImage
        layoutInitialImage()
        
        let toFrame = view.convert(containerView.frame, from: scrollView)
        let transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        overlayView.alpha = 0
        containerView.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            animateImageView.transform = transform
            animateImageView.frame = toFrame
        }) { _ in
            animateImageView.removeFromSuperview()
            self.overlayView.alpha = 1
            self.containerView.alpha = 1
            self.isRotating = false
        }
        
        generateThumbnailImage()
        clipRatioColView.reloadData()
    }
    
    @objc func gridGesPanAction(_ pan: UIPanGestureRecognizer) {
        let point = pan.location(in: view)
        if pan.state == .began {
            startEditing()
            beginPanPoint = point
            clipOriginFrame = clipBoxFrame
            panEdge = calculatePanEdge(at: point)
        } else if pan.state == .changed {
            guard panEdge != .none else {
                return
            }
            updateClipBoxFrame(point: point)
        } else if pan.state == .cancelled || pan.state == .ended {
            panEdge = .none
            startTimer()
        }
    }
    
    func calculatePanEdge(at point: CGPoint) -> ZLClipImageViewController.ClipPanEdge {
        let frame = clipBoxFrame.insetBy(dx: -30, dy: -30)
        
        let cornerSize = CGSize(width: 60, height: 60)
        let topLeftRect = CGRect(origin: frame.origin, size: cornerSize)
        if topLeftRect.contains(point) {
            return .topLeft
        }
        
        let topRightRect = CGRect(origin: CGPoint(x: frame.maxX - cornerSize.width, y: frame.minY), size: cornerSize)
        if topRightRect.contains(point) {
            return .topRight
        }
        
        let bottomLeftRect = CGRect(origin: CGPoint(x: frame.minX, y: frame.maxY - cornerSize.height), size: cornerSize)
        if bottomLeftRect.contains(point) {
            return .bottomLeft
        }
        
        let bottomRightRect = CGRect(origin: CGPoint(x: frame.maxX - cornerSize.width, y: frame.maxY - cornerSize.height), size: cornerSize)
        if bottomRightRect.contains(point) {
            return .bottomRight
        }
        
        let topRect = CGRect(origin: frame.origin, size: CGSize(width: frame.width, height: cornerSize.height))
        if topRect.contains(point) {
            return .top
        }
        
        let bottomRect = CGRect(origin: CGPoint(x: frame.minX, y: frame.maxY - cornerSize.height), size: CGSize(width: frame.width, height: cornerSize.height))
        if bottomRect.contains(point) {
            return .bottom
        }
        
        let leftRect = CGRect(origin: frame.origin, size: CGSize(width: cornerSize.width, height: frame.height))
        if leftRect.contains(point) {
            return .left
        }
        
        let rightRect = CGRect(origin: CGPoint(x: frame.maxX - cornerSize.width, y: frame.minY), size: CGSize(width: cornerSize.width, height: frame.height))
        if rightRect.contains(point) {
            return .right
        }
        
        return .none
    }
    
    func updateClipBoxFrame(point: CGPoint) {
        var frame = clipBoxFrame
        let originFrame = clipOriginFrame
        
        var newPoint = point
        newPoint.x = max(maxClipFrame.minX, newPoint.x)
        newPoint.y = max(maxClipFrame.minY, newPoint.y)
        
        let diffX = ceil(newPoint.x - beginPanPoint.x)
        let diffY = ceil(newPoint.y - beginPanPoint.y)
        let ratio = selectedRatio.whRatio
        
        switch panEdge {
        case .left:
            frame.origin.x = originFrame.minX + diffX
            frame.size.width = originFrame.width - diffX
            if ratio != 0 {
                frame.size.height = originFrame.height - diffX / ratio
            }
            
        case .right:
            frame.size.width = originFrame.width + diffX
            if ratio != 0 {
                frame.size.height = originFrame.height + diffX / ratio
            }
            
        case .top:
            frame.origin.y = originFrame.minY + diffY
            frame.size.height = originFrame.height - diffY
            if ratio != 0 {
                frame.size.width = originFrame.width - diffY * ratio
            }
            
        case .bottom:
            frame.size.height = originFrame.height + diffY
            if ratio != 0 {
                frame.size.width = originFrame.width + diffY * ratio
            }
            
        case .topLeft:
            if ratio != 0 {
//                if abs(diffX / ratio) >= abs(diffY) {
                frame.origin.x = originFrame.minX + diffX
                frame.size.width = originFrame.width - diffX
                frame.origin.y = originFrame.minY + diffX / ratio
                frame.size.height = originFrame.height - diffX / ratio
//                } else {
//                    frame.origin.y = originFrame.minY + diffY
//                    frame.size.height = originFrame.height - diffY
//                    frame.origin.x = originFrame.minX + diffY * ratio
//                    frame.size.width = originFrame.width - diffY * ratio
//                }
            } else {
                frame.origin.x = originFrame.minX + diffX
                frame.size.width = originFrame.width - diffX
                frame.origin.y = originFrame.minY + diffY
                frame.size.height = originFrame.height - diffY
            }
            
        case .topRight:
            if ratio != 0 {
//                if abs(diffX / ratio) >= abs(diffY) {
                frame.size.width = originFrame.width + diffX
                frame.origin.y = originFrame.minY - diffX / ratio
                frame.size.height = originFrame.height + diffX / ratio
//                } else {
//                    frame.origin.y = originFrame.minY + diffY
//                    frame.size.height = originFrame.height - diffY
//                    frame.size.width = originFrame.width - diffY * ratio
//                }
            } else {
                frame.size.width = originFrame.width + diffX
                frame.origin.y = originFrame.minY + diffY
                frame.size.height = originFrame.height - diffY
            }
            
        case .bottomLeft:
            if ratio != 0 {
//                if abs(diffX / ratio) >= abs(diffY) {
                frame.origin.x = originFrame.minX + diffX
                frame.size.width = originFrame.width - diffX
                frame.size.height = originFrame.height - diffX / ratio
//                } else {
//                    frame.origin.x = originFrame.minX - diffY * ratio
//                    frame.size.width = originFrame.width + diffY * ratio
//                    frame.size.height = originFrame.height + diffY
//                }
            } else {
                frame.origin.x = originFrame.minX + diffX
                frame.size.width = originFrame.width - diffX
                frame.size.height = originFrame.height + diffY
            }
            
        case .bottomRight:
            if ratio != 0 {
//                if abs(diffX / ratio) >= abs(diffY) {
                frame.size.width = originFrame.width + diffX
                frame.size.height = originFrame.height + diffX / ratio
//                } else {
//                    frame.size.width += diffY * ratio
//                    frame.size.height += diffY
//                }
            } else {
                frame.size.width = originFrame.width + diffX
                frame.size.height = originFrame.height + diffY
            }
            
        default:
            break
        }
        
        let minSize: CGSize
        let maxSize: CGSize
        let maxClipFrame: CGRect
        if ratio != 0 {
            if ratio >= 1 {
                minSize = CGSize(width: minClipSize.height * ratio, height: minClipSize.height)
            } else {
                minSize = CGSize(width: minClipSize.width, height: minClipSize.width / ratio)
            }
            if ratio > self.maxClipFrame.width / self.maxClipFrame.height {
                maxSize = CGSize(width: self.maxClipFrame.width, height: self.maxClipFrame.width / ratio)
            } else {
                maxSize = CGSize(width: self.maxClipFrame.height * ratio, height: self.maxClipFrame.height)
            }
            maxClipFrame = CGRect(origin: CGPoint(x: self.maxClipFrame.minX + (self.maxClipFrame.width - maxSize.width) / 2, y: self.maxClipFrame.minY + (self.maxClipFrame.height - maxSize.height) / 2), size: maxSize)
        } else {
            minSize = minClipSize
            maxSize = self.maxClipFrame.size
            maxClipFrame = self.maxClipFrame
        }
        
        frame.size.width = min(maxSize.width, max(minSize.width, frame.size.width))
        frame.size.height = min(maxSize.height, max(minSize.height, frame.size.height))
        
        frame.origin.x = min(maxClipFrame.maxX - minSize.width, max(frame.origin.x, maxClipFrame.minX))
        frame.origin.y = min(maxClipFrame.maxY - minSize.height, max(frame.origin.y, maxClipFrame.minY))
        
        if panEdge == .topLeft || panEdge == .bottomLeft || panEdge == .left, frame.size.width <= minSize.width + CGFloat.ulpOfOne {
            frame.origin.x = originFrame.maxX - minSize.width
        }
        if panEdge == .topLeft || panEdge == .topRight || panEdge == .top, frame.size.height <= minSize.height + CGFloat.ulpOfOne {
            frame.origin.y = originFrame.maxY - minSize.height
        }
        
        changeClipBoxFrame(newFrame: frame)
    }
    
    func startEditing() {
        cleanTimer()
        shadowView.alpha = 0
        overlayView.isEditing = true
        if rotateBtn.alpha != 0 {
            rotateBtn.layer.removeAllAnimations()
            clipRatioColView.layer.removeAllAnimations()
            UIView.animate(withDuration: 0.2) {
                self.rotateBtn.alpha = 0
                self.clipRatioColView.alpha = 0
            }
        }
    }
    
    @objc func endEditing() {
        overlayView.isEditing = false
        moveClipContentToCenter()
    }
    
    func startTimer() {
        cleanTimer()
        resetTimer = Timer.scheduledTimer(timeInterval: 0.8, target: ZLWeakProxy(target: self), selector: #selector(endEditing), userInfo: nil, repeats: false)
        RunLoop.current.add(resetTimer!, forMode: .common)
    }
    
    func cleanTimer() {
        resetTimer?.invalidate()
        resetTimer = nil
    }
    
    func moveClipContentToCenter() {
        let maxClipRect = maxClipFrame
        var clipRect = clipBoxFrame
        
        if clipRect.width < CGFloat.ulpOfOne || clipRect.height < CGFloat.ulpOfOne {
            return
        }
        
        let scale = min(maxClipRect.width / clipRect.width, maxClipRect.height / clipRect.height)
        
        let focusPoint = CGPoint(x: clipRect.midX, y: clipRect.midY)
        let midPoint = CGPoint(x: maxClipRect.midX, y: maxClipRect.midY)
        
        clipRect.size.width = ceil(clipRect.width * scale)
        clipRect.size.height = ceil(clipRect.height * scale)
        clipRect.origin.x = maxClipRect.minX + ceil((maxClipRect.width - clipRect.width) / 2)
        clipRect.origin.y = maxClipRect.minY + ceil((maxClipRect.height - clipRect.height) / 2)
        
        var contentTargetPoint = CGPoint.zero
        contentTargetPoint.x = (focusPoint.x + scrollView.contentOffset.x) * scale
        contentTargetPoint.y = (focusPoint.y + scrollView.contentOffset.y) * scale
        
        var offset = CGPoint(x: contentTargetPoint.x - midPoint.x, y: contentTargetPoint.y - midPoint.y)
        offset.x = max(-clipRect.minX, offset.x)
        offset.y = max(-clipRect.minY, offset.y)
        UIView.animate(withDuration: 0.3) {
            if scale < 1 - CGFloat.ulpOfOne || scale > 1 + CGFloat.ulpOfOne {
                self.scrollView.zoomScale *= scale
                self.scrollView.zoomScale = min(self.scrollView.maximumZoomScale, self.scrollView.zoomScale)
            }

            if self.scrollView.zoomScale < self.scrollView.maximumZoomScale - CGFloat.ulpOfOne {
                offset.x = min(self.scrollView.contentSize.width - clipRect.maxX, offset.x)
                offset.y = min(self.scrollView.contentSize.height - clipRect.maxY, offset.y)
                self.scrollView.contentOffset = offset
            }
            self.rotateBtn.alpha = 1
            self.clipRatioColView.alpha = 1
            self.shadowView.alpha = 1
            self.changeClipBoxFrame(newFrame: clipRect)
        }
    }
    
    func clipImage() -> (clipImage: UIImage, editRect: CGRect) {
        let frame = convertClipRectToEditImageRect()
        let clipImage = editImage.zl.clipImage(angle: 0, editRect: frame, isCircle: selectedRatio.isCircle) ?? editImage
        return (clipImage, frame)
    }
    
    func convertClipRectToEditImageRect() -> CGRect {
        let imageSize = editImage.size
        let contentSize = scrollView.contentSize
        let offset = scrollView.contentOffset
        let insets = scrollView.contentInset
        
        var frame = CGRect.zero
        frame.origin.x = floor((offset.x + insets.left) * (imageSize.width / contentSize.width))
        frame.origin.x = max(0, frame.origin.x)
        
        frame.origin.y = floor((offset.y + insets.top) * (imageSize.height / contentSize.height))
        frame.origin.y = max(0, frame.origin.y)
        
        frame.size.width = ceil(clipBoxFrame.width * (imageSize.width / contentSize.width))
        frame.size.width = min(imageSize.width, frame.width)
        
        frame.size.height = ceil(clipBoxFrame.height * (imageSize.height / contentSize.height))
        frame.size.height = min(imageSize.height, frame.height)
        
        return frame
    }
}

extension ZLClipImageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == gridPanGes else {
            return true
        }
        let point = gestureRecognizer.location(in: view)
        let frame = overlayView.frame
        let innerFrame = frame.insetBy(dx: 22, dy: 22)
        let outerFrame = frame.insetBy(dx: -22, dy: -22)
        
        if innerFrame.contains(point) || !outerFrame.contains(point) {
            return false
        }
        return true
    }
}

extension ZLClipImageViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return clipRatios.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ZLImageClipRatioCell.zl.identifier, for: indexPath) as! ZLImageClipRatioCell
        
        let ratio = clipRatios[indexPath.row]
        cell.configureCell(image: thumbnailImage ?? editImage, ratio: ratio)
        
        if ratio == selectedRatio {
            cell.titleLabel.textColor = .zl.toolTitleTintColor
        } else {
            cell.titleLabel.textColor = .zl.toolTitleNormalColor
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let ratio = clipRatios[indexPath.row]
        guard ratio != selectedRatio else {
            return
        }
        selectedRatio = ratio
        clipRatioColView.reloadData()
        clipRatioColView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        calculateClipRect()
        layoutInitialImage()
    }
}

extension ZLClipImageViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return containerView
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        startEditing()
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else {
            return
        }
        startEditing()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else {
            return
        }
        startTimer()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView == self.scrollView else {
            return
        }
        if !decelerate {
            startTimer()
        }
    }
}

extension ZLClipImageViewController: UIViewControllerTransitioningDelegate {
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ZLClipImageDismissAnimatedTransition()
    }
}

// MARK: 裁剪比例cell

class ZLImageClipRatioCell: UICollectionViewCell {
    var imageView: UIImageView!
    
    var titleLabel: UILabel!
    
    var image: UIImage?
    
    var ratio: ZLImageClipRatio!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let ratio = ratio, let image = image else {
            return
        }
        
        let center = imageView.center
        var w: CGFloat = 0, h: CGFloat = 0
        
        let imageMaxW = bounds.width - 10
        if ratio.whRatio == 0 {
            let maxSide = max(image.size.width, image.size.height)
            w = imageMaxW * image.size.width / maxSide
            h = imageMaxW * image.size.height / maxSide
        } else {
            if ratio.whRatio >= 1 {
                w = imageMaxW
                h = w / ratio.whRatio
            } else {
                h = imageMaxW
                w = h * ratio.whRatio
            }
        }
        if ratio.isCircle {
            imageView.layer.cornerRadius = w / 2
        } else {
            imageView.layer.cornerRadius = 3
        }
        imageView.frame = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
    }
    
    func setupUI() {
        imageView = UIImageView(frame: CGRect(x: 8, y: 5, width: bounds.width - 16, height: bounds.width - 16))
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 3
        imageView.layer.masksToBounds = true
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        
        titleLabel = UILabel(frame: CGRect(x: 0, y: bounds.height - 15, width: bounds.width, height: 12))
        titleLabel.font = UIFont.systemFont(ofSize: 12)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.withAlphaComponent(0.3).cgColor
        titleLabel.layer.shadowOffset = .zero
        titleLabel.layer.shadowOpacity = 1
        contentView.addSubview(titleLabel)
    }
    
    func configureCell(image: UIImage, ratio: ZLImageClipRatio) {
        imageView.image = image
        titleLabel.text = ratio.title
        self.image = image
        self.ratio = ratio
        
        setNeedsLayout()
    }
}

class ZLClipShadowView: UIView {
    var clearRect: CGRect = .zero {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        UIColor(white: 0, alpha: 0.7).setFill()
        UIRectFill(rect)
        let cr = clearRect.intersection(rect)
        UIColor.clear.setFill()
        UIRectFill(cr)
    }
}

// MARK: 裁剪网格视图

class ZLClipOverlayView: UIView {
    static let cornerLineWidth: CGFloat = 3
    
    var cornerBoldLines: [UIView] = []
    
    var velLines: [UIView] = []
    
    var horLines: [UIView] = []
    
    var isCircle = false {
        didSet {
            guard oldValue != isCircle else {
                return
            }
            setNeedsDisplay()
        }
    }
    
    var isEditing = false {
        didSet {
            guard isCircle else {
                return
            }
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false
        // 两种方法实现裁剪框，drawrect动画效果 更好一点
//        func line(_ isCorner: Bool) -> UIView {
//            let line = UIView()
//            line.backgroundColor = .white
//            line.layer.shadowColor  = UIColor.black.cgColor
//            if !isCorner {
//                line.layer.shadowOffset = .zero
//                line.layer.shadowRadius = 1.5
//                line.layer.shadowOpacity = 0.8
//            }
//            self.addSubview(line)
//            return line
//        }
//
//        (0..<8).forEach { (_) in
//            self.cornerBoldLines.append(line(true))
//        }
//
//        (0..<4).forEach { (_) in
//            self.velLines.append(line(false))
//            self.horLines.append(line(false))
//        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
//        let borderLineLength: CGFloat = 20
//        let borderLineWidth: CGFloat = ZLClipOverlayView.cornerLineWidth
//        for (i, line) in self.cornerBoldLines.enumerated() {
//            switch i {
//            case 0:
//                // 左上 hor
//                line.frame = CGRect(x: -borderLineWidth, y: -borderLineWidth, width: borderLineLength, height: borderLineWidth)
//            case 1:
//                // 左上 vel
//                line.frame = CGRect(x: -borderLineWidth, y: -borderLineWidth, width: borderLineWidth, height: borderLineLength)
//            case 2:
//                // 右上 hor
//                line.frame = CGRect(x: self.bounds.width-borderLineLength+borderLineWidth, y: -borderLineWidth, width: borderLineLength, height: borderLineWidth)
//            case 3:
//                // 右上 vel
//                line.frame = CGRect(x: self.bounds.width, y: -borderLineWidth, width: borderLineWidth, height: borderLineLength)
//            case 4:
//                // 左下 hor
//                line.frame = CGRect(x: -borderLineWidth, y: self.bounds.height, width: borderLineLength, height: borderLineWidth)
//            case 5:
//                // 左下 vel
//                line.frame = CGRect(x: -borderLineWidth, y: self.bounds.height-borderLineLength+borderLineWidth, width: borderLineWidth, height: borderLineLength)
//            case 6:
//                // 右下 hor
//                line.frame = CGRect(x: self.bounds.width-borderLineLength+borderLineWidth, y: self.bounds.height, width: borderLineLength, height: borderLineWidth)
//            case 7:
//                line.frame = CGRect(x: self.bounds.width, y: self.bounds.height-borderLineLength+borderLineWidth, width: borderLineWidth, height: borderLineLength)
//
//            default:
//                break
//            }
//        }
//
//        let normalLineWidth: CGFloat = 1
//        var x: CGFloat = 0
//        var y: CGFloat = -1
//        // 横线
//        for (index, line) in self.horLines.enumerated() {
//            if index == 0 || index == 3 {
//                x = borderLineLength-borderLineWidth
//            } else  {
//                x = 0
//            }
//            line.frame = CGRect(x: x, y: y, width: self.bounds.width - x * 2, height: normalLineWidth)
//            y += (self.bounds.height + 1) / 3
//        }
//
//        x = -1
//        y = 0
//        // 竖线
//        for (index, line) in self.velLines.enumerated() {
//            if index == 0 || index == 3 {
//                y = borderLineLength-borderLineWidth
//            } else  {
//                y = 0
//            }
//            line.frame = CGRect(x: x, y: y, width: normalLineWidth, height: self.bounds.height - y * 2)
//            x += (self.bounds.width + 1) / 3
//        }
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        
        context?.setStrokeColor(UIColor.white.cgColor)
        context?.setLineWidth(1)
        context?.beginPath()
        
        if isCircle {
            let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
            let radius = rect.width / 2 - ZLClipOverlayView.cornerLineWidth
            if !isEditing {
                // top left
                context?.move(to: CGPoint(x: ZLClipOverlayView.cornerLineWidth, y: ZLClipOverlayView.cornerLineWidth))
                context?.addLine(to: CGPoint(x: rect.width / 2, y: rect.origin.y + 3))
                context?.addArc(center: center, radius: radius, startAngle: .pi * 1.5, endAngle: .pi, clockwise: true)
                context?.closePath()
                
                // top right
                context?.move(to: CGPoint(x: rect.width - ZLClipOverlayView.cornerLineWidth, y: ZLClipOverlayView.cornerLineWidth))
                context?.addLine(to: CGPoint(x: rect.width - ZLClipOverlayView.cornerLineWidth, y: rect.height / 2))
                context?.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 1.5, clockwise: true)
                context?.closePath()
                
                // bottom left
                context?.move(to: CGPoint(x: ZLClipOverlayView.cornerLineWidth, y: rect.height - ZLClipOverlayView.cornerLineWidth))
                context?.addLine(to: CGPoint(x: ZLClipOverlayView.cornerLineWidth, y: rect.height / 2))
                context?.addArc(center: center, radius: radius, startAngle: .pi, endAngle: .pi / 2, clockwise: true)
                context?.closePath()
                
                // bottom right
                context?.move(to: CGPoint(x: rect.width - ZLClipOverlayView.cornerLineWidth, y: rect.height - ZLClipOverlayView.cornerLineWidth))
                context?.addLine(to: CGPoint(x: rect.width / 2, y: rect.height - ZLClipOverlayView.cornerLineWidth))
                context?.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: 0, clockwise: true)
                context?.closePath()
                
                context?.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
                context?.fillPath()
            }
            
            context?.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        }
        
        let circleDiff: CGFloat = (3 - 2 * sqrt(2)) * (rect.width - 2 * ZLClipOverlayView.cornerLineWidth) / 6
        
        var dw: CGFloat = 3
        for i in 0..<4 {
            let isInnerLine = isCircle && 1...2 ~= i
            context?.move(to: CGPoint(x: rect.origin.x + dw, y: ZLClipOverlayView.cornerLineWidth + (isInnerLine ? circleDiff : 0)))
            context?.addLine(to: CGPoint(x: rect.origin.x + dw, y: rect.height - ZLClipOverlayView.cornerLineWidth - (isInnerLine ? circleDiff : 0)))
            dw += (rect.size.width - 6) / 3
        }

        var dh: CGFloat = 3
        for i in 0..<4 {
            let isInnerLine = isCircle && 1...2 ~= i
            context?.move(to: CGPoint(x: ZLClipOverlayView.cornerLineWidth + (isInnerLine ? circleDiff : 0), y: rect.origin.y + dh))
            context?.addLine(to: CGPoint(x: rect.width - ZLClipOverlayView.cornerLineWidth - (isInnerLine ? circleDiff : 0), y: rect.origin.y + dh))
            dh += (rect.size.height - 6) / 3
        }

        context?.strokePath()

        context?.setLineWidth(ZLClipOverlayView.cornerLineWidth)

        let boldLineLength: CGFloat = 20
        // 左上
        context?.move(to: CGPoint(x: 0, y: 1.5))
        context?.addLine(to: CGPoint(x: boldLineLength, y: 1.5))

        context?.move(to: CGPoint(x: 1.5, y: 0))
        context?.addLine(to: CGPoint(x: 1.5, y: boldLineLength))

        // 右上
        context?.move(to: CGPoint(x: rect.width - boldLineLength, y: 1.5))
        context?.addLine(to: CGPoint(x: rect.width, y: 1.5))

        context?.move(to: CGPoint(x: rect.width - 1.5, y: 0))
        context?.addLine(to: CGPoint(x: rect.width - 1.5, y: boldLineLength))

        // 左下
        context?.move(to: CGPoint(x: 1.5, y: rect.height - boldLineLength))
        context?.addLine(to: CGPoint(x: 1.5, y: rect.height))

        context?.move(to: CGPoint(x: 0, y: rect.height - 1.5))
        context?.addLine(to: CGPoint(x: boldLineLength, y: rect.height - 1.5))

        // 右下
        context?.move(to: CGPoint(x: rect.width - boldLineLength, y: rect.height - 1.5))
        context?.addLine(to: CGPoint(x: rect.width, y: rect.height - 1.5))

        context?.move(to: CGPoint(x: rect.width - 1.5, y: rect.height - boldLineLength))
        context?.addLine(to: CGPoint(x: rect.width - 1.5, y: rect.height))

        context?.strokePath()

        context?.setShadow(offset: CGSize(width: 1, height: 1), blur: 0)
    }
}
