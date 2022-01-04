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
        observeFirstItemEnd()
    }
    
    /// Access AVPlayerItem duration once AVPlayerItem is loaded
    private func observePlayerItemStatus(lastPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem) {
        statusObserve = currentPlayerItem.observe(\.status, options: [.new]) { [weak self] _, _ in
            guard let self = self else { return }
            self.duration = currentPlayerItem.duration
        }
    }
    
    // MARK: - playerItem method
    
    private func observeBuffering(for playerItem: AVPlayerItem?) {
        guard let playerItem = playerItem else { return }
        isPlaybackBufferEmptyObserver = playerItem.observe(\.isPlaybackBufferEmpty, changeHandler: onIsPlaybackBufferEmptyObserverChanged)
        isPlaybackBufferFullObserver = playerItem.observe(\.isPlaybackBufferFull, changeHandler: onIsPlaybackBufferFullObserverChanged)
        isPlaybackLikelyToKeepUpObserver = playerItem.observe(\.isPlaybackLikelyToKeepUp, changeHandler: onIsPlaybackLikelyToKeepUpObserverChanged)
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
                self.observeBuffering(for: secondItem)
                self.observePlayerItemStatus(lastPlayerItem: items[0], currentPlayerItem: secondItem)
                self.duration = secondItem.duration
                print("firstEnd\(secondItem.duration)")
            }
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
    
}

