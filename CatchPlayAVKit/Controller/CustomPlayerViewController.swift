//
//  CustomPlayerViewController.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import AVKit

class CustomPlayerViewController: UIViewController {
    
    // MARK: - properties
    
    private(set) lazy var networkManager: NetworkManager = {
        return NetworkManager()
    }()
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    private var timeObserverToken: Any?
    
    private var bufferTimer: BufferTimer?
    
    private var autoHideTimer: BufferTimer?
    
    var currentTime: CMTime = .zero {
        didSet {
            if currentTime != oldValue {
                playerControlView.updateProgress(currentTime: Float(CMTimeGetSeconds(currentTime)), duration: Float(CMTimeGetSeconds(duration)))
            }
        }
    }
    
    var duration: CMTime = .zero {
        didSet {
            if duration != oldValue, duration != .zero {
                playerControlView.updateProgress(currentTime: Float(CMTimeGetSeconds(currentTime)), duration: Float(CMTimeGetSeconds(duration)))
            }
        }
    }
    
    var playSpeedRate: Float = 1 {
        didSet {
            if playSpeedRate != oldValue {
                setControlViewSpeedButton(playSpeedRate:playSpeedRate)
            }
        }
    }
    
    private var audioSlectedIndex: Int?
    private var subTitleSlectedIndex: Int?
    
    private lazy var videoPlayHelper: VideoPlayHelper = {
        let videoPlayHelper = VideoPlayHelper()
        videoPlayHelper.delegate = self
        return videoPlayHelper
    }()
    
    // MARK: - UI properties
    
    private lazy var playerView: PlayerView = {
        let playerView = PlayerView()
        playerView.delegate = self
        playerView.player = videoPlayHelper.queuePlayer
        return playerView
    }()
    
    private lazy var playerControlView: PlayerControlView = {
        let playerControlView = PlayerControlView()
        playerControlView.delegate = self
        return playerControlView
    }()
    
    private lazy var screenLockedView: ScreenLockedView = {
        let screenLockedView = ScreenLockedView()
        screenLockedView.delegate = self
        return screenLockedView
    }()
    
    var noNetworkAlert: UIAlertController?
    
    // MARK: - life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setPlayContent()
        setPlayerView()
        setPlayerControlView()
        checkNetwork(connectionHandler: connectionHandler,
                     noConnectionHandler: noConnectionHandler)
        observeScreenBrightness()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - player method
    
    /// Place AVPlayerItem in AVQueuePlayer, assign to AVPlayer
    private func setPlayContent() {
        videoPlayHelper.configQueuePlayer(Constant.sourceOne)
        videoPlayHelper.insertPlayerItem(Constant.sourceTwo)
    }
    
    /// Pause the player and change UI state.
    private func cancelPlay(player: AVPlayer) {
        player.pause()
        videoPlayHelper.playerState = .pause
        bufferTimer?.cancel()
        cancelAutoHidePlayerControl()
    }
    
    /// Set a timer to check if AVPlayerItem.isPlaybackLikelyToKeepUp. If yes, then will play, but if not, will recall this method again.
    private func bufferingForSeconds(playerItem: AVPlayerItem, player: AVPlayer) {
        guard playerItem.status == .readyToPlay,
              videoPlayHelper.playerState != .failed else { return }
        cancelPlay(player: player)
        videoPlayHelper.playerState = .buffering
        bufferTimer = BufferTimer(interval: 0, delaySecs: 3.0, repeats: false, action: { [weak self] _ in
            guard let self = self else { return }
            if playerItem.isPlaybackLikelyToKeepUp {
                self.playPlayer()
            } else {
                self.bufferingForSeconds(playerItem: playerItem, player: player)
            }
        })
        bufferTimer?.start()
    }
    
    // MARK: - update UI method
    
    /// Start observe currentTime.
    private func addPeriodicTimeObserver() {
        guard let player = playerView.player as? AVQueuePlayer else { return }
        // Invoke callback every half second
        let interval = CMTime(seconds: 0.5,
                              preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        // Add time observer. Invoke closure on the main queue.
        timeObserverToken =
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            guard let self = self else { return }
            // update player transport UI
            self.currentTime = time
        }
    }
    
