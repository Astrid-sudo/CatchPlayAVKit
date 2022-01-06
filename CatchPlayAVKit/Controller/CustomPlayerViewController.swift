//
//  CustomPlayerViewController.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import AVKit

class CustomPlayerViewController: UIViewController {
    
    // MARK: - properties
    
    lazy var networkManager: NetworkManager = {
        return NetworkManager()
    }()
    
    private var isPlaybackBufferEmptyObserver: NSKeyValueObservation?
    
    private var isPlaybackBufferFullObserver: NSKeyValueObservation?
    
    private var isPlaybackLikelyToKeepUpObserver: NSKeyValueObservation?
    
    private var statusObserve: NSKeyValueObservation?
    
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
            if duration != oldValue {
                playerControlView.updateProgress(currentTime: Float(CMTimeGetSeconds(currentTime)), duration: Float(CMTimeGetSeconds(duration)))
            }
        }
    }
    
    var playSpeedRate: Float = 1 {
        didSet {
            if playSpeedRate != oldValue {
                playerControlView.setSpeedButtonColor(selecedSpeed: playSpeedRate)
            }
        }
    }
    
    var mediaOption: MediaOption?
    
    // MARK: - life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setPlayerView()
        setPlayerControlView()
        setPlayContent()
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
        guard let firstItem = createAVPlayerItem(Constant.sourceOne),
              let secondItem = createAVPlayerItem(Constant.sourceTwo) else { return }
        playerView.player = AVQueuePlayer(items: [firstItem, secondItem])
        observePlayerItemStatus(currentPlayerItem: firstItem)
        observeBuffering(currentPlayerItem: firstItem)
        observeFirstItemEnd()
    }
    
    /// Access and gather availableMediaCharacteristicsWithMediaSelectionOptions, store in local variable.
    private func getMediaSelectionOptions(currentPlayerItem: AVPlayerItem) {
        
        var audibleOption = [DisplayNameLocale]()
        var legibleOption = [DisplayNameLocale]()
        for characteristic in currentPlayerItem.asset.availableMediaCharacteristicsWithMediaSelectionOptions {
            if characteristic == .audible {
                if let group = currentPlayerItem.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) {
                    for option in group.options {
                        let displayNameLocale = DisplayNameLocale(displayName: option.displayName,
                                                                  locale: option.locale)
                        audibleOption.append(displayNameLocale)
                    }
                }
            }
            
            if characteristic == .legible {
                if let group = currentPlayerItem.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) {
                    for option in group.options {
                        let displayNameLocale = DisplayNameLocale(displayName: option.displayName,
                                                                  locale: option.locale)
                        legibleOption.append(displayNameLocale)
                    }
                }
            }
        }
        
        mediaOption = MediaOption(aVMediaCharacteristicAudible: audibleOption, aVMediaCharacteristicLegible: legibleOption)
    }
    
    /// Set a timer to check if AVPlayerItem.isPlaybackLikelyToKeepUp
    private func bufferingForSeconds(playerItem: AVPlayerItem, player: AVPlayer) {
        
        guard playerItem.status == .readyToPlay,
              playerView.playerState != .failed else { return }
        
        player.pause()
        playerView.playerState = .pause
        bufferTimer?.cancel()
        cancelAutoHidePlayerControl()
        
        playerView.playerState = .buffering
        playerControlView.togglePlayButtonImage(.indicatorView)
        bufferTimer = BufferTimer(interval: 0, delaySecs: 3.0, repeats: false, action: { [weak self] _ in
            guard let self = self else { return }
            if playerItem.isPlaybackLikelyToKeepUp {
                player.play()
                player.rate = self.playSpeedRate
                self.autoHidePlayerControl()
                self.addPeriodicTimeObserver()
                self.playerView.playerState = .playing
                self.playerControlView.togglePlayButtonImage(.pause)
            } else {
                self.bufferingForSeconds(playerItem: playerItem, player: player)
            }
        })
        
        bufferTimer?.start()
    }
    
    // MARK: - playerItem method
    
    /// Create AVPlayerItem by urlString.
    private func createAVPlayerItem(_ urlString: String) -> AVPlayerItem? {
        guard let url = URL(string: urlString) else { return nil }
        return AVPlayerItem(url: url)
    }
    
    private func onIsPlaybackBufferEmptyObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackBufferEmpty {
            playerControlView.showIdicatorView()
        }
    }
    
    private func onIsPlaybackBufferFullObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackBufferFull {
            playerControlView.removeIndicatorView()
        }
    }
    
    private func onIsPlaybackLikelyToKeepUpObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackLikelyToKeepUp {
            playerControlView.removeIndicatorView()
        }
    }
    
    private func observeBuffering(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        guard let currentPlayerItem = currentPlayerItem else { return }
        isPlaybackBufferEmptyObserver = currentPlayerItem.observe(\.isPlaybackBufferEmpty, changeHandler: onIsPlaybackBufferEmptyObserverChanged)
        isPlaybackBufferFullObserver = currentPlayerItem.observe(\.isPlaybackBufferFull, changeHandler: onIsPlaybackBufferFullObserverChanged)
        isPlaybackLikelyToKeepUpObserver = currentPlayerItem.observe(\.isPlaybackLikelyToKeepUp, changeHandler: onIsPlaybackLikelyToKeepUpObserverChanged)
    }
    
    /// Access AVPlayerItem duration, and media options once AVPlayerItem is loaded
    private func observePlayerItemStatus(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        guard let currentPlayerItem = currentPlayerItem else { return }
        statusObserve = currentPlayerItem.observe(\.status, options: [.new]) { [weak self] _, _ in
            guard let self = self else { return }
            self.duration = currentPlayerItem.duration
            self.getMediaSelectionOptions(currentPlayerItem: currentPlayerItem)
        }
    }
    
    private func observeItemPlayEnd(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        if let previousPlayerItem = previousPlayerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: previousPlayerItem)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(didPlaybackEnd), name: .AVPlayerItemDidPlayToEndTime, object: currentPlayerItem)
    }
    
    private func observePlayerItem(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        self.observeBuffering(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
        self.observePlayerItemStatus(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
        self.observeItemPlayEnd(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
    }

    private func observeFirstItemEnd() {
        guard let player = playerView.player as? AVQueuePlayer else { return }
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.items().first, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            let items = player.items()
            if items.indices.contains(1) {
                let secondItem = items[1]
                self.observePlayerItem(previousPlayerItem: items[0], currentPlayerItem: secondItem)
                self.duration = secondItem.duration
                print("firstEnd\(secondItem.duration)")
            }
        }
    }
    
    /// The last player item playback end.
    @objc func didPlaybackEnd() {
        print("Play back end")
        rotateDisplay(to: .portrait)
        presentingViewController?.dismiss(animated: true, completion: nil)
        dismiss(animated: true, completion: nil)
    }
    
    /// Set selected audio track and subtitle to current player item.
    private func selectMediaOption(mediaOptionType: MediaOptionType, index: Int) {
        var array: [DisplayNameLocale]?
        switch mediaOptionType {
        case .audio:
            array = mediaOption?.aVMediaCharacteristicAudible
        case .subtitle:
            array = mediaOption?.aVMediaCharacteristicLegible
        }
        guard let player = playerView.player as? AVQueuePlayer,
              let currentItem = player.currentItem,
              let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: mediaOptionType.aVMediaCharacteristic),
              let locale = array?[index].locale else { return }
        let options =
        AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: locale)
        if let option = options.first {
            currentItem.select(option, in: group)
        }
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
    
    private func hidePlayerControl(animateDuration: TimeInterval = 0.4) {
        UIView.animate(withDuration: animateDuration, delay: 0, options: .curveEaseIn) {
            self.playerControlView.alpha = 0
        }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            self.playerControlView.isHidden = true
        }
    }
    
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
    
    private func removeScreenLockedView() {
        screenLockedView.removeFromSuperview()
    }
    
    private func showScreenLockedPanel(delay: TimeInterval = 0, for seconds: TimeInterval = 3) {
        screenLockedView.uiPropertiesIsHidden(isHidden: false)
        UIView.animate(withDuration: 0.3, delay: delay, options: .curveEaseOut) {
            self.screenLockedView.uiPropertiesAlpha(1)
        }
        
        Timer.scheduledTimer(withTimeInterval: delay + seconds + 0.6, repeats: false) {[weak self] _ in
            guard let self = self else { return }
            self.screenLockedView.uiPropertiesIsHidden(isHidden: true)
        }
    }
    
    ///Add observer UIScreen.brightnessDidChangeNotification
    private func observeScreenBrightness() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateBrightnessSlider), name: UIScreen.brightnessDidChangeNotification, object: nil)
    }
    
    @objc func updateBrightnessSlider() {
        playerControlView.updateBrightnessSliderValue()
    }
    
    // MARK: - UI properties
    
     lazy var playerView: PlayerView = {
        let playerView = PlayerView()
        playerView.delegate = self
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
    
}

