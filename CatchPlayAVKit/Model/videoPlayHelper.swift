//
//  VideoPlayHelper.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/10.
//

import AVFoundation

// MARK: - VideoPlayHelperProtocol

protocol VideoPlayHelperProtocol: AnyObject {
    func toggleIndicatorView(_ videoPlayHelper: PlayerProtocol, show: Bool)
    func updateDuration(_ videoPlayHelper: PlayerProtocol, duration: CMTime)
    func updateCurrentTime(_ videoPlayHelper: PlayerProtocol, currentTime: CMTime)
    func updateSelectedSpeedButton(_ videoPlayHelper: PlayerProtocol, speedButtonType: SpeedButtonType)
    func didPlaybackEnd(_ videoPlayHelper: PlayerProtocol)
    func togglePlayButtonImage(_ videoPlayHelper: PlayerProtocol, playButtonType: PlayButtonType)
    func autoHidePlayerControl(_ videoPlayHelper: PlayerProtocol)
    func cancelAutoHidePlayerControl(_ videoPlayHelper: PlayerProtocol)
}

// MARK: - PlayerState

enum PlayerState {
    case unknow
    case readyToPlay
    case playing
    case buffering
    case failed
    case pause
    case ended
}

// MARK: - VideoPlayHelper

class VideoPlayHelper: PlayerProtocol {
    
    // MARK: - Properties
    
    private(set) var queuePlayer: AVQueuePlayer?
    
    var playerState: PlayerState = .unknow
    
    var itemsInPlayer: [AVPlayerItem]? {
        return queuePlayer?.items()
    }
    
    var currentItem: AVPlayerItem? {
        return queuePlayer?.currentItem
    }
    
    var currentItemIndex: Int? {
        guard let currentItem = currentItem else { return nil }
        return itemsInPlayer?.firstIndex(of: currentItem)
    }
    
    var currentItemDuration: CMTime? {
        guard let currentItem = currentItem else { return nil }
        return currentItem.duration
    }
    
    var currentItemCurrentTime: CMTime? {
        guard let currentItem = currentItem else { return nil }
        return currentItem.currentTime()
    }
    
    var playSpeedRate: Float = 1

    var mediaOption: MediaOption?
    
     var bufferTimer: BufferTimer?
    
     var timeObserverToken: Any?
    
     var isPlaybackBufferEmptyObserver: NSKeyValueObservation?
    
     var isPlaybackBufferFullObserver: NSKeyValueObservation?
    
     var isPlaybackLikelyToKeepUpObserver: NSKeyValueObservation?
    
     var statusObserve: NSKeyValueObservation?
    
    weak var delegate: VideoPlayHelperProtocol?
    
    // MARK: - player item method
    
    /// Create player in VideoPlayHelper with url string. This method also observe the first player item's status, buffering, didPlayEnd.
    /// - Parameter urlString: The first player item in player.
    func configQueuePlayer(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        queuePlayer = AVQueuePlayer(url: url)
        observePlayerItem(previousPlayerItem: nil, currentPlayerItem: currentItem)
    }
    
    /// Insert player item in AVQueuePlayer.
    /// - Parameter urlString: The url string which will used to create AVPlayerItem and insert in AVQueuePlayer.
    func insertPlayerItem(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let playerItem = AVPlayerItem(url: url)
        queuePlayer?.insert(playerItem, after: nil)
    }
    