    /// Stop observe currentTime.
    private func removePeriodicTimeObserver() {
        guard let player = playerView.player as? AVQueuePlayer else { return }
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    /// Hide player control.
    /// - Parameter animateDuration: The duration player control view fades out.
    private func hidePlayerControl(animateDuration: TimeInterval = 0.4) {
        UIView.animate(withDuration: animateDuration, delay: 0, options: .curveEaseIn) {
            self.playerControlView.alpha = 0
        }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            self.playerControlView.isHidden = true
        }
    }
    
    /// Show player control.
    /// - Parameter animateDuration: The duration player control view fades in.
    private func showPlayerControl(animateDuration: TimeInterval = 0.4) {
        self.playerControlView.isHidden = false
        UIView.animate(withDuration: animateDuration, delay: 0, options: .curveEaseOut) {
            self.playerControlView.alpha = 1
        }
    }
    
    private func autoHidePlayerControl() {
        autoHideTimer?.cancel()
        autoHideTimer = BufferTimer(interval: 0, delaySecs: 3, repeats: false, action: { [weak self] _ in
            guard let self = self else { return }
            self.hidePlayerControl()
        })
        autoHideTimer?.start()
    }
    
    private func cancelAutoHidePlayerControl() {
        autoHideTimer?.cancel()
    }
    
