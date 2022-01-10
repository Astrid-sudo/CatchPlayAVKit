//
//  VideoPlayHelper.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/10.
//

import AVFoundation

protocol VideoPlayHelperProtocol: AnyObject {
    func toggleIndicatorView(_ VideoPlayHelper: VideoPlayHelper, show: Bool)
    func updateDuration(_ VideoPlayHelper: VideoPlayHelper, duration: CMTime)
    func didPlaybackEnd(_ VideoPlayHelper: VideoPlayHelper)
}

enum PlayerState {
    case unknow
    case readyToPlay
    case playing
    case buffering
    case failed
    case pause
    case ended
}

class VideoPlayHelper: NSObject {
    
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
    
    weak var delegate: VideoPlayHelperProtocol?
    
    var mediaOption: MediaOption?
    
    private var isPlaybackBufferEmptyObserver: NSKeyValueObservation?
    
    private var isPlaybackBufferFullObserver: NSKeyValueObservation?
    
    private var isPlaybackLikelyToKeepUpObserver: NSKeyValueObservation?
    
    private var statusObserve: NSKeyValueObservation?
    
    func configQueuePlayer(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        queuePlayer = AVQueuePlayer(url: url)
        observePlayerItem(previousPlayerItem: nil, currentPlayerItem: currentItem)
    }
    
    func insertPlayerItem(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let playerItem = AVPlayerItem(url: url)
        queuePlayer?.insert(playerItem, after: nil)
    }
    
    /// Show indicator view when isPlaybackBufferEmpty.
    private func onIsPlaybackBufferEmptyObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackBufferEmpty {
            delegate?.toggleIndicatorView(self, show: true)
        }
    }
    
    /// Remove indicator view when isPlaybackBufferFull.
    private func onIsPlaybackBufferFullObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackBufferFull {
            delegate?.toggleIndicatorView(self, show: false)
        }
    }
    
    /// Remove indicator view when isPlaybackLikelyToKeepUp.
    private func onIsPlaybackLikelyToKeepUpObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        if playerItem.isPlaybackLikelyToKeepUp {
            delegate?.toggleIndicatorView(self, show: false)
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
            self.delegate?.updateDuration(self, duration: currentPlayerItem.duration)
            self.getMediaSelectionOptions(currentPlayerItem: currentPlayerItem)
        }
    }
    
    /// Observe player item did play end.
    private func observeItemPlayEnd(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        if let previousPlayerItem = previousPlayerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: previousPlayerItem)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didPlaybackEnd), name: .AVPlayerItemDidPlayToEndTime, object: currentPlayerItem)
    }
    
    /// Observe player item buffering, status and play end.
    private func observePlayerItem(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
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
        queuePlayer.seek(to: .zero)
        observePlayerItem(previousPlayerItem: currentItem, currentPlayerItem: theLastItem)
    }
    
    @objc func didPlaybackEnd() {
        
        if let currentItemIndex = currentItemIndex,
           let itemsCount = itemsInPlayer?.count,
           itemsCount > currentItemIndex + 1 {
            observePlayerItem(previousPlayerItem: currentItem, currentPlayerItem: itemsInPlayer?[currentItemIndex + 1])
        }
        
        delegate?.didPlaybackEnd(self)
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
    
    /// Collect display name and locale from AVMediaCharacteristic.
    /// - Parameters:
    ///   - currentPlayerItem: The current item in the player.
    ///   - characteristic: The options for specifying media type characteristics.
    /// - Returns: An array of DisplayNameLocale.
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
    
}