    /// Show indicator view when isPlaybackBufferEmpty.
     func onIsPlaybackBufferEmptyObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackBufferEmpty {
            delegate?.toggleIndicatorView(self, show: true)
        }
    }
    
    /// Remove indicator view when isPlaybackBufferFull.
     func onIsPlaybackBufferFullObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackBufferFull {
            delegate?.toggleIndicatorView(self, show: false)
        }
    }
    
    /// Remove indicator view when isPlaybackLikelyToKeepUp.
     func onIsPlaybackLikelyToKeepUpObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackLikelyToKeepUp {
            delegate?.toggleIndicatorView(self, show: false)
        }
    }
    
    /// Observe buffering for current item.
     func observeItemBuffering(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        guard let currentPlayerItem = currentPlayerItem else { return }
        isPlaybackBufferEmptyObserver = currentPlayerItem.observe(\.isPlaybackBufferEmpty, changeHandler: onIsPlaybackBufferEmptyObserverChanged)
        isPlaybackBufferFullObserver = currentPlayerItem.observe(\.isPlaybackBufferFull, changeHandler: onIsPlaybackBufferFullObserverChanged)
        isPlaybackLikelyToKeepUpObserver = currentPlayerItem.observe(\.isPlaybackLikelyToKeepUp, changeHandler: onIsPlaybackLikelyToKeepUpObserverChanged)
    }
    
    /// Access AVPlayerItem duration, and media options once AVPlayerItem is loaded
     func observeItemStatus(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        guard let currentPlayerItem = currentPlayerItem else { return }
        statusObserve = currentPlayerItem.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            guard let self = self else { return }
            self.delegate?.updateDuration(self, duration: currentPlayerItem.duration)
            self.getMediaSelectionOptions(currentPlayerItem: currentPlayerItem)
        }
    }
    
    /// Observe player item did play end.
     func observeItemPlayEnd(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        if let previousPlayerItem = previousPlayerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: previousPlayerItem)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didPlaybackEnd), name: .AVPlayerItemDidPlayToEndTime, object: currentPlayerItem)
    }
    
    /// Observe player item buffering, status and play end.
     func observePlayerItem(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        self.observeItemBuffering(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
        self.observeItemStatus(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
        self.observeItemPlayEnd(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
    }
    
    /// Proceed to next player item, if the item is the last one in the AVQueuePlayer, then will just replay the item.
    func proceedNextPlayerItem() {
        guard let queuePlayer = queuePlayer,
              let currentItem = currentItem,
              let theLastItem = itemsInPlayer?.last else { return }
        if currentItem == theLastItem {
            queuePlayer.seek(to: .zero)
            return
        }
        queuePlayer.advanceToNextItem()
        observePlayerItem(previousPlayerItem: currentItem, currentPlayerItem: theLastItem)
    }
    
    /// Tell the delegate didPlaybackEnd. If next item exist in AVQueuePlayer, observe next item.
    @objc func didPlaybackEnd() {
        if let currentItemIndex = currentItemIndex,
           let itemsCount = itemsInPlayer?.count,
           itemsCount > currentItemIndex + 1 {
            observePlayerItem(previousPlayerItem: currentItem, currentPlayerItem: itemsInPlayer?[currentItemIndex + 1])
        }
        delegate?.didPlaybackEnd(self)
    }
    
    /// Access and gather availableMediaCharacteristicsWithMediaSelectionOptions, store in local variable.
     func getMediaSelectionOptions(currentPlayerItem: AVPlayerItem) {
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
    
    /// Collect display name and locale from AVMediaCharacteristic.
    /// - Parameters:
    ///   - currentPlayerItem: The current item in the player.
    ///   - characteristic: The options for specifying media type characteristics.
    /// - Returns: An array of DisplayNameLocale.
     func getMediaOptionDisplayDetail(currentPlayerItem: AVPlayerItem, characteristic: AVMediaCharacteristic) -> [DisplayNameLocale] {
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
    
    /// Set selected audio track and subtitle to current player item.
    func selectMediaOption(mediaOptionType: MediaOptionType, index: Int) {
        var displayNameLocaleArray: [DisplayNameLocale]? {
            switch mediaOptionType {
            case .audio:
                return mediaOption?.avMediaCharacteristicAudible
            case .subtitle:
                return mediaOption?.avMediaCharacteristicLegible
            }
        }
        guard let currentItem = currentItem,
              let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: mediaOptionType.avMediaCharacteristic),
              let locale = displayNameLocaleArray?[index].locale else { return }
        let options =
        AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: locale)
        if let option = options.first {
            currentItem.select(option, in: group)
        }
    }
    
    // MARK: - player method
    
    /// Start observe currentTime.
    func addPeriodicTimeObserver() {
        guard let queuePlayer = queuePlayer else { return }
        // Invoke callback every half second
        let interval = CMTime(seconds: 0.5,
                              preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        // Add time observer. Invoke closure on the main queue.
        timeObserverToken =
        queuePlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            guard let self = self else { return }
            // update player transport UI
            self.delegate?.updateCurrentTime(self, currentTime: time)
        }
    }
    
    /// Stop observe currentTime.
    func removePeriodicTimeObserver() {
        guard let queuePlayer = queuePlayer else { return }
        if let token = timeObserverToken {
            queuePlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    /// Call this method when user tap jump time button.
     func jumpToTime(_ jumpTimeType: JumpTimeType) {
         guard let queuePlayer = queuePlayer,
               let currentTime = self.currentItemCurrentTime,
               let duration = self.currentItemDuration else {
             return
         }
        let seekCMTime = TimeManager.getValidSeekTime(duration: duration, currentTime: currentTime, jumpTimeType: jumpTimeType)
         queuePlayer.seek(to: seekCMTime)
         delegate?.updateCurrentTime(self, currentTime: seekCMTime)
    }
    
    /// Call this method when user is in the process of dragging progress bar slider.
     func slideToTime(_ sliderValue: Double) {
        guard let queuePlayer = queuePlayer,
              let duration = self.currentItemDuration else { return }
        let seekCMTime = TimeManager.getCMTime(from: sliderValue, duration: duration)
        queuePlayer.seek(to: seekCMTime)
        delegate?.updateCurrentTime(self, currentTime: seekCMTime)
    }
    
    /// Call this method when user end dragging progress bar slider.
     func sliderTouchEnded(_ sliderValue: Double) {
        guard let queuePlayer = queuePlayer,
              let currentItem = currentItem,
        let currentItemDuration = currentItemDuration else { return }
        
        // Drag to the end of the progress bar.
        if sliderValue == 1 {
            delegate?.updateCurrentTime(self, currentTime: currentItemDuration)
            delegate?.togglePlayButtonImage(self, playButtonType: .play)
            playerState = .ended
            removePeriodicTimeObserver()
            return
        }
        
         // Drag to middle and is likely to keep up.
         if currentItem.isPlaybackLikelyToKeepUp {
             playPlayer()
             return
         }
        
        // Drag to middle, but needs time buffering.
        bufferingForSeconds(playerItem: currentItem, player: queuePlayer)
    }
    
    /// Set a timer to check if AVPlayerItem.isPlaybackLikelyToKeepUp. If yes, then will play, but if not, will recall this method again.
     func bufferingForSeconds(playerItem: AVPlayerItem, player: AVPlayer) {
        guard playerItem.status == .readyToPlay,
              playerState != .failed else { return }
        self.cancelPlay(player: player)
        playerState = .buffering
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

    /// Pause player, let player control keep existing on screen.(Call this method when buffering.)
     func cancelPlay(player: AVPlayer) {
        guard let queuePlayer = queuePlayer else { return }
        queuePlayer.pause()
        playerState = .pause
        bufferTimer?.cancel()
        delegate?.cancelAutoHidePlayerControl(self)
    }

    /// Play player, update player UI, let player control auto hide.
    func playPlayer() {
        guard let queuePlayer = queuePlayer else { return }
        queuePlayer.play()
        self.playerState = .playing
        queuePlayer.rate = self.playSpeedRate
        self.addPeriodicTimeObserver()
        self.delegate?.togglePlayButtonImage(self, playButtonType: .pause)
        self.delegate?.autoHidePlayerControl(self)
    }
    
    /// Pause player, update player UI, let player control keep existing on screen.(Call this method when user's intension to pause player.)
     func pausePlayer() {
        guard let queuePlayer = queuePlayer else { return }
        queuePlayer.pause()
        playerState = .pause
        delegate?.cancelAutoHidePlayerControl(self)
        removePeriodicTimeObserver()
        self.delegate?.togglePlayButtonImage(self, playButtonType: .play)
    }
    
    /// Determine play action according to playerState.
     func togglePlay() {
        switch playerState {
            
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
    
    /// Call this method when user tap speedButtonType button.
    func adjustSpeed(_ speedButtonType: SpeedButtonType) {
        guard let currentItem = currentItem,
        let queuePlayer = queuePlayer else { return }
        currentItem.audioTimePitchAlgorithm = .spectral
        self.playSpeedRate = speedButtonType.speedRate
        delegate?.updateSelectedSpeedButton(self, speedButtonType: speedButtonType)
        if playerState == .playing {
            playPlayer()
            return
        }
        queuePlayer.rate = playSpeedRate
        pausePlayer()
    }
    
}
