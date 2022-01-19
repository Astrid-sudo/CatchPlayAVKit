//
//  PlayerProtocol.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/18.
//

import AVFoundation

protocol PlayerProtocol {
   
    // MARK: - Properties
    
    var queuePlayer: AVQueuePlayer? { get }
    
    var playerState: PlayerState { get set }
    
    var itemsInPlayer: [AVPlayerItem]? { get }
    
    var currentItem: AVPlayerItem? { get }
    
    var currentItemIndex: Int? { get }
    
    var currentItemDuration: CMTime? { get }
    
    var currentItemCurrentTime: CMTime? { get }
    
    var playSpeedRate: Float { get set }
    
    var mediaOption: MediaOption? { get set }
    
    var bufferTimer: BufferTimer? { get set }
    
    var timeObserverToken: Any? { get set }
    
    var isPlaybackBufferEmptyObserver: NSKeyValueObservation? { get set }
    
    var isPlaybackBufferFullObserver: NSKeyValueObservation? { get set }
    
    var isPlaybackLikelyToKeepUpObserver: NSKeyValueObservation? { get set }
    
    var statusObserve: NSKeyValueObservation? { get set }
    
    var delegate: VideoPlayHelperProtocol? { get set }
    
    // MARK: - player item method
    
    /// Create player in VideoPlayHelper with url string. This method also observe the first player item's status, buffering, didPlayEnd.
    /// - Parameter urlString: The first player item in player.
    func configQueuePlayer(_ urlString: String)
    
    /// Insert player item in AVQueuePlayer.
    /// - Parameter urlString: The url string which will used to create AVPlayerItem and insert in AVQueuePlayer.
    func insertPlayerItem(_ urlString: String)
   
    /// Show indicator view when isPlaybackBufferEmpty.
    func onIsPlaybackBufferEmptyObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>)
   
    /// Remove indicator view when isPlaybackBufferFull.
    func onIsPlaybackBufferFullObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>)
    
    /// Remove indicator view when isPlaybackLikelyToKeepUp.
    func onIsPlaybackLikelyToKeepUpObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>)
    
    /// Observe buffering for current item.
    func observeItemBuffering(previousPlayerItem: AVPlayerItem?, currentPlayerItem: AVPlayerItem?)
    
    /// Access AVPlayerItem duration, and media options once AVPlayerItem is loaded
    func observeItemStatus(previousPlayerItem: AVPlayerItem?, currentPlayerItem: AVPlayerItem?)
    
    /// Observe player item did play end.
    func observeItemPlayEnd(previousPlayerItem: AVPlayerItem?, currentPlayerItem: AVPlayerItem?)
    
    /// Observe player item buffering, status and play end.
    func observePlayerItem(previousPlayerItem: AVPlayerItem?, currentPlayerItem: AVPlayerItem?)
    
    /// Proceed to next player item, if the item is the last one in the AVQueuePlayer, then will just replay the item.
    func proceedNextPlayerItem()
    
    /// Tell the delegate didPlaybackEnd. If next item exist in AVQueuePlayer, observe next item.
    func didPlaybackEnd()
    
    /// Access and gather availableMediaCharacteristicsWithMediaSelectionOptions, store in local variable.
    func getMediaSelectionOptions(currentPlayerItem: AVPlayerItem)
    
    /// Collect display name and locale from AVMediaCharacteristic.
    /// - Parameters:
    ///   - currentPlayerItem: The current item in the player.
    ///   - characteristic: The options for specifying media type characteristics.
    /// - Returns: An array of DisplayNameLocale.
    func getMediaOptionDisplayDetail(currentPlayerItem: AVPlayerItem, characteristic: AVMediaCharacteristic) -> [DisplayNameLocale]
   
    /// Set selected audio track and subtitle to current player item.
    func selectMediaOption(mediaOptionType: MediaOptionType, index: Int)
    
    // MARK: - player method
    
    /// Start observe currentTime.
    func addPeriodicTimeObserver()
    
    /// Stop observe currentTime.
    func removePeriodicTimeObserver()
    
    /// Call this method when user tap jump time button.
    func jumpToTime(_ jumpTimeType: JumpTimeType)
    
    /// Call this method when user is in the process of dragging progress bar slider.
    func slideToTime(_ sliderValue: Double)
    
    /// Call this method when user end dragging progress bar slider.
    func sliderTouchEnded(_ sliderValue: Double)
    
    /// Set a timer to check if AVPlayerItem.isPlaybackLikelyToKeepUp. If yes, then will play, but if not, will recall this method again.
    func bufferingForSeconds(playerItem: AVPlayerItem, player: AVPlayer)
    
    /// Pause player, let player control keep existing on screen.(Call this method when buffering.)
    func cancelPlay(player: AVPlayer)
    
    /// Play player, update player UI, let player control auto hide.
    func playPlayer()
    
    /// Pause player, update player UI, let player control keep existing on screen.(Call this method when user's intension to pause player.)
    func pausePlayer()
    
    /// Determine play action according to playerState.
    func togglePlay()
    
    /// Call this method when user tap speedButtonType button.
    func adjustSpeed(_ speedButtonType: SpeedButtonType)
    
}
