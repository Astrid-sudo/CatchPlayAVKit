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
    
    func changeSpeedRate(speedRate: Float) {
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
        let currenTime = CMTimeGetSeconds(currentTime)
        let duration = CMTimeGetSeconds(duration)
        self.playProgress.value = Float(currenTime / duration)
    }

}

