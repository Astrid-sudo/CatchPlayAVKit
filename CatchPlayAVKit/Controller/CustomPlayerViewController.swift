//
//  CustomPlayerViewController.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import AVKit

enum PlayerState {
    case unknow
    case readyToPlay
    case playing
    case buffering
    case failed
    case pause
    case ended
}

class CustomPlayerViewController: UIViewController {
    
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
    
    // MARK: - properties
    
    lazy var networkManager = NetworkManager()
    
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
                playerControlView.updateProgress(currentTime: Float(CMTimeGetSeconds(currentTime)) , duration: Float(CMTimeGetSeconds(duration)))
            }
        }
    }
    
    var duration: CMTime = .zero {
        didSet {
            if duration != oldValue {
                playerControlView.updateProgress(currentTime: Float(CMTimeGetSeconds(currentTime)) , duration: Float(CMTimeGetSeconds(duration)))
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
        checkNetwork(connectionHandler: connectionHandler, noConnectionHandler: noConnectionHandler)
        observeScreenBrightness()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI method
    
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
    
    private func createAVPlayerItem(_ urlString: String) -> AVPlayerItem? {
        guard let url = URL(string: urlString) else { return nil }
        return AVPlayerItem(url: url)
    }
    
    private func observeItemPlayEnd(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem) {
        if let lastPlayerItem = previousPlayerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: lastPlayerItem)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(didPlaybackEnd), name: .AVPlayerItemDidPlayToEndTime, object: currentPlayerItem)
    }
    
    /// Access AVPlayerItem duration once AVPlayerItem is loaded
    private func observePlayerItemStatus(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem) {
        statusObserve = currentPlayerItem.observe(\.status, options: [.new]) { [weak self] _, _ in
            guard let self = self else { return }
            self.duration = currentPlayerItem.duration
            self.getMediaSelectionOptions(currentPlayerItem: currentPlayerItem)
        }
    }

    private func observeBuffering(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        guard let currentPlayerItem = currentPlayerItem else { return }
        isPlaybackBufferEmptyObserver = currentPlayerItem.observe(\.isPlaybackBufferEmpty, changeHandler: onIsPlaybackBufferEmptyObserverChanged)
        isPlaybackBufferFullObserver = currentPlayerItem.observe(\.isPlaybackBufferFull, changeHandler: onIsPlaybackBufferFullObserverChanged)
        isPlaybackLikelyToKeepUpObserver = currentPlayerItem.observe(\.isPlaybackLikelyToKeepUp, changeHandler: onIsPlaybackLikelyToKeepUpObserverChanged)
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
    
    private func observeFirstItemEnd() {
        guard let player = playerView.player as? AVQueuePlayer else { return }
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.items().first, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            let items = player.items()
            if items.indices.contains(1) {
                let secondItem = items[1]
                self.observeBuffering(previousPlayerItem: items[0], currentPlayerItem: secondItem)
                self.observePlayerItemStatus(previousPlayerItem: items[0], currentPlayerItem: secondItem)
                self.observeItemPlayEnd(previousPlayerItem: items[0], currentPlayerItem: secondItem)
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
    
    /// Set selected audio track to current player item.
    private func playerItemSelectAudio(index: Int) {
        guard let player = playerView.player as? AVQueuePlayer,
              let currentItem = player.currentItem,
              let mediaOption = mediaOption,
              let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristic.audible),
              let locale = mediaOption.aVMediaCharacteristicAudible[index].locale
        else { return }
        let options =
        AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: locale)
        if let option = options.first {
            currentItem.select(option, in: group)
        }
    }
    
    /// Set selected subtitle to current player item.
    private func playerItemSelectSubtitle(index: Int) {
        guard let player = playerView.player as? AVQueuePlayer,
              let currentItem = player.currentItem,
              let mediaOption = mediaOption,
              let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristic.legible),
              let locale = mediaOption.aVMediaCharacteristicLegible[index].locale
        else { return }
        let options =
        AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: locale)
        if let option = options.first {
            currentItem.select(option, in: group)
        }
    }

    // MARK: - update UI method
    
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
    
}

// MARK: - CustomPlayerControlDelegate

extension CustomPlayerViewController: CustomPlayerControlDelegate {

    func togglePlay(_ playerControlview: PlayerControlView) {
        
        switch playerView.playerState {
            
        case .buffering:
            playerView.player?.play()
            playerView.player?.rate = playSpeedRate
            autoHidePlayerControl()
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
        guard let player = playerView.player as? AVQueuePlayer,
              let currentItem = player.currentItem else { return }
        let currentSeconds = CMTimeGetSeconds(player.currentTime())
        var seekSeconds: Float64 = .zero
        
        switch jumpTimeType {
        case .forward(let associateSeconds):
            seekSeconds = currentSeconds + associateSeconds
        case .backward(let associateSeconds):
            seekSeconds = currentSeconds - associateSeconds
        }
        
        let currentDuration = CMTimeGetSeconds(currentItem.duration)
        
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
            observeBuffering(previousPlayerItem: currentItem, currentPlayerItem: theLastItem)
            observePlayerItemStatus(currentPlayerItem: theLastItem)
            observeItemPlayEnd(previousPlayerItem: currentItem, currentPlayerItem: theLastItem)
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
        print("Tap screenLockedView")
        showScreenLockedPanel()
    }
    
    func unlockScreen(from screenLockedView: ScreenLockedView) {
        print("Unlock Screen screenLockedView")
        removeScreenLockedView()
        showPlayerControl()
    }
    
}

// MARK: - SubtitleAudioSelectDelegate

extension CustomPlayerViewController: SubtitleAudioSelectDelegate {
    
    func selectSubtitle(_ subtitleAudioViewController: SubtitleAudioViewController, index: Int) {
        playerItemSelectSubtitle(index: index)
    }
    
    func selectAudio(_ subtitleAudioViewController: SubtitleAudioViewController, index: Int) {
        playerItemSelectAudio(index: index)
    }
    
}