    /// Display screenLockedView.
    private func addScreenLockedView() {
        view.addSubview(screenLockedView)
        screenLockedView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            screenLockedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            screenLockedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            screenLockedView.topAnchor.constraint(equalTo: view.topAnchor),
            screenLockedView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    /// Remove screenLockedView.
    private func removeScreenLockedView() {
        screenLockedView.removeFromSuperview()
    }
    
    /// Display screen locked panel.
    /// - Parameters:
    ///   - delay: Show screen locked view after delay seconds.
    ///   - seconds: The duration screen locked view keep visible on screen.
    private func showScreenLockedPanel(delay: TimeInterval = 0, for seconds: TimeInterval = 3) {
        screenLockedView.uiPropertiesIsHidden(isHidden: false)
        
        Timer.scheduledTimer(withTimeInterval: delay + seconds + 0.6, repeats: false) {[weak self] _ in
            guard let self = self else { return }
            self.screenLockedView.uiPropertiesIsHidden(isHidden: true)
        }
    }
    
    /// Add observer UIScreen.brightnessDidChangeNotification
    private func observeScreenBrightness() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateBrightnessSlider), name: UIScreen.brightnessDidChangeNotification, object: nil)
    }
    
    /// Update brightness slider value when brightness did change.
    @objc func updateBrightnessSlider() {
        playerControlView.updateBrightnessSliderValue()
    }
    
    /// Toggle the slelcted button be orange.
    private func setControlViewSpeedButton(playSpeedRate:Float) {
        var button: UIButton? {
            switch playSpeedRate {
            case 0.5:
                return playerControlView.slowSpeedButton
            case 1:
                return playerControlView.normalSpeedButton
            case 1.5:
                return playerControlView.fastSpeedButton
            default:
                return nil
            }
        }
        playerControlView.setSpeedButtonColor(selecedSpeedButton: button)
    }
    
    // MARK: - methods use with delegate methods
    
    /// Pause the player, show player control, and make play button be play image.
    private func pausePlayer() {
        videoPlayHelper.queuePlayer?.pause()
        videoPlayHelper.playerState = .pause
        cancelAutoHidePlayerControl()
        removePeriodicTimeObserver()
        playerControlView.togglePlayButtonImage(.play)
    }
    
    /// Play the player, auto hide player control, and make play button be pause image.
    private func playPlayer() {
        videoPlayHelper.queuePlayer?.play()
        videoPlayHelper.playerState = .playing
        playerView.player?.rate = playSpeedRate
        autoHidePlayerControl()
        addPeriodicTimeObserver()
        playerControlView.togglePlayButtonImage(.pause)
    }
    
    private func togglePlay() {
        switch videoPlayHelper.playerState {
            
        case .buffering:
            playPlayer()
            
        case .unknow, .pause, .readyToPlay:
            playPlayer()
            
        case .playing:
            pausePlayer()
            
        default:
            break
        }
    }
    
    /// Call this method when user tap jump time button.
    private func jumpToTime(_ jumpTimeType: JumpTimeType) {
        guard let player = playerView.player as? AVQueuePlayer else { return }
        let seekCMTime = TimeManager.getValidSeekTime(duration: duration, currentTime: currentTime, jumpTimeType: jumpTimeType)
        player.seek(to: seekCMTime)
        self.currentTime = seekCMTime
    }
    
    /// Call this method when user in the process of dragging progress bar slider.
    private func slideToTime(_ sliderValue: Double) {
        guard let player = playerView.player as? AVQueuePlayer else { return }
        let seekCMTime = TimeManager.getCMTime(from: sliderValue, duration: duration)
        player.seek(to: seekCMTime)
        self.currentTime = seekCMTime
    }
    
    /// Call this method when user end dragging progress bar slider.
    private func sliderTouchEnded(_ sliderValue: Double) {
        guard let player = playerView.player as? AVQueuePlayer,
              let playerItem = player.currentItem else { return }
        
        // Drag to the end of the progress bar.
        if sliderValue == 1 {
            currentTime = duration
            playerControlView.togglePlayButtonImage(.play)
            videoPlayHelper.playerState = .ended
            removePeriodicTimeObserver()
            print("sliderValue 1")
            return
        }
        
        // Drag to middle and is likely to keep up.
        if playerItem.isPlaybackLikelyToKeepUp {
            playPlayer()
            return
        }
        
        // Drag to middle, but needs time buffering.
        bufferingForSeconds(playerItem: playerItem, player: player)
    }
    
    /// Set player playback speed rate according to correspond button type.
    private func adjustSpeed(_ speedButtonType: SpeedButtonType) {
        playerView.player?.currentItem?.audioTimePitchAlgorithm = .spectral
        self.playSpeedRate = speedButtonType.speedRate
        if videoPlayHelper.playerState == .playing {
            playPlayer()
            return
        }
        playerView.player?.rate = playSpeedRate
        pausePlayer()
    }
    
    /// Hide control panel and show locked screen view.
    private func lockScreen() {
        hidePlayerControl(animateDuration: 0.2)
        addScreenLockedView()
        showScreenLockedPanel()
    }
    
    /// Present subtitleAudioViewController.
    private func showAudioSubtitleSelection() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let subtitleAudioViewController = storyboard.instantiateViewController(withIdentifier: SubtitleAudioViewController.reuseIdentifier) as? SubtitleAudioViewController else { return }
        subtitleAudioViewController.mediaOption = videoPlayHelper.mediaOption
        subtitleAudioViewController.selectedAudioIndex = audioSlectedIndex
        subtitleAudioViewController.selectedSubtitleIndex = subTitleSlectedIndex
        subtitleAudioViewController.delegate = self
        present(subtitleAudioViewController, animated: true, completion: nil)
    }
    
    private func dismissCustomPlayerViewController() {
        rotateDisplay(to: .portrait)
        dismiss(animated: true, completion: nil)
    }
    
    private func adjustBrightness(_ sliderValue: Double) {
        UIScreen.main.brightness = CGFloat(sliderValue)
    }
    
}

// MARK: - PlayerControlDelegate

extension CustomPlayerViewController: PlayerControlViewDelegate {
    
    func handleSliderEvent(_ playerControlview: PlayerControlView, sliderEventType: PlayerControlViewSliderEventType) {
        
        switch sliderEventType {
            
        case .progressValueChange(let sliderValue):
            slideToTime(Double(sliderValue))
            
        case .progressTouchEnd(let sliderValue):
            sliderTouchEnded(Double(sliderValue))
            
        case .brightnessValueChange(let sliderValue):
            adjustBrightness(Double(sliderValue))
        }
    }
    
    
    func handleTap(_ playerControlview: PlayerControlView, tapType: PlayerControlViewTapType) {
        
        switch tapType {
            
        case .togglePlay:
            togglePlay()
            
        case .jumpToTime(let jumpTimeType):
            jumpToTime(jumpTimeType)
            
        case .adjustSpeed(let speedButtonType):
            adjustSpeed(speedButtonType)
            
        case .proceedNextItem:
            videoPlayHelper.proceedNextPlayerItem()
            
        case .hidePlayerControl:
            hidePlayerControl()
            
        case .lockScreen:
            lockScreen()
            
        case .showAudioSubtitlePage:
            showAudioSubtitleSelection()
            
        case .dismissCustomPlayerViewController:
            dismissCustomPlayerViewController()
        }
    }
    
