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
        return PlayerView()
    }()
    
    private lazy var playerControlView: PlayerControlView = {
        let playerControlView = PlayerControlView()
        playerControlView.delegate = self
        return playerControlView
    }()
    
    // MARK: - properties
    
    private var isPlaybackBufferEmptyObserver: NSKeyValueObservation?
    
    private var isPlaybackBufferFullObserver: NSKeyValueObservation?
    
    private var isPlaybackLikelyToKeepUpObserver: NSKeyValueObservation?
    
    private var statusObserve: NSKeyValueObservation?
    
    override open var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return .landscape
    }
    
    private var timeObserverToken: Any?
    
    private var bufferTimer: BufferTimer?
    
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

    
    // MARK: - life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setPlayerView()
        setPlayerControlView()
        setPlayContent()
    }
    
    // MARK: - UI method
    
    private func setPlayerView() {
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setPlayerControlView() {
        view.addSubview(playerControlView)
        playerControlView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerControlView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            playerControlView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            playerControlView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            playerControlView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // MARK: - player method
    
    private func createAVPlayerItem(_ urlString: String) -> AVPlayerItem? {
        guard let url = URL(string: urlString) else { return nil }
        return AVPlayerItem(url: url)
    }
    
    /// Place AVPlayerItem in AVQueuePlayer, assign to AVPlayer
    private func setPlayContent() {
        guard let firstItem = createAVPlayerItem(Constant.sourceOne),
              let secondItem = createAVPlayerItem(Constant.sourceTwo) else { return }
        playerView.player = AVQueuePlayer(items: [firstItem, secondItem])
        observePlayerItemStatus(currentPlayerItem: firstItem)
        observeBuffering(currentPlayerItem: firstItem)
        observeFirstItemEnd()
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
        }
    }
    
    /// Set a timer to check if AVPlayerItem.isPlaybackLikelyToKeepUp
    private func bufferingForSeconds(playerItem: AVPlayerItem, player: AVPlayer) {
        
        guard playerItem.status == .readyToPlay,
              playerView.playerState != .failed else { return }
        
        player.pause()
        playerView.playerState = .pause
        bufferTimer?.cancel()
        
        playerView.playerState = .buffering
        playerControlView.togglePlayButtonImage(.indicatorView)
        bufferTimer = BufferTimer(interval: 0, delaySecs: 3.0, repeats: false, action: { [weak self] _ in
            guard let self = self else { return }
            if playerItem.isPlaybackLikelyToKeepUp {
                player.play()
                player.rate = self.playSpeedRate
                self.playerView.playerState = .playing
                self.playerControlView.togglePlayButtonImage(.pause)
            } else {
                self.bufferingForSeconds(playerItem: playerItem, player: player)
            }
        })
        
        bufferTimer?.start()
        
    }
    
    // MARK: - playerItem method
    
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
    
    @objc func didPlaybackEnd() {
        print("Play back end")
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
    
}

// MARK: - CustomPlayerControlDelegate

extension CustomPlayerViewController: CustomPlayerControlDelegate {
    
    func togglePlay(_ playerControlview: PlayerControlView) {
        
        switch playerView.playerState {
            
        case .buffering:
            playerView.player?.play()
            playerView.player?.rate = playSpeedRate
            playerControlview.togglePlayButtonImage(.indicatorView)
            print("buffering")
            
        case .unknow, .pause, .readyToPlay:
            playerView.player?.play()
            playerView.player?.rate = playSpeedRate
            playerView.playerState = .playing
            
            playerControlview.togglePlayButtonImage(.pause)
            addPeriodicTimeObserver()
            print("unknow.pause.readyToPlay")
            
        case .playing:
            playerView.player?.pause()
            playerView.playerState = .pause
            
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
            self.playSpeedRate = playSpeedRate
            playerView.player?.rate = playSpeedRate
        } else {
            self.playSpeedRate = playSpeedRate
            playerView.player?.rate = playSpeedRate
            playerView.player?.pause()
            playerView.playerState = .pause
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
    
}

