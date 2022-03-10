//
//  CustomPlayerViewModel.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/11.
//

import Foundation
import CoreMedia

public class CustomPlayerViewModel {
    
    let playSpeedRate: Box<Float> = Box(1)
    let playProgress: Box<Float> = Box(.zero)
    let currentTime = Box("")
    let duration = Box("")
    let playButtonType: Box<PlayButtonType> = Box(.play)
    let showIndicator: Box<Bool> = Box(false)
    let autoHidePlayerControl: Box<Bool> = Box(true)
    let playerControlHide: Box<Bool> = Box(false)
    let playBackEnd: Box<Bool> = Box(false)
    let isTheLastItem: Box<Bool> = Box(false)
    var autoHideTimer: BufferTimer?

    private(set) lazy var videoPlayHelper: PlayerProtocol = {
        let videoPlayHelper = VideoPlayHelper()
        videoPlayHelper.delegate = self
        return videoPlayHelper
    }()
    
    init() {
        configPlayer()
    }
    
    // MARK: - player method
    
    /// Configure player with url string, insert plyer item to the player.
    private func configPlayer() {
        videoPlayHelper.configQueuePlayer(Constant.sourceOne)
        videoPlayHelper.insertPlayerItem(Constant.sourceTwo)
    }

    func changeSpeedRate(speedRate: Float) {
        //This CatchPlayAVKit app doesn't support play reverse, so make sure the speedRate is positive.
        guard speedRate > 0 else { return }
        playSpeedRate.value = speedRate
    }
    
    func changeCurrentTime(currentTime: CMTime) {
        let currenTimeSeconds = CMTimeGetSeconds(currentTime)
        self.currentTime.value = TimeManager.floatToTimecodeString(seconds: Float(currenTimeSeconds)) + " /"
    }
    
    func changeDuration(duration: CMTime) {
        let durationSeconds = CMTimeGetSeconds(duration)
        self.duration.value = TimeManager.floatToTimecodeString(seconds: Float(durationSeconds))
    }
    
    func changeProgress(currentTime: CMTime, duration: CMTime) {
        guard duration >= currentTime else { return }
        let currenTime = CMTimeGetSeconds(currentTime)
        let duration = CMTimeGetSeconds(duration)
        self.playProgress.value = Float(currenTime / duration)
    }
    
    func automaticallyHidePlayerControl() {
        autoHideTimer?.cancel()
        autoHideTimer = BufferTimer(interval: 0, delaySecs: 3, repeats: false, action: { [weak self] _ in
            guard let self = self else { return }
            self.playerControlHide.value = true
        })
        autoHideTimer?.start()
    }
    
     func cancelAutoHidePlayerControl() {
        autoHideTimer?.cancel()
    }

}

// MARK: - PlayerProtocolDelegate

extension CustomPlayerViewModel: PlayerProtocolDelegate {
    
    func updateSelectedSpeedButton(_ videoPlayHelper: PlayerProtocol, speedButtonType: SpeedButtonType) {
        changeSpeedRate(speedRate: speedButtonType.speedRate)
    }
    
    func togglePlayButtonImage(_ videoPlayHelper: PlayerProtocol, playButtonType: PlayButtonType) {
        self.playButtonType.value = playButtonType
    }
    
    func autoHidePlayerControl(_ videoPlayHelper: PlayerProtocol) {
        automaticallyHidePlayerControl()
    }
    
    func cancelAutoHidePlayerControl(_ videoPlayHelper: PlayerProtocol) {
        cancelAutoHidePlayerControl()
    }
    
    func updateCurrentTime(_ videoPlayHelper: PlayerProtocol, currentTime: CMTime) {
        changeCurrentTime(currentTime: currentTime)
        if let duration = videoPlayHelper.currentItemDuration {
            changeProgress(currentTime: currentTime, duration: duration)
        }
    }
    
    func didPlaybackEnd(_ videoPlayHelper: PlayerProtocol) {
        guard let itemsInPlayer = videoPlayHelper.itemsInPlayer,
              let currentItem = videoPlayHelper.currentItem else { return }
        
        playBackEnd.value = true
        
        if currentItem == itemsInPlayer.last {
            isTheLastItem.value = true
            return
        }
    }
    
    func toggleIndicatorView(_ videoPlayHelper: PlayerProtocol, show: Bool) {
        if show {
            showIndicator.value = true
        } else {
            showIndicator.value = false
        }
    }
    
    func updateDuration(_ videoPlayHelper: PlayerProtocol, duration: CMTime) {
        changeDuration(duration: duration)
        if let currentTime = videoPlayHelper.currentItemCurrentTime {
            changeProgress(currentTime: currentTime, duration: duration)
        }
    }
    
    func slideToTime(_ sliderValue: Double) {
        videoPlayHelper.slideToTime(sliderValue)
    }
    
    func sliderTouchEnded(_ sliderValue: Double) {
        videoPlayHelper.sliderTouchEnded(sliderValue)
    }
    
    func togglePlay() {
        videoPlayHelper.togglePlay()
    }
    
    func jumpToTime(_ jumpTimeType: JumpTimeType) {
        videoPlayHelper.jumpToTime(jumpTimeType)
    }
    
    func adjustSpeed(_ speedButtonType: SpeedButtonType) {
        videoPlayHelper.adjustSpeed(speedButtonType)
    }
    
    func proceedNextPlayerItem() {
        videoPlayHelper.proceedNextPlayerItem()
    }
    
    func pausePlayer() {
        videoPlayHelper.pausePlayer()
    }
    
    func selectMediaOption(mediaOptionType: MediaOptionType, index: Int) {
        videoPlayHelper.selectMediaOption(mediaOptionType: mediaOptionType, index: index)
    }
    
}