// MARK: - PlayerControlDelegate

extension CustomPlayerViewController: PlayerControlViewDelegate {
    
    func togglePlay(_ playerControlview: PlayerControlView) {
        
        switch playerView.playerState {
            
        case .buffering:
            playerView.player?.play()
            playerView.player?.rate = playSpeedRate
            autoHidePlayerControl()
            playerView.playerState = .playing
            playerControlview.togglePlayButtonImage(.indicatorView)
            addPeriodicTimeObserver()
            print("buffering")
            
        case .unknow, .pause, .readyToPlay:
            playerView.player?.play()
            playerView.player?.rate = playSpeedRate
            autoHidePlayerControl()
            playerView.playerState = .playing
            
            playerControlview.togglePlayButtonImage(.pause)
            addPeriodicTimeObserver()
            print("unknow.pause.readyToPlay")
            
        case .playing:
            playerView.player?.pause()
            playerView.playerState = .pause
            cancelAutoHidePlayerControl()
            playerControlview.togglePlayButtonImage(.play)
            removePeriodicTimeObserver()
            print("playing")
            
        default:
            print("break")
            break
        }
    }
    
    func jumpToTime(_ playerControlview: PlayerControlView, _ jumpTimeType: JumpTimeType) {
        guard let player = playerView.player as? AVQueuePlayer else { return }
        let currentSeconds = CMTimeGetSeconds(self.currentTime)
        var seekSeconds: Float64 = .zero
        
        switch jumpTimeType {
        case .forward(let associateSeconds):
            seekSeconds = currentSeconds + associateSeconds
        case .backward(let associateSeconds):
            seekSeconds = currentSeconds - associateSeconds
        }
        
        let currentDuration = CMTimeGetSeconds(self.duration)
        
        seekSeconds = seekSeconds > currentDuration ? currentDuration : seekSeconds
        seekSeconds = seekSeconds < 0 ? 0.0 : seekSeconds
        
        let seekCMTime = CMTime(seconds: seekSeconds, preferredTimescale: 1)
        player.seek(to: seekCMTime)
        self.currentTime = seekCMTime
    }
    
