//
//  XHPreviewImageOrVideoViewController.swift
//  XCamera
//
//  Created by jing_mac on 2020/5/26.
//  Copyright © 2020 xhey. All rights reserved.
//  二次封装图片浏览器

import UIKit

typealias XHPhotoBrowserAnimationHandler = (Int) -> (UIView?, UIImage?, CGRect)

class XHPreviewImageOrVideoViewController: JXPhotoBrowser {
    
    /// 数据源是一个数组，可以放任何数据，但是需要在设置图片的地方添加兼容方式
    var dataSource: [XHPreviewImageOrVideoModel] = []
    
    /// 当前播放的index
    var currentPlayIndex: Int?
    
    // V2.9.125版本添加，解决视频播放点击重试没有反应的bug
    weak var currentContainerView: UIView?
    var currentVideoUrl: URL?
    var currentCoverURLStr: String?
    weak var currentCoverImage: UIImage?
    
    /// 展示动画的回调，需要设置才会有动画效果
    var animationHandler: XHPhotoBrowserAnimationHandler?
    
    open var player: ZFPlayerController?
    open var controlView: XHVideoCustomControlView?
    
    // 隐藏状态栏
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    deinit {
        XHLogDebug("deinit - [图片或视频预览调试] - XHPreviewImageOrVideoViewController")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 实例方法
    init(dataSource: [XHPreviewImageOrVideoModel], currentIndex: Int, animation: XHPhotoBrowserAnimationHandler?) {
        super.init()
        self.dataSource = dataSource
        self.pageIndex = currentIndex
        self.animationHandler = animation
        
        self.cellClassAtIndex = { [weak self] index in
            if let type = self?.setCellClass(at: index) {
                return type
            }
            return XHPreviewImageCell.self
        }
        
        self.numberOfItems = { [weak self] in
            return self?.dataSource.count ?? 0
        }
        
        self.reloadCellAtIndex = { [weak self] context in
            self?.configData(context)
        }
        
        // 更丝滑的Zoom动画
        self.transitionAnimator = JXPhotoBrowserSmoothZoomAnimator(transitionViewAndFrame: { [weak self] (index, destinationView) -> JXPhotoBrowserSmoothZoomAnimator.TransitionViewAndFrame? in
            
            if let handler = self?.animationHandler {
                let result = handler(index)
                if let currentView = result.0 {
                    let transitionView = UIImageView(image: result.1, contentMode: .scaleAspectFill, clipsToBounds: true)
                    let thumbnailFrame = currentView.convert(result.2, to: destinationView)
                    return (transitionView, thumbnailFrame)
                }
            }
            return nil
        })
        
        /// Cell将显示
        self.cellWillAppear = {[weak self] (cell, index) in
            self?.cellWillAppear(cell, index: index)
        }
        
        /// Cell已显示
        self.cellDidAppear = {[weak self] (cell, index) in
            self?.cellDidAppear(cell, index: index)
        }
        
        /// Cell将消失
        self.cellWillDisappear = {[weak self] (cell, index) in
            self?.cellWillDisappear(cell, index: index)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.player?.isViewControllerDisappear = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.player?.isViewControllerDisappear = true
        self.player?.currentPlayerManager.pause()
        
        // 退出全屏
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.allowOrentitaionRotation = false
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        
        if self.player?.isFullScreen == true {
            return .landscape
        }
        return .portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func dismiss() {
        self.stopPlayVideo()
        super.dismiss()
    }
    
    // 设置cell的类型
    func setCellClass(at index: Int) -> JXPhotoBrowserCell.Type {
        
        let currentModel = self.dataSource[index]
        if currentModel.type == .image {
            return XHPreviewImageCell.self
        } else {
            return XHPreviewVideoCell.self
        }
    }
    
    /// Cell将显示
    func cellWillAppear(_ cell: JXPhotoBrowserCell, index: Int) {
        
        XHLogDebug("[图片或视频预览调试] - Cell将显示 - index:[\(index)]")
        if self.dataSource.count == 0 || index >= self.dataSource.count {
            return
        }
        
        if let videoIndex = self.currentPlayIndex, videoIndex == index {
            return
        }
        
        let model = self.dataSource[index]
        if let videoCell = cell as? XHPreviewVideoCell {
            if let tempStr = model.videoUrlStr?.urlPercentEncoding,
               let url = URL(string: tempStr), let proxyURL = XHKTVHTTPCacheManager.getProxyURL(url) {
                
                self.addPlayer(containerView: videoCell.imageView, videoUrl: proxyURL, playIndex: index, coverURLStr: model.placeholderUrlStr, coverImage: model.placeholderImage)
            } else if let filePath = model.videoPath{
                
                self.addPlayer(containerView: videoCell.imageView, videoUrl: URL(fileURLWithPath: filePath), playIndex: index, coverURLStr: model.placeholderUrlStr, coverImage: model.placeholderImage)
            }
        } else {
            self.stopPlayVideo()
        }
    }
    
    func cellDidAppear(_ cell: JXPhotoBrowserCell, index: Int) {
        XHLogDebug("[图片或视频预览调试] - Cell已显示 - index:[\(index)]")
    }
    
    /// Cell将消失
    func cellWillDisappear(_ cell: JXPhotoBrowserCell, index: Int) {
        
        XHLogDebug("[图片或视频预览调试] - Cell将消失 - index:[\(index)]")
        if let playIndex = self.currentPlayIndex, playIndex == index {
            self.stopPlayVideo()
        }
    }
    
    // MARK: - 填充数据
    func configData(_ context: ReloadCellContext) {
        
        XHLogDebug("[图片或视频预览调试] - 填充数据 - index:[\(context.index)] - currentIndex:[\(context.currentIndex)]")
        if self.dataSource.count == 0 || context.index >= self.dataSource.count {
            return
        }
        
        let currentModel = self.dataSource[context.index]
        
        if currentModel.type == .image {
            // 图片
            if let cell = context.cell as? XHPreviewImageCell {
                if let image = currentModel.image {
                    cell.imageView.image = image
                } else if let imageUrl = currentModel.imageUrlStr {
                    
                    cell.imageView.setImage(with: imageUrl, defaultImage: currentModel.placeholderImage, complete: { [weak cell] (image, url) in
                        cell?.setNeedsLayout()
                    })
                }
            }
        } else {
            // 视频
            if let cell = context.cell as? XHPreviewVideoCell {
                cell.imageView.image = currentModel.image
            }
        }
    }
    
    // 关闭视频播放
    func closeVideoAction() {
        self.dismiss()
    }
    
    // 中心的播放按钮的点击方法
    func centerPlayButtonAction() {
        
    }
    
    // 重试按钮的点击
    func retryButtonAction() {
        // self.player?.currentPlayerManager.reloadPlayer()
        
        // V2.9.125版本添加，解决视频播放点击重试没有反应的bug
        if let containerView = self.currentContainerView, let videoUrl = self.currentVideoUrl, let playIndex = self.currentPlayIndex {
            
            XHLogDebug("deinit - [图片或视频预览调试] - 点击重试按钮，开始重试播放")
            self.addPlayer(containerView: containerView, videoUrl: videoUrl, playIndex: playIndex, coverURLStr: self.currentCoverURLStr, coverImage: self.currentCoverImage)
        } else {
            XHLogDebug("deinit - [图片或视频预览调试] - 点击重试按钮，没有找到播放资源，不能播放")
        }
    }
    
    // 添加播放器
    func addPlayer(containerView: UIView, videoUrl: URL, playIndex: Int, coverURLStr: String?, coverImage: UIImage?) {
        
        self.stopPlayVideo()
        XHLogDebug("[图片或视频预览调试] - addPlayer - videoUrl:[\(videoUrl)]")
        
        controlView = XHVideoCustomControlView()
        controlView?.closeHandler = { [weak self] in
            self?.closeVideoAction()
        }
        
        // 重试按钮的点击
        controlView?.retryHandler = { [weak self] in
            self?.retryButtonAction()
        }
        
        controlView?.centerPlayHandler = { [weak self] in
            self?.centerPlayButtonAction()
        }
        
//        let playerManager = ZFAVPlayerManager()
        let playerManager = ZFIJKPlayerManager()
        
        /// 播放器相关
        self.player = ZFPlayerController(playerManager: playerManager, containerView: containerView)
        /// AudioSession由外面控制
//        self.player?.customAudioSession = true
        self.player?.controlView = self.controlView!
        /// 设置退到后台继续播放
        self.player?.pauseWhenAppResignActive = true
        
        /// 0.4是消失40%时候
        self.player?.playerDisapperaPercent = 0.4;
        /// 0.6是出现60%时候
        self.player?.playerApperaPercent = 0.6;
        /// 移动网络依然自动播放
        self.player?.isWWANAutoPlay = true;
        /// 续播
        self.player?.resumePlayRecord = false;
        /// 禁止掉滑动手势
        self.player?.disableGestureTypes = .pan;
        
        // 不允许屏幕旋转
        self.player?.allowOrentitaionRotation = true
        
        // 横屏模式
        self.player?.orientationObserver.fullScreenMode = .landscape
        
        self.player?.orientationWillChange = { (player, isFullScreen) in
            if let delegate = UIApplication.shared.delegate as? AppDelegate {
                delegate.allowOrentitaionRotation = isFullScreen
            }
        }
        
        self.player?.playerDidToEnd = {[weak self] (asset) in
            self?.player?.seek(toTime: 0, completionHandler: nil)
            self?.player?.currentPlayerManager.pause()
        }
        
        playerManager.assetURL = videoUrl
        self.controlView?.showTitle(coverURLString: coverURLStr ?? "", coverImage: coverImage)
        self.currentPlayIndex = playIndex
        
        self.currentContainerView = containerView
        self.currentVideoUrl = videoUrl
        self.currentCoverURLStr = coverURLStr
        self.currentCoverImage = coverImage
    }
    
    // 停止播放视频
    func stopPlayVideo() {
        XHLogDebug("[图片或视频预览调试] - 停止播放视频，清空记录的播放视频的信息 - currentPlayIndex:[\(currentPlayIndex ?? -1)]")
        self.player?.stopCurrentPlayingView()
        self.currentPlayIndex = nil
        
        self.currentContainerView = nil
        self.currentVideoUrl = nil
        self.currentCoverURLStr = nil
        self.currentCoverImage = nil
    }
}

