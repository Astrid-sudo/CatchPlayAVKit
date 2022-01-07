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
    
    private var mediaOption: MediaOption?
    
    private var player: AVQueuePlayer? {
        playerView.player as? AVQueuePlayer
    }
    
    private var itemsInPlayer: [AVPlayerItem]? {
        player?.items()
    }
    
    // MARK: - UI properties
    
    private lazy var playerView: PlayerView = {
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
        observePlayerItem(previousPlayerItem: nil, currentPlayerItem: firstItem)
    }
    
    /// Access and gather availableMediaCharacteristicsWithMediaSelectionOptions, store in local variable.
    private func getMediaSelectionOptions(currentPlayerItem: AVPlayerItem) {
        var audibleOption = [DisplayNameLocale]()
        var legibleOption = [DisplayNameLocale]()
        for characteristic in currentPlayerItem.asset.availableMediaCharacteristicsWithMediaSelectionOptions {
            if characteristic == .audible {
                audibleOption = getMediaOptionDisplayDetail(currentPlayerItem: currentPlayerItem,
                                                            characteristic: characteristic)
            }
            if characteristic == .legible {
                legibleOption = getMediaOptionDisplayDetail(currentPlayerItem: currentPlayerItem,
                                                            characteristic: characteristic)
            }
        }
        mediaOption = MediaOption(avMediaCharacteristicAudible: audibleOption, avMediaCharacteristicLegible: legibleOption)
    }

    private func getMediaOptionDisplayDetail(currentPlayerItem: AVPlayerItem, characteristic: AVMediaCharacteristic) -> [DisplayNameLocale] {
        var result = [DisplayNameLocale]()
        if let group = currentPlayerItem.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) {
            for option in group.options {
                let displayNameLocale = DisplayNameLocale(displayName: option.displayName,
                                                          locale: option.locale)
                result.append(displayNameLocale)
            }
        }
        return result
    }
    
    /// Cancel play when playerItem needs time buffer.
    private func cancelPlay(player: AVPlayer) {
        player.pause()
        playerView.playerState = .pause
        bufferTimer?.cancel()
        cancelAutoHidePlayerControl()
    }
    
    /// Set a timer to check if AVPlayerItem.isPlaybackLikelyToKeepUp
    private func bufferingForSeconds(playerItem: AVPlayerItem, player: AVPlayer) {
        guard playerItem.status == .readyToPlay,
              playerView.playerState != .failed else { return }
        cancelPlay(player: player)
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
    
    /// Show indicator view when isPlaybackBufferEmpty.
    private func onIsPlaybackBufferEmptyObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackBufferEmpty {
            playerControlView.showIdicatorView()
        }
    }
    
    /// Remove indicator view when isPlaybackBufferFull.
    private func onIsPlaybackBufferFullObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackBufferFull {
            playerControlView.removeIndicatorView()
        }
    }
    
    /// Remove indicator view when isPlaybackLikelyToKeepUp.
    private func onIsPlaybackLikelyToKeepUpObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackLikelyToKeepUp {
            playerControlView.removeIndicatorView()
        }
    }
    
    /// Observe buffering for current item.
    private func observeItemBuffering(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        guard let currentPlayerItem = currentPlayerItem else { return }
        isPlaybackBufferEmptyObserver = currentPlayerItem.observe(\.isPlaybackBufferEmpty, changeHandler: onIsPlaybackBufferEmptyObserverChanged)
        isPlaybackBufferFullObserver = currentPlayerItem.observe(\.isPlaybackBufferFull, changeHandler: onIsPlaybackBufferFullObserverChanged)
        isPlaybackLikelyToKeepUpObserver = currentPlayerItem.observe(\.isPlaybackLikelyToKeepUp, changeHandler: onIsPlaybackLikelyToKeepUpObserverChanged)
    }
    
    /// Access AVPlayerItem duration, and media options once AVPlayerItem is loaded
    private func observeItemStatus(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        guard let currentPlayerItem = currentPlayerItem else { return }
        statusObserve = currentPlayerItem.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
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
        self.observeItemBuffering(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
        self.observeItemStatus(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
        self.observeItemPlayEnd(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
    }

    /// Triggerd when player item playback end.
    @objc func didPlaybackEnd() {
        guard let player = player,
              let itemsInPlayer = itemsInPlayer,
              let currentItem = player.currentItem else { return }
        
        if currentItem == itemsInPlayer.last {
            rotateDisplay(to: .portrait)
            presentingViewController?.dismiss(animated: true, completion: nil)
            dismiss(animated: true, completion: nil)
            return
        }
        
        if let nowIndex = getIndexCurrentItem(itemsInPlayer: itemsInPlayer, currentItem: currentItem) {
            observePlayerItem(previousPlayerItem: currentItem, currentPlayerItem: itemsInPlayer[nowIndex + 1])
        }
    }
    
    /// Get index of currentItem.
    private func getIndexCurrentItem(itemsInPlayer:[AVPlayerItem], currentItem: AVPlayerItem) -> Int? {
        return itemsInPlayer.firstIndex(of: currentItem)
    }
    
    /// Set selected audio track and subtitle to current player item.
    private func selectMediaOption(mediaOptionType: MediaOptionType, index: Int) {
        var displayNameLocaleArray: [DisplayNameLocale]? {
            switch mediaOptionType {
            case .audio:
                return mediaOption?.avMediaCharacteristicAudible
            case .subtitle:
                return mediaOption?.avMediaCharacteristicLegible
            }
        }
        guard let player = playerView.player as? AVQueuePlayer,
              let currentItem = player.currentItem,
              let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: mediaOptionType.avMediaCharacteristic),
              let locale = displayNameLocaleArray?[index].locale else { return }
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
            return
        }
        
        if playerItem.isPlaybackLikelyToKeepUp {
            player.play()
            playerView.player?.rate = playSpeedRate
            addPeriodicTimeObserver()
            autoHidePlayerControl()
            playerView.playerState = .playing
            playerControlview.togglePlayButtonImage(.pause)
            return
        }
        
        bufferingForSeconds(playerItem: playerItem, player: player)
        
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
            return
        }
        self.playSpeedRate = playSpeedRate
        playerView.player?.rate = playSpeedRate
        playerView.player?.pause()
        playerView.playerState = .pause
        cancelAutoHidePlayerControl()
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