    func slideToTime(_ playerControlview: PlayerControlView, _ sliderValue: Double) {
        guard let player = playerView.player as? AVQueuePlayer,
              let duration = player.currentItem?.duration else { return }
        let durationSeconds = CMTimeGetSeconds(duration)
        let seekTime = durationSeconds * sliderValue
        let seekCMTime = CMTimeMake(value: Int64(ceil(seekTime)), timescale: 1)
        player.seek(to: seekCMTime)
        self.currentTime = seekCMTime
    }
    
    func pauseToSeek(_ playerControlview: PlayerControlView) {
        playerView.player?.pause()
        playerView.playerState = .pause
        cancelAutoHidePlayerControl()
    }
    
    func sliderTouchEnded(_ playerControlview: PlayerControlView, _ sliderValue: Double) {
        guard let player = playerView.player as? AVQueuePlayer,
              let playerItem = player.currentItem else { return }
        
        if sliderValue == 1 {
            currentTime = duration
            playerControlview.togglePlayButtonImage(.play)
            playerView.playerState = .ended
            removePeriodicTimeObserver()
            print("sliderValue 1")
            
        } else if playerItem.isPlaybackLikelyToKeepUp {
            player.play()
            playerView.player?.rate = playSpeedRate
            addPeriodicTimeObserver()
            autoHidePlayerControl()
            playerView.playerState = .playing
            playerControlview.togglePlayButtonImage(.pause)
            
        } else {
            bufferingForSeconds(playerItem: playerItem, player: player)
        }
    }
    