    func pauseToSeek(_ playerControlview: PlayerControlView) {
        pausePlayer()
    }
    
}

// MARK: - NetworkCheckable

extension CustomPlayerViewController: NetworkCheckable {
    
    private func connectionHandler() {
        DispatchQueue.main.async {
            if let noNetworkAlert = self.noNetworkAlert {
                self.dismissAlert(noNetworkAlert, completion: nil)
            }
        }
    }
    
    private func noConnectionHandler() {
        DispatchQueue.main.async {
            self.noNetworkAlert = self.popAlert(title: Constant.networkAlertTitle, message: Constant.networkAlertMessage)
        }
    }
    
}

// MARK: - PlayerViewDelegate

extension CustomPlayerViewController: PlayerViewDelegate {
    
    /// Show player control when user tap playerView.
    func showPlayerControl(from playerView: PlayerView) {
        showPlayerControl()
        autoHidePlayerControl()
    }
    
}

// MARK: - ScreenLockedViewDelegate

extension CustomPlayerViewController: ScreenLockedViewDelegate {
    
    /// Show screen lock panel when user tap screenLockedView.
    func showScreenLockPanel(from screenLockedView: ScreenLockedView) {
        showScreenLockedPanel()
    }
    
    /// Remove screen locked view, and then show play control.
    func unlockScreen(from screenLockedView: ScreenLockedView) {
        removeScreenLockedView()
        showPlayerControl()
    }
    
}

// MARK: - SubtitleAudioSelectDelegate

extension CustomPlayerViewController: SubtitleAudioSelectDelegate {
    
    /// Recieve the subtitle index from subtitleAudioViewController, and set to current player item.
    func selectSubtitle(_ subtitleAudioViewController: SubtitleAudioViewController, index: Int) {
        videoPlayHelper.selectMediaOption(mediaOptionType: .subtitle, index: index)
        subTitleSlectedIndex = index
    }
    
    /// Recieve the audio index from subtitleAudioViewController, and set to current player item.
    func selectAudio(_ subtitleAudioViewController: SubtitleAudioViewController, index: Int) {
        videoPlayHelper.selectMediaOption(mediaOptionType: .audio, index: index)
        audioSlectedIndex = index
    }
    
}

// MARK: - Config UI method

extension CustomPlayerViewController {
    
    private func setBackgroundcolor() {
        view.backgroundColor = .black
    }
    
    private func setPlayerView() {
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setPlayerControlView() {
        view.addSubview(playerControlView)
        playerControlView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerControlView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerControlView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerControlView.topAnchor.constraint(equalTo: view.topAnchor),
            playerControlView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
}

// MARK: - Section Heading

extension CustomPlayerViewController: VideoPlayHelperProtocol {
    
    func didPlaybackEnd(_ VideoPlayHelper: VideoPlayHelper) {
        guard let itemsInPlayer = videoPlayHelper.itemsInPlayer,
              let currentItem = videoPlayHelper.currentItem else { return }
        
        presentedViewController?.dismiss(animated: true, completion: nil)
        subTitleSlectedIndex = nil
        audioSlectedIndex = nil
        
        if currentItem == itemsInPlayer.last {
            rotateDisplay(to: .portrait)
            dismiss(animated: true, completion: nil)
            return
        }
    }
    
    func toggleIndicatorView(_ VideoPlayHelper: VideoPlayHelper, show: Bool) {
        if show {
            playerControlView.showIdicatorView()
        } else {
            playerControlView.removeIndicatorView()
        }
    }
    
    func updateDuration(_ VideoPlayHelper: VideoPlayHelper, duration: CMTime) {
        self.duration = duration
    }
    
}