    func adjustSpeed(_ playerControlview: PlayerControlView, _ playSpeedRate: Float) {
        playerView.player?.currentItem?.audioTimePitchAlgorithm = .spectral
        if playerView.playerState == .playing {
            playerView.player?.pause()
            playerView.player?.play()
            addPeriodicTimeObserver()
            self.playSpeedRate = playSpeedRate
            playerView.player?.rate = playSpeedRate
            autoHidePlayerControl()
        } else {
            self.playSpeedRate = playSpeedRate
            playerView.player?.rate = playSpeedRate
            playerView.player?.pause()
            playerView.playerState = .pause
            cancelAutoHidePlayerControl()
        }
    }
    
    func proceedNextPlayerItem(_ playerControlview: PlayerControlView) {
        guard let player = playerView.player as? AVQueuePlayer,
              let currentItem = player.currentItem,
              let theLastItem = player.items().last else { return }
        if currentItem == theLastItem {
            player.seek(to: .zero)
        } else {
            player.advanceToNextItem()
            observePlayerItem(previousPlayerItem: currentItem, currentPlayerItem: theLastItem)
        }
    }
    
    /// Hide player control when user tap playerControlView.
    func handleTapGesture(_ playerControlview: PlayerControlView) {
        hidePlayerControl()
    }
    
    func lockScreen(_ playerControlview: PlayerControlView) {
        hidePlayerControl(animateDuration: 0.2)
        addScreenLockedView()
        showScreenLockedPanel()
    }
    
    func showAudioSubtitleSelection(_ playerControlview: PlayerControlView) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let subtitleAudioViewController = storyboard.instantiateViewController(withIdentifier: SubtitleAudioViewController.reuseIdentifier) as? SubtitleAudioViewController else { return }
        subtitleAudioViewController.mediaOption = mediaOption
        subtitleAudioViewController.delegate = self
        present(subtitleAudioViewController, animated: true, completion: nil)
    }
    
    func dismissCustomPlayerViewController(_ playerControlview: PlayerControlView) {
        rotateDisplay(to: .portrait)
        dismiss(animated: true, completion: nil)
    }
    
    func adjustBrightness(_ playerControlview: PlayerControlView, _ sliderValue: Double) {
        UIScreen.main.brightness = CGFloat(sliderValue)
    }
    
}

// MARK: - CheckNetWorkProtocol

extension CustomPlayerViewController: CheckNetWorkProtocol {
    
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
    func handleTapGesture(from playerView: PlayerView) {
        showPlayerControl()
        autoHidePlayerControl()
    }
    
}

// MARK: - ScreenLockedViewDelegate

extension CustomPlayerViewController: ScreenLockedViewDelegate {
    
    /// Show screen lock panel when user tap screenLockedView.
    func handleTapGesture(from screenLockedView: ScreenLockedView) {
        showScreenLockedPanel()
    }
    
    func unlockScreen(from screenLockedView: ScreenLockedView) {
        removeScreenLockedView()
        showPlayerControl()
    }
    
}

// MARK: - SubtitleAudioSelectDelegate

extension CustomPlayerViewController: SubtitleAudioSelectDelegate {
    
    func selectSubtitle(_ subtitleAudioViewController: SubtitleAudioViewController, index: Int) {
        selectMediaOption(mediaOptionType: .subtitle, index: index)
    }
    
    func selectAudio(_ subtitleAudioViewController: SubtitleAudioViewController, index: Int) {
        selectMediaOption(mediaOptionType: .audio, index: index)
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


